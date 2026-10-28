# Migrating from API v2 to v4

## Table of contents
- Auth
- Request format
- Response format
- Pagination, filters and list options
- Value types
- Document lines
- Incremental sync
- Endpoint mapping
- No v4 equivalent
- Porting steps

## Auth

| v2 | v4 |
|---|---|
| `apiKey` (site key) or `user_token` in the JSON request body | OAuth 2.0 Bearer token in the `Authorization: Bearer <token>` header |
| `user_token` obtained from a username and password via `userAuth/modify` (plus `userAuth/verify` for 2-step verification) | Authorization-code flow for an app registered in the Scoro Developer Portal; there is no password login |
| `scoro-app-id` header identifying a public integration | The OAuth client is the integration's identity; no extra header |
| `company_account_id` in the body selects the business entity | `Scoro-Company-Account: <identifier>` request **header**; optional, the user's default account when absent |

v4 has no static API key. Every integration needs an OAuth app registered in the Scoro Developer Portal, and scopes are enforced per endpoint at the API gateway. See `references/getting-started.md` for the authorization flow.

## Request format

v2 sends every call as `POST https://{site}.scoro.com/api/v2/{module}/{action}/{id}`. The action (`list`, `view`, `modify`, `delete`, `pdf`, ...) and the record ID are in the **URL**; the JSON body carries the credentials, list options and a `request` object with the record's fields:

```json
{
  "apiKey": "API_hash",
  "lang": "eng",
  "company_account_id": "tutorial",
  "per_page": 50,
  "page": 2,
  "filter": { "modified_date": { "from_date": "2026-01-01", "to_date": "2026-01-31" } },
  "request": { "name": "New name" }
}
```

| v2 | v4 |
|---|---|
| `POST /{module}/list` | `GET /resource` |
| `POST /{module}/view/{id}` | `GET /resource/{id}` |
| `POST /{module}/modify` (no ID creates) with the fields in `request` | `POST /resource` with the fields as the JSON body |
| `POST /{module}/modify/{id}` with the fields in `request` | `PATCH /resource/{id}` with only the changed fields |
| `POST /{module}/delete/{id}` | `DELETE /resource/{id}` |
| `lang` in the body | Dropped. A `lang` query parameter exists only on `GET /products`, `GET /product-groups` and the `/pdf` endpoints |
| `return_data` on modify | Dropped. `POST` returns `201` with `{"id": <number>}` and `PATCH` returns `204` with no body; `GET` the record if you need it back |
| `detailed_response` and `basic_data` on list | Dropped; list and detail responses have one shape, except document lines (see Document lines) |
| `bookmark` object on list (user token only) | `filters[bookmarkId]=<id>` or `filters[bookmarkHash]=<bh_...>` on any list |
| `include_deleted: "1"` | `filters[isDeleted]=true` |

v2 module names are camelCase and some are nested (`timeEntries`, `purchaseOrders`, `invoices/prepayments`); v4 resources are kebab-case (`/tasks/time-entries`, `/purchase-orders`, `/prepayments`). Field names change from snake_case to camelCase throughout (`modified_date` → `modifiedDateTime`, `company_id` → `companyId`).

## Response format

| v2 | v4 |
|---|---|
| Envelope: `{status, statusCode, messages, data}` | Bare JSON (array or object) |
| Errors returned as HTTP 200 with `status: "ERROR"` and the real code only in `statusCode` (`"400"`, `"401"`, `"403"`, `"500"`, ...) | Real HTTP status codes (400, 401, 403, 404, 429, 500) with an `{error, statusCode, timestamp, path, message}` body |
| Success indicated by `status: "OK"` | Indicated by the HTTP 2xx status |
| Exceptions: a wrong `scoro-app-id` is a real HTTP 401, and rate limiting is a real HTTP 429 with the envelope body | The gateway's `429` body still uses the v2-style envelope |

Replace all envelope parsing with HTTP status checks. Remove code that reads `response.status === "OK"` or unwraps `response.data`. See `references/conventions.md` for the v4 error shape.

## Pagination, filters and list options

