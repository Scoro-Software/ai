---
name: api-best-practices
description: Scoro API v4 best practices for AI coding agents — auth, conventions, data model, and common integration patterns.
---

# Scoro API v4 Best Practices

**Base URL:** `https://{yoursite}.scoro.com/api/v4` — replace `{yoursite}` with your Scoro subdomain.

**Auth:** OAuth 2.0 Bearer token — `Authorization: Bearer <token>`. See `references/getting-started.md`.

**Multi-entity sites:** Pass `Scoro-Company-Account: <identifier>` header on every request. The identifier is a string (e.g. `"mycompany"`) — get the list from the `accounts` array in `GET /users/me`.

**Pagination:** `page` starts at 1, `perPage` default 20 max 100. Response is a bare array with no total count — stop when a page returns fewer items than `perPage`.

**Statuses:** Fields named `status` expect the status **code** (a string like `"active"`) from `GET /statuses` — never a numeric ID. Invoices, bills, and expenses use fixed values: `"paid"`, `"unpaid"`, `"voided"`.

## Integration Routing

| Use case | Reference |
|---|---|
| Auth setup, first API call | `references/getting-started.md` |
| Paging, filters, writes, errors, retries | `references/conventions.md` |
| Creating linked objects in the right order | `references/data-model.md` |
| Sync contacts, companies, or quotes from a CRM | `references/crm.md` |
| Export invoices, payments, or quotes to accounting | `references/finance.md` |
| Sync expenses, bills, or purchase orders | `references/purchasing.md` |
| Availability, bookings, time off, resource planning | `references/planning.md` |
| Projects, tasks, reporting | `references/projects-and-tasks.md` |
| Log or sync time entries | `references/time-tracking.md` |
| Port v2 code to v4 | `references/migration.md` |

## Critical Rules

1. Read statuses from `GET /statuses` before creating or updating any object that has a `status` field. Send the `code` string, never the numeric `id`.
2. Confirm before executing: deletes, bulk writes, settings changes, and anything that would send email to a client or contact.
3. Never print, log, store, or commit OAuth tokens or client secrets.
4. `PATCH` takes partial request bodies — send only the fields you want to change.
5. Array fields like `relatedCompanyIds` on a person **replace the entire array** on update. Always read the current value and include all IDs you want to keep.
