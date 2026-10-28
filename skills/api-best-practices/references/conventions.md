# API Conventions

## Table of contents
- Pagination
- Sorting
- Filters
- Incremental sync
- Writes
- Document lines
- Error handling
- Rate limiting and retries
- Scopes and permissions
- Webhooks
- Traps to avoid

## Pagination

All list endpoints use page-based pagination.

- `page`: page number, starts at **1** (not 0)
- `perPage`: items per page, default **20**, maximum **100**

Values are validated, not clamped: `page=0` or `perPage=101` returns `400 PaginationValidationException`.

The response is a **bare JSON array** — there is no envelope, no `total`, no `hasMore` flag. The end of the list is reached when a page returns **fewer items than `perPage`**.

```http
GET /tasks?page=1&perPage=100
GET /tasks?page=2&perPage=100
# Stop when a page returns fewer than 100 items
```

Always use `perPage=100` for bulk reads to minimize round trips.

## Sorting

Most list endpoints accept `sort`: comma-separated field names, `-` prefix for descending, at most 3 fields. Each endpoint has its own set of sortable fields; an unknown field returns `400 SortValidationException`.

```http
GET /tasks?sort=-dueDateTime,name
```

When paging through data that changes while you read it, add a stable sort such as `sort=id` or `sort=modifiedDateTime,id`. Without it, records can be skipped or returned twice across pages.

## Filters

Filters use **deep-object query parameter syntax** with camelCase, usually plural, keys.

```
# Single value
GET /tasks?filters[isDone]=false

# Multiple values (OR logic within a filter)
GET /invoices?filters[statuses][]=paid&filters[statuses][]=unpaid

# Datetime range — the timezone offset is mandatory
GET /tasks?filters[modifiedDateTime][from]=2026-01-01T00:00:00Z&filters[modifiedDateTime][to]=2026-12-31T23:59:59Z

# Date-only range (date fields such as invoice date)
GET /invoices?filters[date][from]=2026-01-01&filters[date][to]=2026-01-31

# Filter by IDs
GET /tasks?filters[ids][]=101&filters[ids][]=102&filters[ids][]=103
```

Numeric fields take the same `[from]`/`[to]` range form (durations in seconds), and custom fields filter as `filters[customFields][c_region]=north`.

Rules worth knowing:

- **Text filters are partial matches.** `name`, `description`, `companyName`, `registrationCode` and similar use a contains-match. Compare the exact value in the response before treating a result as a match.
- **Datetime filters need an offset.** `2026-01-01T00:00:00Z` or `...+02:00` works. A bare `2026-01-01T00:00:00`, or a date-only value in a datetime filter, returns `400 FilterDeserializeException`.
- **Generated clients must emit this bracket syntax.** With openapi-generator 7.26 the TypeScript client repeats the key without `[]` and the Python client JSON-encodes the object; Go and a plain PHP array work. Run the check in `references/getting-started.md` before relying on filters.
- **Deleted records are excluded by default.** Lists return only live records unless you pass `filters[isDeleted]=true`.
- **Saved views:** `filters[bookmarkId]=<id>` or `filters[bookmarkHash]=<bh_ segment of a Scoro list URL>` applies a saved list view. Explicit filters override the bookmark's values. The two bookmark keys cannot be combined.

## Incremental sync

Use `filters[modifiedDateTime][from]` to fetch only records changed since the last successful run. Store the timestamp of your last successful sync and use it as the next `from` value.

Because deleted records are excluded by default, **a `modifiedDateTime` sync never sees deletions**. Poll deletions separately, or subscribe to a `delete` webhook (see Webhooks):

```http
GET /tasks?filters[isDeleted]=true&filters[deletedDateTime][from]=2026-10-01T00:00:00Z
```

Time offs are the one naming exception: their filters are `createdDate` and `modifiedDate`, not `modifiedDateTime`.

## Writes

- `POST` creates a new resource and returns `201` with a body of `{"id": <number>}`.
- `PATCH` updates an existing resource partially — include only the fields you want to change. Returns `204` with no response body.
- `DELETE` removes a resource. Returns `204`. Deletes are soft for most resources — the record stays readable with `filters[isDeleted]=true`.

Exceptions to the `201`/`204` pattern: document line upserts return `200` with the full line list (see Document lines); `POST /invoices/{id}/mark-paid` returns `200` or `201`; action endpoints such as `POST /tasks/{id}/set-done` return `204`; time-tracker actions return `200`.