| v2 | v4 |
|---|---|
| `per_page` in the body (max 100; max 25 with `detailed_response`) | `perPage` query param (max 100) |
| `page` in the body | `page` query param (starts at 1) |
| `filter: { key: value }` in the body | `filters[key]=value` query params |
| Snake_case filter keys | camelCase filter keys, plural for ID lists |
| `filter: { project_id: 5 }` | `filters[projectIds][]=5` |
| `filter: { is_done: 1 }` | `filters[isDone]=true` |
| Range: `filter: { modified_date: { from_date: "...", to_date: "..." } }` | `filters[modifiedDateTime][from]=...&filters[modifiedDateTime][to]=...` |
| `filter: { custom_fields: { c_field: "x" } }` | `filters[customFields][c_field]=x` |
| `{module}/filters` action that lists the available filters | Dropped; each list endpoint's `filters` parameter is documented in the schema |
| No sort option on lists (only `tasks/sorting`, which reorders tasks) | `sort` query param, up to 3 fields, `-` prefix for descending |

## Value types

| v2 | v4 |
|---|---|
| Durations as `HH:ii:ss` strings (`duration`, `duration_planned`, `billable_hours`); only bookings and retainers were already in seconds | All durations as integer **seconds** (e.g. `5400`) |
| Booleans as `1` / `0` | Booleans as `true` / `false` |
| Datetimes as `YYYY-MM-DDTHH:MM:SS+0000`; without an offset the site's default timezone applies | ISO 8601 with a mandatory timezone offset (`2026-01-01T00:00:00Z`) |
| `company_account_id` in the request body | `Scoro-Company-Account: <identifier>` request **header** (string, e.g. `"mycompany"`) |
| Custom field writes: `custom_fields: [{"id": "c_field", "value": "x"}, ...]` | `customFields` object keyed by field id: `{"customFields": {"c_field": "x"}}` |
| Custom field reads: array of `{id, name, value, type}`, only in view responses | `customFields` object keyed by field id |
| Status as a code string (`task_status1`, `inprogress`, `paid`) | Still a code string. Take task, project and custom-module codes from `GET /statuses?filters[modules][]=tasks`, never a numeric id. Invoices, prepayments, bills and expenses use fixed `paid`, `unpaid`, `voided` |
| One `contacts` module with `contact_type: "person"` or `"company"` | Separate `/companies` and `/persons` resources |

## Document lines

v2 embedded line items in the parent document: a `lines` array inside `request` on modify, and in view responses. v4 keeps lines on the document for create (`lines` array in the `POST` body) and for detail views, and adds `/lines` sub-resource endpoints for listing, upserting and deleting lines.

| v2 | v4 |
|---|---|
| Lines in the view response | Included in `GET /invoices/{id}`; on lists pass `includeLines=true` |
| `lines` in `request` on create | `lines` array in `POST /invoices` |
| `lines` in `request` on modify | `POST /invoices/{id}/lines` with `{"lines": [...]}` — an upsert, lines with `id` are updated |
| Removing a line | `DELETE /invoices/{id}/lines/{lineId}` |

This applies to invoices, quotes, orders, bills, purchase orders, expenses and scheduled invoices. Prepayments have `POST /prepayments/{id}/lines` only, with no list or delete endpoint. Quote templates have their own `/quote-templates/{id}/lines`.

## Incremental sync

v2 had no dedicated sync action. Integrations polled list endpoints with a `modified_date` range filter and `include_deleted: "1"` to see deletions (deleted records stay available for 30 days with `is_deleted` and `deleted_date` set). v4 works the same way with different spelling, but deleted records come from a separate query:

```http
GET /tasks?filters[modifiedDateTime][from]=2026-10-01T00:00:00Z
GET /tasks?filters[isDeleted]=true&filters[deletedDateTime][from]=2026-10-01T00:00:00Z
```

Store the timestamp of your last successful run and use it as the next `from` value. v4 lists exclude deleted records unless `filters[isDeleted]=true` is set, so a `modifiedDateTime` poll never sees deletions. Run the deletion query as well, or subscribe to `delete` webhooks (`POST /webhooks`) instead of polling.

## Endpoint mapping

