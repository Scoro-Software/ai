# Getting Started with Scoro API v4

## Table of contents
- Registering a Developer Portal app
- Generating a client from the OpenAPI schema
- Getting a token
- Refreshing the token
- Making the first call
- Multi-entity sites
- Traps to avoid

## Registering a Developer Portal app

Register at [developer.scoro.com](https://developer.scoro.com).

- **Private apps** are tied to specific Scoro sites and work without review — use for internal integrations and development.
- **Public apps** (for distribution to other Scoro customers) require Scoro review before they work on sites you don't own.
- Select the scopes your integration needs. A token can never hold more than the app's configured scopes — requesting more is silently narrowed to what is configured. `base:r` (reference data such as statuses, tax rates and `/users/me`) is added to every token automatically. In production, always request least-privilege scopes.
- The **client secret is shown once** at creation — copy it immediately. If lost, rotate it from the portal.

Scope format is `{resource}:{level}` with `r` (read) < `rw` (read + write) < `rwd` (read + write + delete). Resource names do not always match URL paths — companies and persons are `contacts:*`, time entries are `tasks:*`. See `references/conventions.md`.

## Generating a client from the OpenAPI schema

The API conforms fully to **OpenAPI 3.1**. The schema is always current at `https://api.scoro.com/api/v4/reference/openapi`, and `https://api.scoro.com/api/v4/reference` renders it as browsable docs with a try-it console.

Generate a typed client in your language with [openapi-generator](https://github.com/openapitools/openapi-generator) before writing any request code. The generated client carries the exact paths, field names, enums and required fields, so most of the mistakes this skill warns about become compile-time errors. Use a recent generator release (7.x or newer) for OpenAPI 3.1 support.

```bash
# TypeScript example — swap -g for python, java, csharp, go, php, kotlin, ruby, ...
npx @openapitools/openapi-generator-cli generate \
  -i https://api.scoro.com/api/v4/reference/openapi \
  -g typescript-fetch \
  -o ./scoro-client
```

Configure the generated client with the site base URL, the bearer token, and (on multi-account sites) the `Scoro-Company-Account` header. Everything else in this skill — pagination, status codes, line upserts, booking units — still applies; the client only guarantees the shapes, not the semantics.

## Getting a token

Developer Portal apps use **OAuth 2.0 authorization code flow with PKCE** — a browser sign-in is required to obtain the first token.

Flow:
1. Build the authorization URL with your `client_id`, `redirect_uri`, PKCE `code_challenge`, and requested `scope`. Include `offline_access` in scope to receive a refresh token.
2. Open the URL in a browser. The user signs in and approves the scopes.
3. Exchange the returned `code` for tokens using `POST https://{yoursite}.scoro.com/auth/oauth/token` with `grant_type=authorization_code` and your `code_verifier`.

The response contains:
- `access_token` — include in every API request as `Authorization: Bearer <access_token>`
- `refresh_token` — use this to get new tokens without a browser (requires `offline_access` scope)
- `expires_in` — access token lifetime in seconds. Access tokens are short-lived; use this value rather than assuming a lifetime.
- `scope` — the scopes actually granted. Compare it with what you requested.

## Refreshing the token

Refresh before the access token expires:

```http
POST https://{yoursite}.scoro.com/auth/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&client_id=<your_client_id>
&client_secret=<your_client_secret>
&refresh_token=<your_refresh_token>
```

`client_secret` is for confidential clients; a public (PKCE-only) client omits it.

Store the `access_token` and `refresh_token` from every response and use the latest refresh token next time. Refreshing extends the refresh token's lifetime. Do **not** send `scope` on a refresh request: a refresh that names scopes is narrowed to those scopes, and nothing but a new authorization can widen a grant.

## Making the first call

Verify the token and discover accessible company accounts:

```http
GET /users/me
Authorization: Bearer <access_token>
```

Response includes the authenticated user's profile, an `accounts` array listing every Scoro company account (business entity) the user can access, `enabledPermissions`, and the user's formatting preferences (`baseCurrency`, `dateFormat`, `timeFormat`, `thousandSeparator`, `decimalSeparator`). The `accounts` values are **string identifiers** (e.g. `["mycompany", "mycompany_uk"]`) — use one of these in the `Scoro-Company-Account` header.

## Multi-entity sites

Some Scoro sites run multiple business entities (company accounts) under one login.

- The `Scoro-Company-Account: <identifier>` header is **optional**. Without it, the request runs on the user's default account.
- Set it to one of the string values from the `accounts` array in `/users/me` (e.g. `"mycompany"`). It is matched case-insensitively.
- Naming an account the user cannot access returns `403`.
- Some resources are scoped to the account from the header — tax rates, for example, are returned for that account only. On a site with more than one account, send the header on every request so you always know which account you are reading from or writing to.

```http
GET /tasks
Authorization: Bearer <access_token>
Scoro-Company-Account: mycompany
```

## Traps to avoid

- **Status fields expect a code string, not a numeric ID.** The `status` field on tasks, projects, quotes, orders and purchase orders takes the status `code` value from `GET /statuses` (e.g. `"active"`, `"won"`), not the numeric `id`. The spec describes the field as a "status ID", which is misleading — always read statuses first.
- **The first token needs a browser.** Headless integrations still require a one-time sign-in. Automate token refresh with `offline_access` after the initial authorization.
- **Client secret shown once.** There is no way to retrieve it after initial creation. Rotate it from the Developer Portal if lost.
- **Scope changes require re-authorization.** Adding a scope to the app's configuration does not add it to existing tokens — the user must go through the OAuth flow again. Removing a scope takes effect on the next refresh.
- **Omit `scope` when refreshing.** A refresh request that lists scopes gets only those scopes.
