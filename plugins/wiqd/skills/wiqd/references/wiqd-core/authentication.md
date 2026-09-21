# OAuth Authentication for M365 Agent Plugins

This guide explains how to configure OAuth authentication for MCP server plugins and API plugins in your M365 Copilot agent. It covers endpoint discovery, credential acquisition, PKCE, the `oauth/register` lifecycle step in `m365agents.yml`, how to recover a registration that was created with the wrong values, and the platform constraints that make Entra-protected servers more expensive than they look.

> **When to use this guide:**
>
> - Your MCP server requires OAuth authentication (most third-party MCP servers do)
> - Your API plugin requires OAuth (not just API key auth)
> - You need to register OAuth credentials in the Teams Developer Portal via wiqd

> **When NOT to use this guide:**
>
> - The MCP server or API is unauthenticated → use `"auth": {"type": "None"}` directly
> - You're using API key authentication → handle via environment variables in the OpenAPI spec

---

## Overview

Authenticated plugins use a three-part setup:

1. **Discover** OAuth endpoints from the server's well-known metadata
2. **Obtain** client credentials (via Dynamic Client Registration or manual entry)
3. **Register** the OAuth configuration in `m365agents.yml` so wiqd provisions it in the Teams Developer Portal

The result is a `<PREFIX>_MCP_AUTH_ID` environment variable that the plugin manifest references via `OAuthPluginVault`.

