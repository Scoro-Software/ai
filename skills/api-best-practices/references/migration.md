# Migrating from API v2 to v4

## Table of contents
- Auth
- Request format
- Response format
- Pagination and filters
- Value types
- Document lines
- Incremental sync
- Endpoint mapping
- Porting steps

## Auth

| v2 | v4 |
|---|---|
| `apiKey` or `user_token` in the JSON request body | OAuth 2.0 Bearer token in `Authorization: Bearer <token>` header |

v4 has no equivalent to a static API key. Every integration requires an OAuth app registered in the Scoro Developer Portal. See `references/getting-started.md` for the authorization flow.

## Request format

| v2 | v4 |
|---|---|
| Every call is `POST` with a JSON body | REST verbs: `GET`, `POST`, `PATCH`, `DELETE` |
| `action: "list"` in the body | `GET /resource` |
| `action: "view", id: 123` in the body | `GET /resource/123` |
| `action: "modify"` (no ID, creates) | `POST /resource` |
| `action: "modify", id: 123` (updates) | `PATCH /resource/123` |
| `action: "delete", id: 123` | `DELETE /resource/123` |

## Response format

| v2 | v4 |
|---|---|
| Envelope: `{status, statusCode, messages, data}` | Bare JSON (array or object) |
| Errors returned as HTTP 200 with `status: "ERROR"` | Real HTTP error codes (400, 401, 403, 404, 429, 500) |
| Success indicated by `status: "OK"` field | Indicated by HTTP 2xx status code |

Replace all envelope parsing with direct HTTP status code checks. Remove any code that reads `response.status === "OK"`.

## Pagination and filters

| v2 | v4 |
|---|---|
| `per_page` in request body | `perPage` query param (max 100) |
| `page` in request body | `page` query param (starts at 1) |
| `filter: { key: value }` in body | `filters[key]=value` query params |
| Snake_case filter keys | camelCase filter keys, usually plural |
| `filter: { project_id: 5 }` | `filters[projectIds][]=5` |
| `filter: { is_done: 1 }` | `filters[isDone]=true` |

## Value types

| v2 | v4 |
|---|---|
| Duration as `"HH:MM:SS"` string (e.g. `"1:30:00"`) | Duration as integer **seconds** (e.g. `5400`) |
| Booleans as `1` / `0` | Booleans as `true` / `false` |
| `company_account_id` in request body | `Scoro-Company-Account: <identifier>` request **header** (string, e.g. `"mycompany"`) |
| Custom fields as `[{"id": 5, "value": "x"}, ...]` | Custom fields as `{"fieldName": "x"}` flat map |
| Status as numeric ID | Status as `code` string from `GET /statuses` |

## Document lines

In v2, line items (invoice lines, quote lines, order lines, bill lines) were embedded in the parent document response. In v4, lines are **separate sub-resources** with their own endpoints.

| v2 | v4 |
|---|---|
| Lines in parent response body | `GET /invoices/{id}/lines` |
| Lines in modify body | `POST /invoices/{id}/lines` |

This applies to: invoices, quotes, orders, bills, purchase orders, expenses.

## Incremental sync

v2 provided a `syncData` action that returned changed records. v4 uses standard filter parameters instead.

Replace `action: "syncData"` with a `modifiedDateTime` range filter on any list endpoint:

```http
GET /tasks?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z
```

Store the timestamp of your last successful sync run and use it as the `from` value on the next run.

## Endpoint mapping

| v2 module | v2 action | v4 |
|---|---|---|
| `contacts` | `list` | `GET /companies` or `GET /persons` |
| `contacts` | `view` | `GET /companies/{id}` or `GET /persons/{id}` |
| `contacts` | `modify` | `POST /companies` or `PATCH /companies/{id}` |
| `contacts` | `delete` | `DELETE /companies/{id}` |
| `projects` | `list` | `GET /projects` |
| `projects` | `view` | `GET /projects/{id}` |
| `projects` | `modify` | `POST /projects` or `PATCH /projects/{id}` |
| `tasks` | `list` | `GET /tasks` |
| `tasks` | `view` | `GET /tasks/{id}` |
| `tasks` | `modify` | `POST /tasks` or `PATCH /tasks/{id}` |
| `time_entries` | `list` | `GET /tasks/time-entries` |
| `time_entries` | `modify` | `POST /tasks/{taskId}/time-entries` |
| `invoices` | `list` | `GET /invoices` |
| `invoices` | `view` | `GET /invoices/{id}` |
| `invoices` | `modify` | `POST /invoices` or `PATCH /invoices/{id}` |
| `invoices` → lines | embedded | `GET /invoices/{id}/lines` |
| `quotes` | `list` | `GET /quotes` |
| `quotes` | `view` | `GET /quotes/{id}` |
| `quotes` | `modify` | `POST /quotes` or `PATCH /quotes/{id}` |
| `orders` | `list` | `GET /orders` |
| `orders` | `modify` | `POST /orders` or `PATCH /orders/{id}` |
| `bills` | `list` | `GET /bills` |
| `bills` | `modify` | `POST /bills` or `PATCH /bills/{id}` |
| `expenses` | `list` | `GET /expenses` |
| `expenses` | `modify` | `POST /expenses` or `PATCH /expenses/{id}` |
| `calendar` | `list` | `GET /calendar-events` |
| `calendar` | `modify` | `POST /calendar-events` or `PATCH /calendar-events/{id}` |
| `users` | `list` | `GET /users` |
| `users/me` | `view` | `GET /users/me` |
| `statuses` | `list` | `GET /statuses` |
| `products` | `list` | `GET /products` |
| `bookings` | `list` | `GET /bookings` |
| `bookings` | `modify` | `POST /bookings` or `PATCH /bookings/{id}` |

## Porting steps

Work through these in order:

1. **Register an OAuth app** in the Scoro Developer Portal and obtain a token. See `references/getting-started.md`.
2. **Find every v2 call** in the codebase — search for `scoro.com/api/v2` and any `action:` keys in API request bodies.
3. **Map each call to v4** using the endpoint mapping table above.
4. **Remove envelope parsing** — replace `response.data` access with direct field access, and replace `response.status === "OK"` checks with HTTP status code checks.
5. **Convert filter objects** to query parameter notation using the deep-object syntax `filters[key][]=value`.
6. **Convert value types**: duration strings → seconds, integer booleans → `true`/`false`, status IDs → status codes from `GET /statuses`.
7. **Move line item operations** to the `/lines` sub-resource endpoints.
8. **Replace `syncData`** with `filters[modifiedDateTime][from]` range filters.
9. **Move `company_account_id`** from the request body to the `Scoro-Company-Account` request header.
10. **Update custom field writes** from `[{id, value}]` arrays to `{"fieldName": value}` maps.
11. **Test against a v4 sandbox** — verify field names in responses match expectations, and confirm pagination works correctly.
