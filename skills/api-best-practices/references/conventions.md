# API Conventions

## Table of contents
- Pagination
- Filters
- Writes
- Error handling
- Rate limiting and retries
- Scopes
- Traps to avoid

## Pagination

All list endpoints use cursor-free page-based pagination.

- `page`: page number, starts at **1** (not 0)
- `perPage`: items per page, default **20**, maximum **100**

The response is a **bare JSON array** — there is no envelope, no `total`, no `hasMore` flag. The end of the list is reached when a page returns **fewer items than `perPage`**.

```http
GET /tasks?page=1&perPage=100
GET /tasks?page=2&perPage=100
# Stop when a page returns fewer than 100 items
```

Always use `perPage=100` for bulk reads to minimize round trips.

## Filters

Filters use **deep-object query parameter syntax** with camelCase, usually plural, keys.

```
# Single value
GET /tasks?filters[isDone]=false

# Multiple values (OR logic within a filter)
GET /invoices?filters[statuses][]=paid&filters[statuses][]=unpaid

# Date range
GET /tasks?filters[modifiedDateTime][from]=2026-01-01T00:00:00Z&filters[modifiedDateTime][to]=2026-12-31T23:59:59Z

# Filter by IDs
GET /tasks?filters[ids][]=101&filters[ids][]=102&filters[ids][]=103
```

Use `filters[modifiedDateTime][from]` for incremental sync — fetch only records changed since the last successful run.

## Writes

- `POST` creates a new resource and returns `201` with a body of `{"id": <number>}`.
- `PATCH` updates an existing resource partially — include only the fields you want to change. Returns `204` with no response body.
- `DELETE` removes a resource. Returns `204`.

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

## Error handling

Error responses follow a consistent shape:

```json
{
  "error": "not_found",
  "statusCode": 404,
  "timestamp": "2026-10-27T10:00:00Z",
  "path": "/api/v4/tasks/9999",
  "message": ["Task not found"]
}
```

Standard HTTP status codes:

| Code | Meaning |
|---|---|
| 400 | Bad request — invalid input, missing required field |
| 401 | Unauthorized — missing or expired token |
| 403 | Forbidden — valid token but insufficient scope |
| 404 | Not found |
| 429 | Rate limit exceeded |
| 500 | Server error — safe to retry with back-off |

## Rate limiting and retries

When a `429` is returned, check the `Retry-After` header for the number of seconds to wait before retrying. Do not retry immediately.

- `GET` requests are idempotent — safe to retry on 429 or 5xx.
- `POST` requests are **not** idempotent — check whether the resource was created before retrying. A duplicate POST may create a duplicate record.
- `PATCH` and `DELETE` are idempotent — safe to retry.

For bulk operations, add a small delay (100–500ms) between requests to stay within rate limits.

## Scopes

Scopes control what an OAuth token can do:

| Scope suffix | Access granted |
|---|---|
| `r` | Read only — `GET` requests |
| `rw` | Read and write — `GET`, `POST`, `PATCH` |
| `rwd` | Read, write, delete — `GET`, `POST`, `PATCH`, `DELETE` |

Scope format: `{module}:{level}` — for example, `tasks:rw`, `invoices:r`, `projects:rwd`.

Request the minimum scope needed. Read-only integrations (exports, reporting) should never request write or delete scopes.

## Traps to avoid

- **No total count in responses.** Never assume you have all records after fetching one page. Always paginate until a short page.
- **`page=0` is not valid** — pagination starts at 1. Passing `page=0` returns an error.
- **Incremental sync uses `modifiedDateTime`, not a `syncData` action** (that was a v2 concept). Always store the timestamp of your last successful sync run and use it as `filters[modifiedDateTime][from]` on the next run.
- **`POST` is not idempotent** — if a request times out, check for an existing record before retrying to avoid duplicates.
- **`PATCH` sends a partial body** — sending a field with `null` will clear that field. Omit fields you don't intend to change rather than including them with their current value.