The v2 column uses the `module/action` spelling from the v2 docs, so you can grep for it. `*` stands for the module's `list`, `view`, `modify` and `delete` actions (where v2 offers them), which map to `GET /resource`, `GET /resource/{id}`, `POST /resource` or `PATCH /resource/{id}`, and `DELETE /resource/{id}`.

### Contacts and CRM

| v2 | v4 |
|---|---|
| `contacts/list` | `GET /companies` and `GET /persons`; the `contact_type` filter becomes the choice of resource |
| `contacts/view/{id}` | `GET /companies/{id}` or `GET /persons/{id}` |
| `contacts/modify[/{id}]` | `POST /companies` or `PATCH /companies/{id}`; the same on `/persons` |
| `contacts/delete/{id}` | `DELETE /companies/{id}` or `DELETE /persons/{id}` |
| `contacts/getRelatedObjects/{id}` | Filter the related list instead: `GET /tasks?filters[companyIds][]=1`, `filters[personIds][]`, `filters[projectIds][]` |
| `relations` (list, modify, delete) | `relatedCompanyIds` on `POST /companies`, `PATCH /companies/{id}` and the `/persons` equivalents; read back as `relatedCompanies` and `relatedPersons`. There is no relation name, comment or default flag |
| `relationTypes/list` | `GET /contact-relation-types` |
| `categories/list` | `GET /contact-categories` |
| `clientProfiles/*` | `/client-profiles` |
| `search/list` (`search_phrase`) | `GET /{resource}/search?keyword=...` on companies, persons, projects, tasks, invoices, quotes, orders, bills, expenses, purchase-orders, users, comments and files |

### Projects, tasks and time

| v2 | v4 |
|---|---|
| `projects/*` | `/projects`; budget via `GET /projects/{id}/budget` |
| `projectPhases/list` | `GET /projects/{projectId}/phases` (per project); v4 also has `POST` and `GET` / `PATCH` / `DELETE /projects/{projectId}/phases/{id}` |
| `tasks/*` | `/tasks` |
| `tasks/setDone/{id}` (`completed_datetime`) | `POST /tasks/{id}/set-done` with `{"isDone": true, "doneDateTime": "..."}` |
| `timeEntries/list` | `GET /tasks/time-entries`; filter by `taskIds`, `calendarEventIds`, `userIds`, `projectIds` |
| `timeEntries/view/{id}` | `GET /tasks/time-entries/{id}` |
| `timeEntries/modify` (new entry, `event_id`) | `POST /tasks/{taskId}/time-entries`. v4 creates time entries only under a task; entries on calendar events are readable but cannot be created through the API |
| `timeEntries/modify/{id}` | `PATCH /tasks/time-entries/{id}` |
| `timeEntries/setDone/{id}` | `PATCH /tasks/time-entries/{id}` with `{"isCompleted": true}` |
| `timeEntries/delete/{id}` | `DELETE /tasks/time-entries/{id}` |
| `calendar/*` | `/calendar` |
| `calendar/check` (availability of users or resources) | `GET /calendar/free-time-slots?filters[startDate]=...&filters[endDate]=...&filters[userIds][]=...`; `GET /availability/lookup` for role or user capacity |
| `eventsResources/list`, `view` | `GET /event-resources`, `GET /event-resources/{id}`; v4 also creates, updates and deletes them |
| `bookings/*` | `/bookings` |
| `activities/list` | `GET /activity-types` |
| `timeOffs/*` | `/time-offs` |
| `timeOffTypes/*` | `/time-off-types` |
| `retainers/view`, `modify` | `GET` / `PATCH /retainers/{id}`; periods via `GET` / `POST /retainers/{id}/periods` and `PATCH` / `DELETE /retainer-periods/{id}` instead of the `retainer_periods` array |
| `revenueForecastPeriods/*` | `GET /revenue-forecast-periods`, `GET` / `PATCH /revenue-forecast-periods/{id}` |
| `roles/list`, `view` | `GET /roles`, `GET /roles/{id}` |
| `rolesPrices/list` | `GET /roles`; each role carries `priceLists[]` with `priceListId` and `sellingPrice` |
| `localPriceLists/view`, `modify` | `GET` / `PATCH /projects/{id}/role-prices`, and the same `/role-prices` sub-resource on quotes, orders, invoices, prepayments and scheduled invoices |

