# Getting Started with Scoro API v4

## Table of contents
- Registering a Developer Portal app
- Getting a token
- Refreshing the token
- Making the first call
- Multi-entity sites
- Traps to avoid

## Registering a Developer Portal app

Register at [developer.scoro.com](https://developer.scoro.com).

- **Private apps** work on up to 3 Scoro sites without review — use for internal integrations and development.
- **Public apps** (for distribution to other Scoro customers) require Scoro review before they work on sites you don't own.
- Select the minimum scopes your integration needs. If no scopes are selected, the app receives `scoro:all`. In production, always request least-privilege scopes.
- The **client secret is shown once** at creation — copy it immediately. If lost, rotate it from the portal.

Scope hierarchy: `r` (read) < `rw` (read + write) < `rwd` (read + write + delete). Request only what you need.

## Getting a token

Scoro uses **OAuth 2.0 authorization code flow with PKCE**. There is no `client_credentials` grant — a browser sign-in is required to obtain the first token.

Flow:
1. Build the authorization URL with your `client_id`, `redirect_uri`, PKCE `code_challenge`, and requested `scope`. Include `offline_access` in scope to receive a refresh token.
2. Open the URL in a browser. The user signs in and approves the scopes.
3. Exchange the returned `code` for tokens using `POST https://{yoursite}.scoro.com/auth/oauth/token` with `grant_type=authorization_code` and your `code_verifier`.

The response contains:
- `access_token` — include in every API request as `Authorization: Bearer <access_token>`
- `refresh_token` — use this to get new tokens without a browser (requires `offline_access` scope)
- `expires_in` — access token lifetime in seconds

## Refreshing the token

Access tokens have a sliding 30-day window. Refresh before expiry using:

```http
POST https://{yoursite}.scoro.com/auth/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&client_id=<your_client_id>
&client_secret=<your_client_secret>
&refresh_token=<your_refresh_token>
```

Store the new `access_token` and `refresh_token` from the response. The old refresh token is invalidated.

## Making the first call

Verify the token and discover accessible company accounts:

```http
GET /users/me
Authorization: Bearer <access_token>
```

Response includes the authenticated user's profile and an `accounts` array listing every Scoro company account (business entity) the user can access. The values are **string identifiers** (e.g. `["mycompany", "mycompany_uk"]`) — use one of these in the `Scoro-Company-Account` header.

## Multi-entity sites

Some Scoro sites run multiple business entities (company accounts) under one login. When a site has multiple entities:

- **All requests** must include `Scoro-Company-Account: <identifier>` in the header, where `<identifier>` is one of the string values from the `accounts` array in `/users/me` (e.g. `"mycompany"`).
- Omitting this header on a multi-entity site returns a 400 error.
- Each company account has isolated data — contacts, projects, invoices, etc. are not shared between accounts.

```http
GET /tasks
Authorization: Bearer <access_token>
Scoro-Company-Account: mycompany
```

## Traps to avoid

- **Status fields expect a code string, not a numeric ID.** Fields named `status` or `statusId` on tasks, projects, quotes, and orders take the status `code` value from `GET /statuses` (e.g. `"active"`, `"won"`), not the numeric `id` field. The field name is misleading — always read statuses first.
- **No `client_credentials` grant.** Headless integrations still require a one-time browser sign-in. Automate token refresh with `offline_access` after the initial authorization.
- **Client secret shown once.** There is no way to retrieve it after initial creation. Rotate it from the Developer Portal if lost.
- **Scope changes require re-authorization.** Adding a scope to an existing app requires the user to re-approve the OAuth flow — a new token with the old scopes won't gain access to the new ones.