> **⛔ Read this first if the server is Microsoft-hosted / Entra-protected** (`*.azure.com`, `*.microsoft.com`, anything whose authority is `login.microsoftonline.com`). Two things in this guide do **not** apply, and discovering that the hard way costs hours:
>
> - **Dynamic Client Registration cannot work.** Entra implements no RFC 7591 `registration_endpoint`. Skip Step 2's DCR path entirely — see [Entra does not support DCR](#entra-does-not-support-dcr).
> - **You will have to register an Entra application by hand.** `agentConnectors` has no `microsoftEntra` auth type, so the only OAuth-capable connector type is `OAuthPluginVault`, which needs a `clientId` you own — even when the resource is a first-party Microsoft API. See [Platform constraints](#platform-constraints-read-before-estimating).


---

## Step 1: OAuth Endpoint Discovery

Attempt to auto-discover OAuth endpoints from the server's well-known metadata. Try **both** URLs in parallel:

```
GET <SERVER_ROOT>/.well-known/oauth-authorization-server
GET <SERVER_ROOT>/.well-known/openid-configuration
```

Where `<SERVER_ROOT>` is the scheme + host of the server URL (e.g., `https://mcp.example.com`).

### Field Mapping

| Plugin field       | Well-known field                                                                                                                                                                                                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `authorizationUrl` | `authorization_endpoint`                                                                                                                                                                                                                                                                          |
| `tokenUrl`         | `token_endpoint`                                                                                                                                                                                                                                                                                  |
| `refreshUrl`       | `token_endpoint` (same endpoint handles refresh grants)                                                                                                                                                                                                                                           |
| `scope`            | `scopes_supported` → join with comma (e.g., `"openid,email,profile"`). If no scopes are discovered or provided, default to `"openid"`. **If `scope` has no value, it MUST be quoted as `""`** — a bare `scope:` with no value is YAML null, not an empty string, and will fail schema validation. |

### If discovered

Show the values to the user and confirm:

> "I found the following OAuth endpoints for [name]. Shall I use these?
>
> - Authorization URL: ...
> - Token URL: ...
> - Refresh URL: ...
> - Scopes: ..."

### If not discovered

Ask the user to provide the four values. If the user doesn't have them, offer:

> "I can search for these values online — shall I proceed?"

Only search if the user confirms. Show results and confirm before using.

---

## Step 2: Client Credentials

### Entra does not support DCR

**Before probing for DCR, check whether the server is Entra-protected** — its `authorization_endpoint`/`token_endpoint` from Step 1 point at `login.microsoftonline.com` (or another Entra authority). If so, **skip DCR entirely and go straight to [Manual Credential Entry](#manual-credential-entry).**

Entra does not implement RFC 7591 dynamic client registration:

- `https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration` returns valid metadata — so the "OAuth metadata found" branch is taken — but carries **no `registration_endpoint`** key at all.
- `https://login.microsoftonline.com/common/v2.0/.well-known/oauth-authorization-server` returns **404**.

This is structural, not a per-server accident: no amount of retrying, and no other endpoint, will produce a DCR registration against Entra. Do not report the missing `registration_endpoint` as a server misconfiguration, and do not ask the user to "enable DCR" — tell them a manual app registration is required and move on.

### Dynamic Client Registration (DCR)

For **non-Entra** servers, check if `registration_endpoint` is present in the well-known metadata from Step 1.

**If `registration_endpoint` is present → attempt DCR automatically:**

```bash
curl -s -X POST <registration_endpoint> \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "<display name> M365 Connector",
    "redirect_uris": ["https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect"],
    "grant_types": ["authorization_code", "refresh_token"],
    "response_types": ["code"],
    "token_endpoint_auth_method": "client_secret_basic",
    "scope": "<discovered scopes>"
  }'
```

- If the response contains `client_id` and `client_secret` → use them directly. Tell the user credentials were obtained via dynamic registration. **Do NOT ask the user for credentials.**
- If DCR returns an error or no `client_secret` → fall through to manual entry below.

### Manual Credential Entry

**If the server is Entra-protected, OR `registration_endpoint` is absent, OR DCR fails → ask the user:**

> "Please provide your OAuth client credentials for [name]:
>
> - Client ID:
> - Client Secret (leave blank if your app is a secretless PKCE public client):"

`clientId` is **always** required — `oauth/register` validates it unconditionally. `clientSecret` is optional; see PKCE below.

If the user has no app registration yet and the server is Entra-protected, they must create one before continuing. The registration must use the redirect URI `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect` exactly.

### PKCE

After obtaining credentials, ask the user:

> "Does your tenant allow client secrets for this app, or should I configure a secretless PKCE public client? (secret / PKCE)"

- If the user wants PKCE, says their tenant blocks client secrets, **or asks you to decide** → `isPKCEEnabled: true` and **omit the `clientSecret` line entirely**
- Only if the user explicitly supplies a client secret → `isPKCEEnabled: false` with `clientSecret: ${{<PREFIX>_MCP_CLIENT_SECRET}}`

**Default to PKCE.** Many corporate tenants have policies that block client-secret credentials outright, and the secretless shape is the one that works in both cases. `oauth/register` never requires `clientSecret` — it is only format-validated when it is present *and* PKCE is off — so the secretless variant is always valid.

> **Secretless PKCE means the Entra app must be registered as an SPA, not a Web app.** A Web-platform registration expects a confidential client with a secret; a secretless public client using PKCE must be registered under the **Single-page application** platform with the redirect URI above and **zero** password or key credentials. Registering the wrong platform produces a redirect/credential error at consent time, not at provision time.

### ⛔ Security Rules

- **NEVER** print, display, or reveal access tokens, bearer tokens, or client secrets in your output
- **NEVER** write secrets to any file — they are passed as OS environment variables at provision time only
- Treat `client_secret` as sensitive — store it only in `.env.*.user` files (which are gitignored)

---

## Step 3: Register in `m365agents.yml` and `m365agents.local.yml`

**⛔ CRITICAL:** You MUST add the `oauth/register` step to BOTH `m365agents.yml` AND `m365agents.local.yml`. Both files need identical `oauth/register` blocks — if you only update one, authentication will fail in that environment.

Add the `oauth/register` step to the `provision` lifecycle in both files, after `teamsApp/create` and before `teamsApp/zipAppPackage`:

```yaml
provision:
  - uses: teamsApp/create
    with:
      name: <app-name>${{APP_NAME_SUFFIX}}
    writeToEnvironmentFile:
      teamsAppId: TEAMS_APP_ID

  - uses: oauth/register
    with:
      name: <slug>-oauth
      # ⛔ REQUIRED, and it must stay even though `applicableToApps: AnyApp`
      # makes it inert. The action's YAML schema lists only `name` and `flow`
      # as required and says appId "only takes effect when applicableToApps is
      # SpecificApp", but the driver validates it unconditionally — removing
      # this line fails provision with InvalidActionInputError.
      appId: ${{TEAMS_APP_ID}}
      # ⛔ MUST be AnyApp. A Cowork plugin carries TWO app identities:
      # TEAMS_APP_ID (from teamsApp/create) and M365_APP_ID (from the publish
      # step). SpecificApp binds the vault record to TEAMS_APP_ID, but Cowork
      # resolves the connector's referenceId under M365_APP_ID, so every call
      # fails with a hard 404 the UI reports only as "Could not verify
      # connection":
      #   {"code":"NotFound","message":"Configuration '…' not found in
      #    Application '<M365_APP_ID>'","innerError":{"code":
      #    "M365AppNotFoundError"}}
      # Binding to M365_APP_ID instead does not work either: oauth/register
      # runs before the publish step, so that value is still empty on a first
      # provision. AnyApp sidesteps the ordering problem entirely.
      applicableToApps: AnyApp
      clientId: ${{<PREFIX>_MCP_CLIENT_ID}}
      clientSecret: ${{<PREFIX>_MCP_CLIENT_SECRET}}
      authorizationUrl: <authorizationUrl>
      tokenUrl: <tokenUrl>
      refreshUrl: <refreshUrl>
      scope: <comma-separated-scopes or "openid" if none provided>
      # ⚠️ If scope has no value, use `scope: ""` (quoted empty string).
      # A bare `scope:` is YAML null and will fail schema validation.
      flow: authorizationCode
      identityProvider: Custom
      isPKCEEnabled: <true or false>
      tokenExchangeMethodType: PostRequestBody
      baseUrl: <SERVER_URL>
    writeToEnvironmentFile:
      configurationId: <PREFIX>_MCP_AUTH_ID

  - uses: teamsApp/zipAppPackage
    with:
      manifestPath: ./appPackage/manifest.json
      outputZipPath: ./appPackage/build/appPackage.zip
      outputFolder: ./appPackage/build

  - uses: teamsApp/update
    with:
      appPackagePath: ./appPackage/build/appPackage.zip
```

### Secretless PKCE variant (use this when the tenant blocks client secrets)

Identical to the block above except that the `clientSecret` line is **removed entirely** and PKCE is on. Do not pass an empty `clientSecret:` — omit the key:

```yaml
  - uses: oauth/register
    with:
      name: <slug>-oauth
      appId: ${{TEAMS_APP_ID}}
      applicableToApps: AnyApp
      clientId: ${{<PREFIX>_MCP_CLIENT_ID}}
      # no clientSecret — this is a public client
      authorizationUrl: <authorizationUrl>
      tokenUrl: <tokenUrl>
      refreshUrl: <refreshUrl>
      scope: <comma-separated-scopes or "openid" if none provided>
      flow: authorizationCode
      identityProvider: Custom
      isPKCEEnabled: true
      tokenExchangeMethodType: PostRequestBody
      baseUrl: <SERVER_URL>
    writeToEnvironmentFile:
      configurationId: <PREFIX>_MCP_AUTH_ID
```

With this variant, omit `<PREFIX>_MCP_CLIENT_SECRET` from `.env.dev.user` as well — there is no secret to store.

### Naming Conventions

| Value                        | Derivation                                   | Example                      |
| ---------------------------- | -------------------------------------------- | ---------------------------- |
| `<PREFIX>`                   | Uppercase slug, hyphens/spaces → underscores | `CANVA_V1`, `HUBSPOT`        |
| `<slug>`                     | Display name lowercased, spaces → hyphens    | `canva-v1`, `hubspot`        |
| `name` in oauth/register     | `<slug>-oauth`                               | `canva-v1-oauth`             |
| `<PREFIX>_MCP_CLIENT_ID`     | Client ID env var                            | `CANVA_V1_MCP_CLIENT_ID`     |
| `<PREFIX>_MCP_CLIENT_SECRET` | Client secret env var                        | `CANVA_V1_MCP_CLIENT_SECRET` |
| `<PREFIX>_MCP_AUTH_ID`       | Auth config ID (written by provision)        | `CANVA_V1_MCP_AUTH_ID`       |

### Environment Files

**`env/.env.dev`** (committed, no secrets):

```
TEAMS_APP_ID=
<PREFIX>_MCP_AUTH_ID=
APP_NAME_SUFFIX=-dev
TEAMSFX_ENV=dev
```

**`env/.env.dev.user`** (gitignored, contains secrets):

```
<PREFIX>_MCP_CLIENT_ID=<client_id>
<PREFIX>_MCP_CLIENT_SECRET=<client_secret>
```

> **Important:** Add `<PREFIX>_MCP_AUTH_ID=` to `.env.dev` as soon as you detect the server requires OAuth — before running provision. The `oauth/register` step will populate its value during provisioning.
>
> **⛔ NEVER set a placeholder value** for `<PREFIX>_MCP_AUTH_ID` (e.g., `PLACEHOLDER`, `TODO`, `temp`). Leave it empty (`<PREFIX>_MCP_AUTH_ID=`). The `oauth/register` automation will write the real value during provisioning. If a placeholder is present, it will be treated as the actual value and will NOT be overwritten.

### Re-provisioning, rewriting, and recovering a registration

**`oauth/register` creates or skips. It never rewrites.** It decides using the `writeToEnvironmentFile` output variable, not the registration's `name`:

- **`<PREFIX>_MCP_AUTH_ID` empty** → a new configuration is created and the id is written back.
- **`<PREFIX>_MCP_AUTH_ID` populated** → the action fetches that id and **skips**. Editing anything under `with:` and re-provisioning changes nothing, silently, at exit 0.
- **`<PREFIX>_MCP_AUTH_ID` populated but the configuration no longer exists** → the fetch fails, the action logs a **warning and still does nothing**. Provision reports success against a configuration that is gone. Do not read a green provision as proof the vault record is healthy.

So if a registration was created with the wrong values — the `applicableToApps` 404 above being the common case — re-running provision will **not** fix it. Choose one:

**Option A — rewrite in place with `oauth/update`** (preferred; keeps the id, so the manifest's `reference_id` and every deployed copy stay valid):

```yaml
  - uses: oauth/update
    with:
      name: <slug>-oauth
      configurationId: ${{<PREFIX>_MCP_AUTH_ID}}
      applicableToApps: AnyApp
      appId: ${{TEAMS_APP_ID}}
      clientId: ${{<PREFIX>_MCP_CLIENT_ID}}
      authorizationUrl: <authorizationUrl>
      tokenUrl: <tokenUrl>
      refreshUrl: <refreshUrl>
      scope: <comma-separated-scopes>
      flow: authorizationCode
      identityProvider: Custom
      isPKCEEnabled: true
      tokenExchangeMethodType: PostRequestBody
      baseUrl: <SERVER_URL>
```

`oauth/update` requires `configurationId`, reads the existing record, diffs it, and PATCHes only when something actually differs. Unlike `register` it does **not** short-circuit on the env var.

**Option B — start over.** Delete the configuration in the [Teams Developer Portal](https://dev.teams.microsoft.com/), then clear the env var (`<PREFIX>_MCP_AUTH_ID=`, empty — never a placeholder) and re-provision so `oauth/register` creates a fresh one. This mints a **new** id, so anything already referencing the old `reference_id` must be re-provisioned too.

> **There is no read or delete surface in wiqd or ATK.** The Teams Developer Portal backs these records at `/api/v1.0/oAuthConfigurations`, and the toolchain wires up only create (`POST`), read-by-id (`GET`, used internally by the short-circuit above), and update (`PATCH`). There is no list-all, no delete, and no CLI command or lifecycle action that surfaces any of them. Inspecting or deleting a configuration is a Teams Developer Portal (web UI) operation.

---

## Platform constraints (read before estimating)

Two limits are **not** wiqd bugs and cannot be worked around in the manifest. Surface them to the user early — both are commonly discovered only after significant work.

### `agentConnectors` has no `microsoftEntra` auth type

The two extensibility surfaces expose different auth vocabularies:

| Surface                                                             | Available auth types                                                                                   |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `composeExtensions[].authorization.authType`                        | `none`, `apiSecretServiceAuth`, **`microsoftEntra`**, `oAuth2.0`                                        |
| `agentConnectors[].toolSource.remoteMcpServer.authorization.type`   | `None`, `OAuthPluginVault`, `ApiKeyPluginVault`, `DynamicClientRegistration`, `AzureKeyVault` (from v1.29) |

There is no `microsoftEntra` for agent connectors, and therefore **no SSO path**. Even for a first-party Microsoft API, the only OAuth-capable connector type is `OAuthPluginVault`, whose `referenceId` comes from `oauth/register` — which unconditionally requires a `clientId` the developer owns.

> **`DynamicClientRegistration` is in the enum, but that is not how DCR is enabled.** The schema conditionally requires a `referenceId` for it, while dynamic client registration exists precisely because there is no pre-registered client to reference. In Copilot Cowork the supported way to enable DCR is to **omit the `authorization` node entirely**, which is what `wiqd plugin add connector --auth-type dcr` emits. Do not hand-author `{"type": "DynamicClientRegistration"}` expecting DCR behavior. (This does not rescue Entra-protected servers — see above.)

**Consequence:** the developer must register an Entra application purely to obtain a client ID, even when both the client and the resource are Microsoft's. wiqd can wire the manifest and the vault record end to end, but it **cannot** create that app registration for them. Say so plainly rather than implying automation will handle it. (`DynamicClientRegistration` is a real connector auth type, but it is unusable against Entra — see [Entra does not support DCR](#entra-does-not-support-dcr).)

### Provision does not verify that the scope can be consented to

A successful provision says nothing about whether anyone in the tenant can actually grant the delegated scope the connector requests. When they cannot, the failure appears much later — at a **"Need admin approval"** page on first use, potentially days afterwards — with nothing linking it back to provisioning.

This is sharpest when the resource app is homed in a different tenant from the client, which is the norm for first-party Microsoft APIs: the resource app object is not visible to the developer *or* to their tenant admin (`az ad app show` returns 404; only the service principal is visible), so **neither can pre-authorize the client**. Admin consent is the only lever.

Before declaring an Entra-protected connector done, tell the user to confirm:

1. Whether the delegated scope requires admin consent (scope `type` — `User` vs `Admin`).
2. Whether the tenant's user-consent policy permits consenting to it at all.
3. Whether a grant already exists for the client/resource pair.

---

## Step 4: Plugin Manifest Auth Block

In the plugin manifest's `runtimes[]` entry, reference the registered OAuth configuration:

### Authenticated (OAuthPluginVault)

```json
{
  "type": "RemoteMCPServer",
  "auth": {
    "type": "OAuthPluginVault",
    "reference_id": "${{<PREFIX>_MCP_AUTH_ID}}"
  },
  "spec": {
    "url": "<SERVER_URL>",
    "mcp_tool_description": {
      "tools": [ ... ]
    }
  },
  "run_for_functions": [ ... ]
}
```

### Unauthenticated (None)

```json
{
  "type": "RemoteMCPServer",
  "auth": {
    "type": "None"
  },
  "spec": {
    "url": "<SERVER_URL>",
    "mcp_tool_description": {
      "tools": [ ... ]
    }
  },
  "run_for_functions": [ ... ]
}
```

---

## Decision Tree

Use this decision tree to determine the authentication flow:

```
MCP server URL provided
│
├── Probe /.well-known/oauth-authorization-server
│   AND /.well-known/openid-configuration
│
├── OAuth metadata found?
│   ├── NO → Use "auth": {"type": "None"} — skip Steps 1-3
│   └── YES → Step 1 (map endpoints)
│       │
│       ├── Is the authority Entra (login.microsoftonline.com)?
│       │   ├── YES → SKIP DCR (Entra has no registration_endpoint).
│       │   │         User must hand-register an Entra app → Manual Credential Entry
│       │   │         → warn: no microsoftEntra connector auth type; admin consent may be required
│       │   └── NO  → Step 2 (try DCR, fall back to manual creds)
│       │
│       └── Step 3 (oauth/register — ALWAYS applicableToApps: AnyApp) → Step 4 (OAuthPluginVault)
│
└── For API plugins: same flow applies — add oauth/register to m365agents.yml if OAuth is needed
```

> Already registered once with the wrong values? Re-running provision will **not** fix it — see [Re-provisioning, rewriting, and recovering a registration](#re-provisioning-rewriting-and-recovering-a-registration).

---

## Common Issues

| Issue                                                  | Solution                                                                                                                                                                                                            |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Connector shows "Could not verify connection"; network tab shows a 404 with `M365AppNotFoundError` | The vault record is bound to the Teams app id. Set `applicableToApps: AnyApp`, then **delete the old record and clear the env var** — `oauth/register` never rewrites, so re-provisioning alone changes nothing. See [recovery](#re-provisioning-rewriting-and-recovering-a-registration). |
| `registration_endpoint` returns 404                    | DCR not supported — ask user for credentials manually. If the authority is Entra this is expected and permanent; see [Entra does not support DCR](#entra-does-not-support-dcr).                                     |
| Provision exits 0 but nothing changed                  | `oauth/register` skips whenever `<PREFIX>_MCP_AUTH_ID` is already populated. Use `oauth/update`, or clear the env var and delete the old configuration in the Teams Developer Portal.                                |
| `InvalidActionInputError: appId`                       | `appId` is validated unconditionally even under `applicableToApps: AnyApp`, where it is inert. Restore `appId: ${{TEAMS_APP_ID}}`.                                                                                  |
| `InvalidActionInputError: clientId`                    | `clientId` is always required. There is no connector auth type that avoids it — see [Platform constraints](#platform-constraints-read-before-estimating).                                                           |
| Tenant policy blocks client secrets                    | Use the [secretless PKCE variant](#secretless-pkce-variant-use-this-when-the-tenant-blocks-client-secrets): `isPKCEEnabled: true`, omit `clientSecret`, register the Entra app as an **SPA** (not Web).             |
| "Need admin approval" on first use                     | The delegated scope needs consent nobody in the tenant can grant. Provision does not check this — see [Provision does not verify that the scope can be consented to](#provision-does-not-verify-that-the-scope-can-be-consented-to). |
| Token refresh fails                                    | Verify `refreshUrl` matches `token_endpoint` from well-known metadata                                                                                                                                              |
| `<PREFIX>_MCP_AUTH_ID` empty after provision           | Check that `oauth/register` step is in `m365agents.yml` and credentials are correct                                                                                                                                |
| "Invalid redirect URI" during OAuth                    | Ensure redirect URI is exactly `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect`                                                                                                                        |
| PKCE errors                                            | Some providers don't support PKCE — set `isPKCEEnabled: false` and supply a `clientSecret`                                                                                                                          |
