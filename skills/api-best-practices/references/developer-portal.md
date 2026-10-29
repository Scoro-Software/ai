# Registering an App in the Scoro Developer Portal

Every API v4 integration authenticates as a Developer Portal app. The app holds the OAuth client ID and secret, the callback URLs, the Scoro sites it may issue tokens for, and the scopes a token can carry. This guide walks through registering one and explains every choice. Getting a token and making the first call are in `references/getting-started.md`.

## Table of contents
- Before you start
- Sign in
- Create the app
- Choices on the Setup tab: app type, authentication type, grant type, callback URLs, site URLs, access (scopes), app profile
- Generate the OAuth credentials
- What goes into your configuration
- Changing an app later
- Publishing a public app to the App Store
- App statuses
- Traps to avoid

## Before you start

- **A Scoro site to connect to.** Tokens are issued per Scoro site, and the app lists the sites it may be used on. Develop against a separate trial site so you never test on live customer data; the portal links to the free trial sign-up.
- **A Google or Microsoft account.** The portal has no password login.
- **The list of endpoints the integration calls.** The scopes you select come from those endpoints (see "Scopes and permissions" in `references/conventions.md`).

## Sign in

Open [developers.scoro.com](https://developers.scoro.com) and choose **Continue with Google** or **Continue with Microsoft**. A developer account is created automatically on the first sign-in; use the same provider to log in next time. You land on the **Apps** list.

Open **Developer site configuration** (the settings page) once and enter your Scoro site URL, for example `https://acme.scoro.com`. It pre-fills the Site URLs of every app you create afterwards. The **User token** field on the same page belongs to API v2 and is not needed for an API v4 app.

## Create the app

1. Click **Create app**. The editor opens with a header (app name, app type) and the **Setup** tab.
2. Fill in the name and the Setup tab (every choice is explained below). The first save needs: a name (3 to 255 characters, unique), the app type, the authentication type, at least one callback URL, and at least one site URL. Category, description and logo can wait.
3. Click **Save**. The portal creates the app and opens its edit page. The header now shows the **App ID** and the status **Not published**, and the Setup tab shows the **OAuth credentials** card.
4. Click **Generate OAuth credentials** and copy the client ID and the secret (details below).

A private app is ready to use at this point. A public app continues with the App Store profile and Submit for review tabs (see "Publishing a public app").

## Choices on the Setup tab

### App type

| Type | Use it for | What it means |
|---|---|---|
| **Private** (default) | Internal integrations, one customer's own tooling, development | Only the Setup tab exists. No review. The app works only on the Scoro sites listed under Site URLs (up to 3). |
| **Public** | An integration you distribute to other Scoro customers | Adds the App Store profile and Submit for review tabs. Until Scoro publishes it, the app is restricted to its Site URLs like a private one. Once published it is listed in the Scoro App Store and any Scoro site can connect. |

Other types visible in the portal (Scoro Integration, Scoro App, via Zapier) are assigned by Scoro and cannot be chosen by partners. Start private: you can switch to Public later and fill in the listing then.

### Authentication type

Choose the **OAuth** option (labelled API v4). The other two, **API key** and **User token**, are API v2, are marked deprecated, and do not work against `/api/v4`.

The rest of this guide assumes OAuth. The authentication type is fixed after the first save, so decide before saving.

### Grant type (nothing to choose)

There is no grant type selector for partner apps. Every app uses the **authorization code** grant with PKCE: a Scoro user signs in once in a browser and approves the scopes, and every token acts as that user, with that user's permissions. The client credentials grant (server-to-server, no user) is not available to partner apps. A headless job therefore still needs one browser sign-in; after that it runs unattended on refresh tokens (request `offline_access`, see `references/getting-started.md`). A job that stays paused for a long time may find its refresh token expired and need a new sign-in.

### Callback URLs

The URLs Scoro may redirect to after the user signs in. The `redirect_uri` in your authorization request must match one of them exactly.

- 1 to 10 URLs; at least one is required.
- Accepted: `https://` URLs (plain `http://` too), custom schemes for desktop and mobile apps such as `myapp://oauth`, and `localhost` or `127.0.0.1` with an optional port and path, with or without a scheme (`http://localhost:8080/callback`). Rejected: `javascript:`, `data:`, `vbscript:` and `file:` URLs, and any URL containing a space.
- A server-side job that signs in once can use a localhost URL served by a throwaway script during that sign-in.
- Removing a URL that a running integration still uses breaks its sign-in flow; the portal asks for confirmation.

### Site URLs

The Scoro sites this app may issue tokens for.

- 1 to 3 entries, each an `https://*.scoro.com` address such as `https://acme.scoro.com`. Only the origin is kept, and each entry must be a different site.
- Required while the app is private, or public but not yet published. The first entry is pre-filled from Developer site configuration.
- A sign-in from a site that is not listed fails, so list both the trial site and the production site if you develop on one and run on the other.
- When a public app is published the restriction is lifted and the list is cleared. It applies again if the app is unpublished.

### Access (scopes)

Click **Manage access** to choose what the app may read and change. Access is grouped (Contacts, Quotes and orders, Invoicing and payments, Purchases and expenses, Finance configuration, Projects and budgets, Tasks and time tracking, Resource planning and time off, Calendar and meetings, Work management configuration, Custom modules, Communication, Files, Site configuration, Users, roles and labor costs, AI assistant, Webhooks), and each group has a level:

| Level | Scope suffix | Allows |
|---|---|---|
| Off | — | nothing in this group |
| View | `:r` | read |
| Edit | `:rw` | read, create, update |
| Full | `:rwd` | read, create, update, delete |

Expand a group to set a level per resource instead of for the whole group. **Basic information** (`base:r`: `/users/me`, statuses, tax rates, currencies, roles, tags, units and custom-field definitions) is always on and cannot be switched off. Setting a group level can also switch on reads in other groups it depends on; Contacts, for example, turns on View for client profiles under Finance configuration. The picker lists these under "Depends on".

Where to find a resource in the picker (the scope is `{resource}:{level}`; the operation's `security` entry in the schema is authoritative):

| Group | Resources |
|---|---|
| Contacts | `contacts` (companies and persons), `contact-categories`, `contact-relation-types` |
| Quotes and orders | `quotes`, `orders` |
| Invoicing and payments | `invoices`, `invoice-payments`, `prepayments`, `payment-accounts` |
| Purchases and expenses | `bills`, `bill-payments`, `expenses`, `purchase-orders` |
| Finance configuration | `products`, `product-groups`, `price-lists`, `client-profiles`, `finance-accounts`, `accounting-objects`, `company-bank-accounts`, `quote-templates`, `pdf-templates`, `currencies`, `tax-rates`, `units` |
| Projects and budgets | `projects`, `retainers`, `retainer-periods`, `revenue-forecast-periods` |
| Tasks and time tracking | `tasks` (includes time entries), `task-bundles`, `time-trackers` |
| Resource planning and time off | `bookings`, `availability`, `time-offs` |
| Calendar and meetings | `calendar`, `event-resources` |
| Work management configuration | `activity-types`, `project-templates` |
| Custom modules | `custom-modules` |
| Communication | `comments`, `notifications`, `sent-emails` |
| Files | `files` |
| Site configuration | `settings`, `company-settings`, `statuses`, `tags`, `time-off-types`, `bookmarks` |
| Users, roles and labor costs | `users`, `user-groups`, `roles`, `permission-sets`, `labor-costs` |
| AI assistant | `ai` |
| Webhooks | `webhooks` |

Reference resources that Basic information already covers for reading (currencies, tax rates, units, statuses, tags, roles) have no View level of their own; only Edit or Full appears for them.

What matters for the integration:

- **Never save an app without opening Manage access.** Left untouched, the access is saved as full access (`scoro:all`) or, in newer portal versions, as Basic information only; the first is far too broad and the second lets no integration work. Derive the list from the endpoints you call, keep the highest level per resource, and select exactly those. **Copy scopes** in the picker copies the selected list as text, so you can compare it with the scopes the schema names for each operation. Read-only integrations never need Edit or Full.
- Scope names are `{resource}:{level}`, and the resource is the OAuth resource, not the URL path: companies and persons are `contacts`, time entries are `tasks`, payments and their allocations are `invoice-payments`. When in doubt, take the scope from the operation's `security` entry in the schema.
- A token can never hold more scopes than the app's access list. `offline_access` is not part of that list: request it in the authorization request, and it is granted alongside the app's scopes.
- Adding access later does not widen existing tokens; the user has to sign in again. Removing access takes effect on the next token refresh.
- Scopes are necessary, not sufficient. The user who signs in also needs the module and the permission in Scoro.

### App profile

- **App logo:** optional. JPG or PNG up to 10 MB, cropped between square and 2:1.
- **Category:** optional on save, required to submit a public app for review.
- **Short description:** optional on save, required to submit for review. Keep it under 150 characters.

## Generate the OAuth credentials

On the saved app's Setup tab click **Generate OAuth credentials**. The portal creates the OAuth client and shows the **client secret once**, in a dialog. Copy it before closing; it cannot be displayed again. The **OAuth Client ID** stays on the card with a copy button, next to the date the active secret was created.

- **The App ID is not the client ID.** The App ID in the header identifies the app record in the portal. The OAuth Client ID on the credentials card is the `client_id` for the token flow. They are different values, and the client ID only exists after you generate credentials.
- **Rotate client secret** issues a new secret (shown once) and asks how long the current one keeps working: immediately, 1 hour, 24 hours (the default) or 7 days. Update your configuration within that window. Only one previous secret can stay valid at a time, so rotating again ends the earlier grace period early. Choose "Immediately" if the secret has leaked.
- Revoking the credentials altogether, which also discards the client ID, is done by Scoro. Contact support if you need it.

## What goes into your configuration

| Value | Where it comes from |
|---|---|
| `client_id` | OAuth Client ID on the Setup tab |
| `client_secret` | Shown once when generated or rotated. Every portal app has one, so send it on token and refresh requests |
| Authorization endpoint | `https://{yoursite}.scoro.com/auth/oauth/authorize` |
| Token endpoint | `https://{yoursite}.scoro.com/auth/oauth/token` |
| `redirect_uri` | One of the app's callback URLs, character for character |
| `scope` in the authorization request | The scopes you need (within the app's access) plus `offline_access` for a refresh token |
| API base URL | `https://{yoursite}.scoro.com/api/v4` (the bare host for a generated client) |

`{yoursite}` must be one of the app's Site URLs. Keep the secret and the refresh token in a secret store, never in the repository or in logs. The token flow continues in `references/getting-started.md`.

## Changing an app later

- **Save** on the edit page updates the app. New callback URLs, site URLs and access apply to new sign-ins.
- To add scopes: change the access list, save, and have the user sign in again; issued tokens are never widened. Removed scopes drop out at the next refresh.
- To add a site: add its URL and save. Removing a site stops token issuance for it once the app is saved; do not count on existing refresh tokens for that site continuing to work.
- Switching a private app to Public keeps its setup and credentials; it just adds the two listing tabs.
- Deleting an app disconnects it from every site. The portal asks for confirmation, and you cannot restore it yourself.

## Publishing a public app to the App Store

Only public apps have these tabs. Uploads (screenshots, documents) need a saved app.

**App Store profile**, required before submission: Overview, Key benefits and How it works (rich text); developer name, website URL, support e-mail, help materials URL, terms of use URL and privacy policy URL; at least one screenshot (JPG or PNG, 16:10, up to 3 MB each, up to 12). Optional: a demo video (YouTube or Vimeo), the app landing page URL (where "Get this app" sends users) and a developer logo. The Setup tab's category and short description are required too.

**Submit for review** is a security and data-protection questionnaire:

- Certifications: describe them, or upload the certificate.
- Penetration testing: a text answer and the most recent report; both are required.
- Backups, logging, categories of personal data processed, incidents in the past 36 months, EEA data hosting, sub-processors, third-party breaches: a text answer each.
- Data processing agreement (GDPR Article 28): upload required.
- Consent to Scoro's Privacy Policy and the Developer Terms.
- Additional information: an optional comment to the reviewer.

Documents can be PDF, Word, ODT, RTF, TXT, Excel, ODS, PNG or JPG.

Click **Submit for review**. The portal saves the app first, then moves it to **In review**. The app is read-only until the review ends, which can take up to 30 days; you get an e-mail when the status changes. **Revoke request** takes it back so you can edit and resubmit. A published app stays editable, but changes reach the App Store only after a **Request to re-publish** is approved, and the app is read-only while that request is open. To unpublish, contact Scoro support.

## App statuses

| Status | Meaning |
|---|---|
| Not published | Saved and usable on its site URLs. The default for a new app. |
| Draft | Being edited after a review. A previously published version, if any, stays live. |
| In review | Submitted; read-only until Scoro finishes the review. |
| Published | Listed in the Scoro App Store; any Scoro site can connect. During a re-publish request the live listing stays up. |

## Traps to avoid

- **Using the App ID as `client_id`.** Generate credentials and use the OAuth Client ID.
- **Missing site URL.** No token is issued for a site that is not listed, for private apps and for public apps that are not yet published.
- **Access left at the default.** Open Manage access, select exactly what the endpoints need, and verify with Copy scopes.
- **Expecting a machine-to-machine grant.** Authorization code only: one browser sign-in, then `offline_access` refresh tokens.
- **Picking API key or User token.** Those are API v2; API v4 needs OAuth.
- **`redirect_uri` that does not match a callback URL exactly.** The sign-in fails; add the URL to the app.
- **Losing the secret.** It is shown once; rotate it with a grace period instead of guessing.
- **Adding scopes without a new sign-in.** Existing tokens keep their old scopes.