```http
# Create a task
POST /tasks
Content-Type: application/json

{"name": "Onboarding call", "projectId": 42, "status": "open"}

# Response: 201 {"id": 9871}

# Update only the status
PATCH /tasks/9871
Content-Type: application/json

{"status": "done"}

# Response: 204 (no body)
```

**Custom fields** go in a `customFields` object, keyed by the `id` returned from `GET /{module}/custom-fields` (e.g. `c_region`):

```json
{"name": "Onboarding call", "customFields": {"c_region": "north"}}
```

Multi-select and multi-date fields take arrays, number and money range fields take `{"from": ..., "to": ...}`, and an empty array clears a field.

**`null` does not always clear a field.** Only fields the schema marks nullable accept `null`. Fields documented "Cannot be null. Omit to leave unchanged" — for example `clientId`, `date` and `status` on finance documents, or `userId` on time entries — return `400` on `null`.

## Document lines

Invoices, quotes, orders, bills, expenses, purchase orders, prepayments and scheduled invoices all handle line items the same way:

- **Create with lines embedded.** `POST /invoices` (and the other document creates) accept a `lines` array in the same request — no second call needed.
- **Detail responses always include `lines`.** `GET /invoices/{id}` returns them; there is no `includeLines` parameter on detail endpoints.
- **List responses omit lines by default.** Pass `includeLines=true` on `GET /invoices`, `/bills`, `/expenses`, `/orders`, `/purchase-orders`, `/quotes`, `/prepayments` or `/scheduled-invoices` to include them.
- **`POST /{document}/{id}/lines` is an upsert**, not an append. The body is `{"lines": [...]}` — an object, not a bare array. Lines with an `id` are updated, lines without one are created, lines you don't mention are left alone. Returns `200` with the full, updated line list.
- **There is no line `PATCH`.** Update a line through the upsert with its `id`. Remove one with `DELETE /{document}/{id}/lines/{lineId}`.
- Prepayments support the upsert but have no line `GET`.

```http
POST /invoices/123/lines
Content-Type: application/json

{
  "lines": [
    {"id": 501, "quantity": 3},
    {"productId": 7, "quantity": 1, "price": 500.00}
  ]
}

# Response: 200 [ ...all lines of invoice 123... ]
```

Line fields are `price` and `quantity` plus `description`, `productId`, `taxRateId`, `unitId`, `projectId`, `discount`, `financeAccountId`, `accountingObjectId` and `customFields`. There is no `sum` on a line — totals are calculated.

## Error handling

Errors from the API have this shape. `error` is the exception class name and `message` is always an array of strings:

```json
{
  "error": "ResourceNotFoundException",
  "statusCode": 404,
  "timestamp": "2026-10-27T10:00:00.000Z",
  "path": "/api/v4/tasks/9999",
  "message": ["Task not found"]
}
```

Common `error` values: `RequestPayloadValidationException` and `RequestValidationException` (400, bad body); `FilterDeserializeException`, `PaginationValidationException` and `SortValidationException` (400, bad query); `AccessDeniedException` (403); `ResourceNotFoundException` and `RelatedResourceNotFoundException` (404); `ConflictException` (409); `InternalServerErrorException` (500).

| Code | Meaning |
|---|---|
| 400 | Bad request — invalid body, filter, sort or pagination value. Validation failures are 400, never 422 (the only 422 is on free-time-slot lookups) |
| 401 | Missing or invalid token, **or the caller's IP is not on the site's allow-list** (`"Requests from this IP are not allowed"`) |
| 403 | Insufficient scope, module not enabled on the site, user lacks the permission, or no access to the requested company account |
| 404 | Resource not found, including a referenced parent that doesn't exist (`RelatedResourceNotFoundException`). Also returned for a wrong HTTP method on a known path — there is no 405 |
| 409 | Conflict with the current state of the resource |
| 414 | URI too long — long `filters[ids][]` lists can hit this; split them into batches |
| 415 | Unsupported media type — send `Content-Type: application/json` |
| 429 | Rate limit exceeded |
| 500 | Server error — safe to retry with back-off |

Two errors come from the API gateway rather than the API, so their bodies differ:

- **Missing scope:** `403 {"error": "insufficient_scope", "required_scope": "<scope>"}`
- **Rate limit:** `429 {"status": "ERROR", "statusCode": "429", "messages": {"error": ["Too Many Requests"]}}` — a v2-style envelope

Authentication failures before routing (bad token, inaccessible company account, blocked IP) return a bare JSON string body, e.g. `"Unauthorized"` or `"Access denied to account \"mycompany\""`.

