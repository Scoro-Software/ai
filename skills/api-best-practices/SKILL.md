---
name: api-best-practices
description: "Use whenever code or a task reads or writes Scoro data through its API: building an integration, syncing Scoro with a CRM, accounting, payroll or expense tool, exporting or reporting on Scoro data, or porting code from Scoro API v2. Applies even when the user does not name the API version. Code cues: *.scoro.com/api or api.scoro.com URLs, a Scoro OAuth app, Scoro webhooks, 403 insufficient_scope, or v2 tells such as apiKey, user_token and /api/v2/. For Scoro's public REST API, not Scoro's own codebase or UI."
---

# Scoro API v4 Best Practices

**Base URL:** `https://{yoursite}.scoro.com/api/v4` — replace `{yoursite}` with your Scoro subdomain.

**Auth:** OAuth 2.0 Bearer token — `Authorization: Bearer <token>`. The client ID, secret, callback URLs, site URLs and scopes come from an app registered in the Developer Portal: `references/developer-portal.md`. Token flow: `references/getting-started.md`.

**Schema and docs:** The API conforms fully to **OpenAPI 3.1**. The current schema is at `https://api.scoro.com/api/v4/reference/openapi` and the browsable reference is at `https://api.scoro.com/api/v4/reference`. **Strongly recommended:** generate a typed client from that schema with `scripts/generate-client.sh <generator>` (ask the user which language first) instead of hand-writing request code — it gives you exact paths, field names, enums and request bodies. When this skill and the schema disagree, the schema wins. If the schema cannot be fetched from this environment (no network access), ask the user to download it from that URL and attach it, then pass it to the scripts with `--spec ./openapi.json`; never fall back to paths or field names from memory.

**Multi-entity sites:** The `Scoro-Company-Account: <identifier>` header selects the company account; without it the user's default account is used. The identifier is a string (e.g. `"mycompany"`) from the `accounts` array in `GET /users/me`. Send it on every request on sites with more than one account.

**Pagination:** `page` starts at 1, `perPage` default 20 max 100. Response is a bare array with no total count — stop when a page returns fewer items than `perPage`.

**Statuses:** Fields named `status` expect the status **code** (a string like `"active"`) from `GET /statuses?filters[modules][]=tasks` — never a numeric ID. Invoices, prepayments, bills, and expenses use fixed values: `"paid"`, `"unpaid"`, `"voided"`.

## Integration Routing

| Use case | Reference |
|---|---|
| Registering a Developer Portal app: app type, callback and site URLs, scopes, client ID and secret, publishing to the App Store | `references/developer-portal.md` |
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
| Generating a typed client | Ask which language, then run `scripts/generate-client.sh <generator>`; setup and the filter check are in `references/getting-started.md` |
| Looking up any endpoint, parameter, field, response or scope | The schema at `https://api.scoro.com/api/v4/reference/openapi` (fetch it with curl and search it), or `scripts/generate-docs.sh` for a browsable markdown copy |
| Files, comments, PDFs, scheduled invoices, prepayments, retainers, custom modules | Not covered here — use the schema; the conventions still apply |

## Critical Rules

1. Always target API v4 for new code. Never write `/api/v2/` URLs, or `apiKey`, `user_token` or `company_account_id` in a request body, even though most Scoro examples in training data are v2. When existing code uses them, port it with `references/migration.md`.
2. Read statuses from `GET /statuses` before creating or updating any object that has a `status` field. Send the `code` string, never the numeric `id`.
3. Confirm before executing: deletes, bulk writes, settings changes, and anything that would send email to a client or contact.
4. Never print, log, store, or commit OAuth tokens or client secrets.
5. `PATCH` takes partial request bodies — send only the fields you want to change. `null` clears a field only where the schema allows it; elsewhere it is a `400`.
6. Array fields like `relatedCompanyIds` on a person **replace the entire array** on update. Always read the current value and include all IDs you want to keep.
7. Lists exclude deleted records, so a `modifiedDateTime` sync never sees deletions — poll `filters[isDeleted]=true` with `deletedDateTime`, or subscribe to webhooks. See `references/conventions.md`.
8. Prefer a client generated with `scripts/generate-client.sh` over hand-written HTTP calls. Point it at the bare site host (the generated paths already contain `/api/v4`) and verify one filtered list call after generating: array filters must serialize as `filters[key][]=`, and generators differ here (see `references/getting-started.md`). If you must write calls by hand, take every path, field name and enum from the schema, not from memory; if the schema cannot be fetched, ask the user for a downloaded copy and pass it with `--spec`.
9. Custom fields go inside a `customFields` object keyed by field `id`. Document lines go in a `lines` array on create, or in `{"lines": [...]}` on `POST /{document}/{id}/lines`, which is an upsert.