### Sales and purchase documents

| v2 | v4 |
|---|---|
| `invoices/*` | `/invoices` |
| `invoices/prepayments/*` | `/prepayments` |
| `invoices/scheduledInvoices/*` | `/scheduled-invoices` |
| `quotes/*` | `/quotes` |
| `orders/*` | `/orders` |
| `bills/*` | `/bills` |
| `expenses/*` | `/expenses` |
| `purchaseOrders/*` | `/purchase-orders` |
| `invoices/pdf/{id}`, `prepayments/pdf/{id}`, `quotes/pdf/{id}`, `orders/pdf/{id}`, `purchaseOrders/pdf/{id}` | `GET /{resource}/{id}/pdf`; v4 also has `GET /scheduled-invoices/{id}/pdf` |
| Lines embedded in `request` | See Document lines |

### Payments (v2 receipts)

| v2 | v4 |
|---|---|
| `receipts/list` | `GET /invoice-payments` and `GET /invoice-payments/{id}/allocations`; `GET /invoices/{id}/payments`; `GET /bill-payments` |
| `receipts/modify` with `sales_doc_type: "invoices"` | `POST /invoice-payments`, then `POST /invoice-payments/{id}/allocations` with `invoiceId` or `prepaymentId`. Shortcuts: `POST /invoices/{id}/payments` and `POST /invoices/{id}/mark-paid` |
| `receipts/modify` with `sales_doc_type: "bills"` | `POST /bill-payments`; `POST /bills/{id}/mark-paid` |
| `receipts/modify` with `sales_doc_type: "expenses"` | `POST /expenses/{id}/reimbursements` |
| `receipts/delete/{id}` | `DELETE /invoice-payments/{id}`, `DELETE /bill-payments/{id}` or `DELETE /expenses/{id}/reimbursements/{reimbursementId}` |
| `receiptAccounts/list` | `GET /payment-accounts` |

### Catalog and finance settings

| v2 | v4 |
|---|---|
| `products/modify`, `view`, `delete` | `/products`; v4 also lists with `GET /products` |
| `productGroups/*` | `/product-groups` |
| `priceLists/*` | `/price-lists` |
| `vatCodes/*` | `/tax-rates` |
| `financeAccounts/*` | `/finance-accounts` |
| `financeObjects/list`, `view` | `GET /accounting-objects`, `GET /accounting-objects/{id}`; v4 also creates, updates and deletes them |

### Users, site and reference data

| v2 | v4 |
|---|---|
| `companyAccount/list` | `GET /users/me` returns the `accounts` the user can access; branding per account via `GET /company-settings/{id}` |
| `users/list`, `view` | `GET /users`, `GET /users/{id}`, `GET /users/search` |
| `users/settings` | `GET /users/me` |
| `userGroups/list`, `view` | `GET /user-groups`, `GET /user-groups/{id}` |
| `userRoles/list`, `view` (permission sets) | `GET /permission-sets`, `GET /permission-sets/{id}` |
| `usersLaborCost/*` | `GET` / `POST /labor-costs`, `PATCH` / `DELETE /labor-costs/{id}` |
| `statuses/list` (`filter.module`) | `GET /statuses?filters[modules][]=tasks` |
| `tags/list` (`type`) | `GET /tags?filters[type]=contacts` |
| `bookmarks/list` (`module`) | `GET /bookmarks?filters[modules][]=tasks` |
| `customFields/list` | `GET /{module}/custom-fields`, e.g. `GET /tasks/custom-fields` |
| `customModules/list`, `view` | `GET /custom-modules`, `GET /custom-modules/{id}` |
| Custom module entries | `GET` / `POST /custom/{customModulePath}`, `GET` / `PATCH` / `DELETE /custom/{customModulePath}/{id}` |
| `pdfTemplates/list` | `GET /pdf-templates` |
| `sendLog/list` | `GET /sent-emails` |

### Files, comments, notifications and webhooks