## Rate limiting and retries

Limits are counted per OAuth app per Scoro site over several windows (per second, minute, hour, day, week, month and year — the numbers are set per app). Day and longer windows reset at midnight UTC. Every response reports the current state:

- `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` — the shortest window
- `X-Daily-Requests-Limit`, `X-Daily-Requests-Remaining`, `X-Daily-Requests-Reset` — the daily window

Watch `X-RateLimit-Remaining` and slow down before you hit `429`. When a `429` is returned, wait for the number of seconds in `Retry-After` before retrying. A fixed sleep between requests does not map to this model — budget requests per window instead.

Retry rules:

- `GET` requests are idempotent — safe to retry on 429 or 5xx.
- `POST` requests are **not** idempotent — check whether the resource was created before retrying. A duplicate POST may create a duplicate record. This includes action endpoints (`mark-paid`, `set-done`, time-tracker `pause`/`resume`/`complete`) and line upserts: a retried upsert whose lines have no `id` creates duplicate lines.
- `PATCH` is idempotent — safe to retry.
- `DELETE` is safe to retry; a repeated `DELETE` returns `404`.

## Scopes and permissions

Scopes are `{resource}:{level}`. Levels are cumulative: `rwd` includes `rw`, which includes `r`.

| Level | Access granted |
|---|---|
| `r` | Read |
| `rw` | Read and write |
| `rwd` | Read, write and delete |

Rules that trip people up:

- **The schema names the scope of every operation.** Each operation's `security` entry lists the scope it needs; some accept either of two. Derive an integration's scope list from the endpoints it calls: collect their scopes, keep the highest level per resource, and request exactly those. A client generated with `scripts/generate-client.sh` and the docs from `scripts/generate-docs.sh` carry the same scopes, but show only the first alternative, so the schema stays the source of truth.
- **Resource names are not URL segments.** Companies and persons are both `contacts:*`. Time entries are under `tasks:*`. Payment allocations and `mark-paid` are under `invoice-payments:*`. Check the `security` entry of each operation in the OpenAPI schema (`https://api.scoro.com/api/v4/reference/openapi`).
- **Scope is per endpoint, not per HTTP verb.** `POST /invoices/{id}/mark-paid` needs `invoice-payments:rw`, not `invoices:rw`. Comment and file sub-resources accept either `comments:*`/`files:*` or the parent resource's scope.
- **`base:r` is granted automatically** with any granular scope — you don't request it. It covers reference data: `/users/me`, `/users/search`, `/statuses`, `/tax-rates`, `/currencies`, `/roles`, `/tags`, `/units` and `/{module}/custom-fields`.
- **`scoro:all`** grants everything. A few endpoints have no granular scope and accept only `scoro:all`.
- **Scopes are necessary, not sufficient.** The Scoro user behind the token must also have the module and permission. A valid scope still returns `403` when the user can't access the module, and finance values such as costs and margins are hidden from users without finance permissions. `GET /users/me` returns `enabledPermissions` — check it before planning writes.

Request the minimum scope needed. Read-only integrations (exports, reporting) should never request write or delete scopes.

## Webhooks

For near-real-time sync, prefer webhooks over polling. `POST /webhooks` with `module` (e.g. `"tasks"`), `action` (`create`, `modify`, `delete` or `any`) and `url`; optional `fields` (only with `modify`), `owners`, `actors`, `relationType` and `bookmarkId`. `GET /webhooks` lists them, `DELETE /webhooks/{id}` removes one. Scopes: `webhooks:r|rw|rwd`. Scoro POSTs the affected entity to your URL.

## Traps to avoid

- **No total count in responses.** Never assume you have all records after fetching one page. Always paginate until a short page.
- **Incremental sync is a `modifiedDateTime` range filter** (the v2 `modified_date` filter with new spelling; there is no sync action) — and it never returns deleted records. Handle deletions separately (see Incremental sync).
- **`POST` is not idempotent** — if a request times out, check for an existing record before retrying to avoid duplicates.
- **`PATCH` sends a partial body.** Omit fields you don't intend to change. `null` clears a field only where the field is nullable; elsewhere it is a `400`.
- **Line upsert bodies are objects.** `POST /{document}/{id}/lines` takes `{"lines": [...]}`; a bare array is rejected.
- **Use search endpoints for lookups by name.** `GET /{resource}/search?keyword=...` exists for tasks, projects, companies, persons, users, invoices, quotes, orders, bills, expenses, purchase orders, files and comments and returns `{id, title, href}` items — simpler than filters when you only need an ID.
