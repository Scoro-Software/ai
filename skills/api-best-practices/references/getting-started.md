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

Register at [developers.scoro.com](https://developers.scoro.com) (Google or Microsoft sign-in). The full walkthrough, every option on the form and the publishing flow are in `references/developer-portal.md`. The short version:

- Choose the **OAuth** (API v4) authentication type and, to start, the **Private** app type: private apps work without review on up to 3 Scoro sites you list. **Public** apps are reviewed by Scoro and then listed in the App Store for every customer.
- Add at least one **callback URL** (your `redirect_uri`, matched exactly) and one **site URL** (`https://{yoursite}.scoro.com`).
- Set the **access** (scopes) explicitly. A token can never hold more than the app's configured scopes — requesting more is silently narrowed to what is configured. `base:r` (reference data such as statuses, tax rates and `/users/me`) is added to every token automatically. In production, always request least-privilege scopes.
- Save, then **Generate OAuth credentials**. The **client secret is shown once** — copy it immediately; if lost, rotate it from the portal with a grace period. The `client_id` is the **OAuth Client ID** on that card, not the App ID in the header.

Scope format is `{resource}:{level}` with `r` (read) < `rw` (read + write) < `rwd` (read + write + delete). Resource names do not always match URL paths — companies and persons are `contacts:*`, time entries are `tasks:*`. See `references/conventions.md`.

## Generating a client from the OpenAPI schema

The API conforms fully to **OpenAPI 3.1**. The schema is always current at `https://api.scoro.com/api/v4/reference/openapi`, and `https://api.scoro.com/api/v4/reference` renders it as browsable docs with a try-it console.

Generate a typed client before writing any request code: it carries the exact paths, field names, enums and required fields, so most of the mistakes this skill warns about become compile-time errors. The skill ships starter scripts for this in `scripts/` next to `SKILL.md`. They run an installed [openapi-generator](https://openapi-generator.tech) (verified with 7.26.0; `brew install openapi-generator`, or the npm or pip package, see `scripts/README.md`) and download nothing but the schema. **Ask the user which language they want first**, then run:

```bash
scripts/generate-client.sh typescript-fetch   # or python, go, php: these four get a starter config
scripts/generate-client.sh java               # any other openapi-generator name runs with its defaults
scripts/generate-docs.sh                      # markdown reference: one file per resource and per model
```

Output lands in `./scoro-api-client-<generator>` or `./scoro-api-docs`; pass a second argument for another directory, `--spec` for a local copy of the schema, and anything after `--` goes to the generator (see `scripts/README.md`). The generated Go module still has a placeholder module path: set it in `go.mod`, or pass `-- --git-user-id myorg --git-repo-id scoro-api`.

### Configure the generated client

- **The base URL is the bare site host**, `https://{yoursite}.scoro.com`. The generated paths already contain `/api/v4`; a base URL ending in `/api/v4` sends every request to `/api/v4/api/v4/...`.
- **Bearer token:** every operation is marked OAuth2 in the schema, so each client has a token setting. The TypeScript client sends `accessToken` as-is, so include the `Bearer ` prefix there; Python, Go and PHP add it.
- **`Scoro-Company-Account`** is declared as an optional header parameter on every operation, so every generated method accepts it. Set it once as a default header instead of passing it per call.
- The TypeScript client names the `File` model `ModelFile`, because `File` is a built-in type.

```ts
// typescript-fetch
import { Configuration, TasksApi } from 'scoro-api-client'; // after: npm install ./scoro-api-client-typescript-fetch
const tasks = new TasksApi(new Configuration({
  basePath: 'https://mycompany.scoro.com',
  accessToken: async () => `Bearer ${await getFreshToken()}`,
  headers: { 'Scoro-Company-Account': 'mycompany' },
}));
```

```python
# python
import scoro_api
config = scoro_api.Configuration(host="https://mycompany.scoro.com", access_token=token)
client = scoro_api.ApiClient(config)
client.set_default_header("Scoro-Company-Account", "mycompany")
tasks = scoro_api.TasksApi(client)
```

```go
// go
cfg := scoroapi.NewConfiguration()
cfg.Servers = scoroapi.ServerConfigurations{{URL: "https://mycompany.scoro.com"}}
cfg.AddDefaultHeader("Scoro-Company-Account", "mycompany")
client := scoroapi.NewAPIClient(cfg)
ctx := context.WithValue(context.Background(), scoroapi.ContextOAuth2,
    oauth2.StaticTokenSource(&oauth2.Token{AccessToken: token}))
```

```php
// php
$config = (new \Scoro\Api\Configuration())->setHost('https://mycompany.scoro.com')->setAccessToken($token);
$http = new \GuzzleHttp\Client(['headers' => ['Scoro-Company-Account' => 'mycompany']]);
$tasks = new \Scoro\Api\Api\TasksApi($http, $config);
```

### Filters in generated clients

List endpoints take `filters` as a deep-object query parameter, and the API expects bracket syntax: `filters[ids][]=1&filters[ids][]=2`, `filters[createdDateTime][from]=...`, `filters[customFields][c_region]=north` (see `references/conventions.md`). Numeric indexes such as `filters[ids][0]=1` are accepted too. Generators encode this differently, so after generating, make one list call with an array filter and look at the URL that goes out. Observed with openapi-generator 7.26.0:

| Generator | Sends for `ids: [101, 102]` | Fix |
|---|---|---|
| `typescript-fetch` | `filters[ids]=101&filters[ids]=102`: the key repeats without `[]`, and a PHP-style query parser keeps only the last value, so one id gets through. Ranges, booleans and custom fields are correct. | Pass a `queryParamsStringify` that appends `[]` to array keys (below). |
| `python` | `filters={"ids": [101, 102], ...}`: the whole object JSON-encoded, which the API does not understand. | Subclass `ApiClient` and flatten nested dicts and lists in `parameters_to_url_query` (below). |
| `go` | `filters[ids][0]=101&filters[ids][1]=102`; ranges and booleans correct. | None. |
| `php` | From reading the generated code, not from running it: a plain associative array is flattened correctly with numeric indexes, a `TaskFilter` model object is not, and nested booleans are sent empty. | Pass filters as a plain array with string booleans: `['ids' => [101, 102], 'isDone' => 'false']`. |

```ts
// typescript-fetch: query stringifier that produces filters[key][]=value for arrays
import { Configuration, HTTPQuery } from 'scoro-api-client';

function scoroQuery(params: HTTPQuery, prefix = ''): string {
  return Object.keys(params).map((key) => {
    const fullKey = prefix ? `${prefix}[${key}]` : key;
    const value = params[key];
    if (value === null || value === undefined) return '';
    if (Array.isArray(value)) return value.map((v) => `${encodeURIComponent(`${fullKey}[]`)}=${encodeURIComponent(String(v))}`).join('&');
    if (value instanceof Date) return `${encodeURIComponent(fullKey)}=${encodeURIComponent(value.toISOString())}`;
    if (typeof value === 'object') return scoroQuery(value as HTTPQuery, fullKey);
    return `${encodeURIComponent(fullKey)}=${encodeURIComponent(String(value))}`;
  }).filter((part) => part.length > 0).join('&');
}

const config = new Configuration({ basePath: '...', accessToken: '...', queryParamsStringify: scoroQuery });
```

```python
# python: ApiClient that sends filters[...] in the bracket form the API expects
class ScoroApiClient(scoro_api.ApiClient):
    def parameters_to_url_query(self, params, collection_formats):
        flat = []

        def add(key, value):
            if isinstance(value, dict):
                for sub_key, sub_value in value.items():
                    add(f"{key}[{sub_key}]", sub_value)
            elif isinstance(value, (list, tuple)):
                for item in value:
                    add(f"{key}[]", item)
            elif value is not None:
                flat.append((key, value))

        items = params.items() if isinstance(params, dict) else params
        for key, value in items:
            if key in collection_formats:  # sort and other comma-joined lists stay as they are
                flat.append((key, value))
            else:
                add(key, value)
        return super().parameters_to_url_query(flat, collection_formats)

client = ScoroApiClient(config)
```

Success looks like a `200` whose items match the filter. An unfiltered page, or a `400`, means the encoding is still wrong. File upload endpoints accept either multipart form data or a JSON body naming a URL; check which variant the generated method exposes before uploading. Everything else in this skill (pagination, status codes, line upserts, booking units) still applies: the client guarantees the shapes, not the semantics.

## Getting a token

Developer Portal apps use **OAuth 2.0 authorization code flow with PKCE** — a browser sign-in is required to obtain the first token. The client credentials grant is not available to partner apps.

Flow:
1. Build the authorization URL, `https://{yoursite}.scoro.com/auth/oauth/authorize`, with your `client_id` (the OAuth Client ID from the app's Setup tab), `redirect_uri` (one of the app's callback URLs, matched exactly), PKCE `code_challenge`, and requested `scope`. Include `offline_access` in scope to receive a refresh token. The user who signs in must belong to one of the app's site URLs.
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

Developer Portal apps always receive a client secret, so send it. Only a public (PKCE-only) client without a secret would omit it.

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
- **Client secret shown once.** There is no way to retrieve it after initial creation. Rotate it from the Developer Portal if lost; rotation keeps the old secret valid for a grace period you choose (immediately, 1 hour, 24 hours or 7 days).
- **App ID is not `client_id`.** Use the OAuth Client ID shown after generating credentials; the App ID only identifies the portal record.
- **Scope changes require re-authorization.** Adding a scope to the app's configuration does not add it to existing tokens — the user must go through the OAuth flow again. Removing a scope takes effect on the next refresh.
- **Omit `scope` when refreshing.** A refresh request that lists scopes gets only those scopes.