| v2 | v4 |
|---|---|
| `files/list`, `view`, `delete` | `GET /files`, `GET /files/{id}`, `DELETE /files/{id}`; per entity `GET /{entity}/{id}/files` |
| `files/modify` (chunked base64 upload) | `POST /files` (multipart `file`) or `POST /{entity}/{id}/files`. For large files use the signed upload: `POST /files/uploads`, `PUT` the bytes to the returned `uploadUrl`, then `POST /files/uploads/{uploadId}/finalize` |
| `files/download/{id}` | `GET /files/{id}/download` |
| `comments/list` (`module`, `object_id`) | `GET /{entity}/{id}/comments`, e.g. `GET /tasks/123/comments`; keyword search via `GET /comments/search` |
| `comments/modify` (new) | `POST /{entity}/{id}/comments` |
| `comments/modify/{id}` | `PATCH /comments/{id}` |
| `comments/delete/{id}` | `DELETE /comments/{id}` |
| `notifications/list` | `GET /notifications` |
| `notifications/modify` (set last checked date) | `POST /notifications/{id}/read` and `POST /notifications/{id}/unread` per notification; v4 can also create one with `POST /notifications` |
| `webhooks/subscribe` | `POST /webhooks` with the same fields in camelCase: `module`, `action`, `url`, `relationType`, `owners`, `actors`, `bookmarkId`, `fields`. Take the `module` values from the v4 schema |
| `webhooks/list` | `GET /webhooks` |
| `webhooks/unsubscribe/{id}` | `DELETE /webhooks/{id}` |

## No v4 equivalent

- `userAuth/modify`, `userAuth/delete`, `userAuth/verify`, `userAuth/versionCheck` — replaced by OAuth; there is no username/password login or version probe.
- `{module}/filters` — no endpoint lists filters; use the schema.
- `tasks/sorting` — no manual task ordering.
- `customFields/view`, `customFields/modify` — custom field definitions are read-only in v4 (`GET /{module}/custom-fields`).
- `addresses/list` — the lookup of distinct countries, cities, streets and zip codes has no counterpart. `GET /contact-addresses` returns contacts' actual addresses.
- `files/addRelation`, `files/removeRelation` — upload the file under the entity (`POST /{entity}/{id}/files`) instead of relating it afterwards.
- `triggers/*` — automation triggers are not exposed in v4.
- `depot/*` — depots are not exposed in v4.
- `relations` relation names, comments and default flags — v4 keeps only the link (`relatedCompanyIds`).
- Creating time entries on calendar events — v4 creates time entries only under tasks.

## Porting steps

Work through these in order:

1. **Register an OAuth app** in the Scoro Developer Portal and obtain a token. See `references/getting-started.md`.
2. **Find every v2 call** in the codebase: search for `/api/v2/` URLs, for the `"request":` wrapper, and for `apiKey`, `user_token` and `company_account_id` keys in request bodies.
3. **Map each `module/action` pair to v4** using the tables above, and list the calls that have no equivalent before you start.
4. **Remove envelope parsing**: replace `response.data` access with direct field access, and `response.status === "OK"` checks with HTTP status code checks.
5. **Restructure requests**: the record's fields move out of `request` into the JSON body; `per_page`, `page`, `filter` and `include_deleted` become the `perPage`, `page`, `filters[...]` and `filters[isDeleted]` query params in `filters[key][]=value` syntax; `bookmark` becomes `filters[bookmarkId]`. Drop `lang`, `return_data`, `detailed_response` and `basic_data`.
6. **Rename fields** from snake_case to camelCase, taking the exact names from the schema or a generated client.
7. **Convert value types**: `HH:ii:ss` durations → seconds, `1`/`0` → `true`/`false`, datetimes always with a timezone offset.
8. **Move line item updates** to the `/lines` upsert endpoints; keep lines embedded on create.
9. **Replace `modified_date` + `include_deleted` polling** with `filters[modifiedDateTime][from]` plus a separate `filters[isDeleted]=true` query, or webhooks.
10. **Move `company_account_id`** from the request body to the `Scoro-Company-Account` header, and drop the `scoro-app-id` header.
11. **Update custom field writes** to a `customFields` object: `{"customFields": {"c_field": value}}`.
12. **Test against a v4 sandbox**: verify field names in responses match expectations, and confirm pagination stops on a short page.
