---
name: api-best-practices
description: Scoro API v4 best practices for AI coding agents — auth, conventions, data model, and common integration patterns.
---

# Scoro API v4 Best Practices

**Base URL:** `https://{yoursite}.scoro.com/api/v4` — replace `{yoursite}` with your Scoro subdomain.

**Auth:** OAuth 2.0 Bearer token — `Authorization: Bearer <token>`. See `references/getting-started.md`.

**Schema and docs:** The API conforms fully to **OpenAPI 3.1**. The current schema is at `https://api.scoro.com/api/v4/reference/openapi` and the browsable reference is at `https://api.scoro.com/api/v4/reference`. **Strongly recommended:** generate a typed client in your language from that schema with [openapi-generator](https://github.com/openapitools/openapi-generator) instead of hand-writing request code — it gives you exact paths, field names, enums and request bodies. When this skill and the schema disagree, the schema wins.

**Multi-entity sites:** The `Scoro-Company-Account: <identifier>` header selects the company account; without it the user's default account is used. The identifier is a string (e.g. `"mycompany"`) from the `accounts` array in `GET /users/me`. Send it on every request on sites with more than one account.

**Pagination:** `page` starts at 1, `perPage` default 20 max 100. Response is a bare array with no total count — stop when a page returns fewer items than `perPage`.

**Statuses:** Fields named `status` expect the status **code** (a string like `"active"`) from `GET /statuses?filters[modules][]=tasks` — never a numeric ID. Invoices, prepayments, bills, and expenses use fixed values: `"paid"`, `"unpaid"`, `"voided"`.

## Integration Routing

| Use case | Reference |
|---|---|
| Auth setup, first API call | `references/getting-started.md` |
| Paging, sorting, filters, writes, lines, errors, rate limits, scopes, webhooks | `references/conventions.md` |
| Creating linked objects in the right order | `references/data-model.md` |
| Sync contacts, companies, or quotes from a CRM | `references/crm.md` |
| Export invoices, payments, or quotes to accounting | `references/finance.md` |
| Sync expenses, bills, or purchase orders | `references/purchasing.md` |
| Availability, bookings, time off, resource planning | `references/planning.md` |
| Projects, tasks, reporting | `references/projects-and-tasks.md` |
| Log or sync time entries | `references/time-tracking.md` |
| Port v2 code to v4 | `references/migration.md` |
| Generating a client, looking up any endpoint or field | `https://api.scoro.com/api/v4/reference/openapi` (schema) and `https://api.scoro.com/api/v4/reference` (docs) |
| Files, comments, PDFs, scheduled invoices, prepayments, retainers, custom modules | Not covered here — use the schema; the conventions still apply |

## Critical Rules

1. Read statuses from `GET /statuses` before creating or updating any object that has a `status` field. Send the `code` string, never the numeric `id`.
2. Confirm before executing: deletes, bulk writes, settings changes, and anything that would send email to a client or contact.
3. Never print, log, store, or commit OAuth tokens or client secrets.
4. `PATCH` takes partial request bodies — send only the fields you want to change. `null` clears a field only where the schema allows it; elsewhere it is a `400`.
5. Array fields like `relatedCompanyIds` on a person **replace the entire array** on update. Always read the current value and include all IDs you want to keep.
6. Lists exclude deleted records, so a `modifiedDateTime` sync never sees deletions — poll `filters[isDeleted]=true` with `deletedDateTime`, or subscribe to webhooks. See `references/conventions.md`.
7. Prefer a client generated from the OpenAPI schema over hand-written HTTP calls. If you must write calls by hand, take every path, field name and enum from the schema, not from memory.
8. Custom fields go inside a `customFields` object keyed by field `id`. Document lines go in a `lines` array on create, or in `{"lines": [...]}` on `POST /{document}/{id}/lines`, which is an upsert.
