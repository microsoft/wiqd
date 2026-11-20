---
title: wiqd connector
description: Discover connectors published in the Microsoft 365 catalog, then add one to a plugin without hand-copying its endpoint or credential reference.
---

# `wiqd connector`

Microsoft 365 catalog titles publish ready-made agent connectors — for example the Azure DevOps
remote MCP server, complete with its managed-connection reference. `wiqd connector` finds and
inspects those connectors, and `wiqd plugin add connector --selector` adds one to a plugin exactly
as published, so you never have to look up or retype an MCP URL or vault reference.

Connectors are a top-level command because catalog discovery needs only your Microsoft 365
sign-in, not a plugin project. `list` and `show` are read-only. `connector add`
creates a server-side connector; adding a reference to a plugin remains a separate
plugin step:

```bash
wiqd connector list [--search <text>] [--auth-type <type>] [--top <n>]
wiqd connector show <selector>
wiqd connector add --input-file <private-json> [--prepare-for-certification] [--dry-run] [--json]

# Add a connector you found to a plugin
wiqd plugin add connector --selector <selector> [--folder <plugin>]
```

Sign in first with `wiqd auth login`. The commands use the same Microsoft 365 identity as the rest
of the plugin lifecycle. Discovery reads the catalog directly and does not change tenant state.

## Create a connector from an MCP server

**Preview, off by default.** Enable connector creation before running any
`connector add` command, including dry-run, mock, and certification preparation:

```powershell
wiqd config flags set connector-add true
wiqd config flags show connector-add
```

To return to the default-off state, run `wiqd config flags reset connector-add`.
The `WIQD_FLAG_CONNECTOR_ADD` environment variable overrides the saved setting:
`true` enables creation and `false` disables it. Clear that variable when returning
to persisted/default behavior. See [Feature flags](/cli/reference/#feature-flags)
for the full precedence and flag inventory.

When disabled, `connector add` is unavailable and omitted from CLI help and
completion. `connector list`, `connector show`, and `plugin add connector`
(manual or catalog-based composition) remain available. Enabling the preview
does not grant service permissions or bypass tenant consent.

`connector add` wraps an HTTPS MCP URL in a Swagger definition and calls
`POST https://agent365.svc.cloud.microsoft/agents/connectors/add`. It works outside
a plugin project and targets production by default; the closed pre-release
environment selection below supports test and preprod. It does not change
`connector list` or `connector show`, which still query the titles catalog.

Ordinary and certification creation requests send
`Accept: application/json` with `Content-Type: application/json`.
These headers apply to the management POST only, not downstream MCP calls.

Save this as `learn-mcp-server.json`:

```json
{
  "serverUrl": "https://learn.microsoft.com/api/mcp",
  "displayName": "Microsoft Learn MCP",
  "authentication": { "type": "NoAuth" }
}
```

```powershell
# Validate offline without reading credentials or calling any service
wiqd connector add --input-file .\learn-mcp-server.json --dry-run --json

# Create once on the production service
wiqd connector add --input-file .\learn-mcp-server.json --json
```

No Swagger or `operation` block is required for MCP input: the command generates
the POST operation, operation ID, summary, description, 200 response, and
`mcp-streamable-1.0` protocol marker automatically.
The input accepts optional `description` and `operation` metadata. The full MCP
path is preserved (`/api/mcp` above). Operation metadata can override summary,
description, operation ID, tags, model name/description, produces, and responses,
but cannot change the HTTP method, endpoint, or authentication. Unknown fields,
invalid URLs, mixed auth settings, and files over 1 MiB fail before sign-in.

| Connector authentication | Required fields in `authentication` |
| --- | --- |
| `NoAuth` | `type` only |
| `APIKey` | `type`, `apiKeyName`, `apiKeyLocation` (`header` or `query`); not the key itself |
| `EntraOAuth` | `type`, `clientAppId` (GUID), `clientAppSecret`, `scope` |
| `ExternalOAuth` | OAuth fields above plus HTTPS `externalIdpAuthorizationUrl` and `externalIdpTokenUrl`; optional HTTPS `externalIdpRefreshUrl` when the provider refreshes tokens at a different endpoint |

Keep using the `authentication` object in your private input file. WIQD translates
it into Swagger security and, for OAuth, `oauthRegistration`; it does **not**
send the obsolete top-level `authentication` field to MCP Platform.
`NoAuth` generates empty security requirements; `APIKey` declares the header or
query scheme; OAuth declares an authorization-code flow, endpoints, and scope.
Entra uses the public-cloud `common/oauth2/authorize` and `common/oauth2/token`
endpoints; External OAuth keeps your supplied endpoints, including an optional
refresh URL.

External OAuth accepts space-separated scopes such as `openid offline_access`.
Entra accepts one scope without whitespace; prefer a resource-qualified
scope such as `api://<resource-app-id>/access_as_user` or
`https://api.contoso.com/read`: WIQD separates the resource URI from the scope
name. A resource URI without a scope suffix is not a resource-qualified scope.
Legacy relative scopes retain the supplied value as the resource setting.

Keep OAuth input files private and out of source control. Secrets are not accepted
as command-line flags or included in output. Valid input submits immediately
without a confirmation prompt; use `--dry-run` to validate without creating.
`--mock` returns an explicitly labeled fixture
without reading the input file or creating anything.

### Per-connection parameters

An MCP server that runs in several regions or environments can declare
`parameters`. Each end user then picks their values in the connection-creation
dialog, so one connector serves every region. Reference a parameter with a
`{name}` token in the host of `serverUrl` and, for `ExternalOAuth`, in the host
of the OAuth URLs:

```json
{
  "displayName": "Cognite Data Fusion MCP",
  "serverUrl": "https://{host}/mcp",
  "parameters": {
    "authHost": {
      "type": "string",
      "displayName": "Cognite environment",
      "required": true,
      "defaultValue": "auth.cognite.com",
      "allowedValues": [
        { "value": "auth.cognite.com", "displayName": "Production" },
        { "value": "auth-staging.gc-bru-001.cogheim.net", "displayName": "Staging" }
      ]
    },
    "host": {
      "type": "string",
      "displayName": "Cognite cluster",
      "required": true,
      "defaultValue": "api.cognitedata.com",
      "allowedValues": [{ "value": "api.cognitedata.com", "displayName": "Production: europe-west1-1" }]
    }
  },
  "hostAllowlist": ["*.cognitedata.com"],
  "authentication": {
    "type": "ExternalOAuth",
    "clientAppId": "00000000-0000-0000-0000-000000000000",
    "clientAppSecret": "<secret>",
    "scope": "openid offline_access",
    "externalIdpAuthorizationUrl": "https://{authHost}/oauth2/authorize",
    "externalIdpTokenUrl": "https://{authHost}/oauth2/token"
  }
}
```

| Parameter field | Meaning |
| --- | --- |
| `type` | `string`, or `securestring` for a secret value (not allowed in a URL) |
| `displayName`, `description` | Label and help text in the connection dialog |
| `required` | Whether a value must be chosen; defaults to `false` |
| `defaultValue` | Preselected value; must be one of `allowedValues` when both are set |
| `allowedValues` | Dropdown choices as `{ "value", "displayName" }` entries |

Rules, checked before sign-in:

- At most 10 parameters, named with a letter followed by up to 63 letters, digits
  or underscores, unique ignoring case. Parameters cannot be named `token`
  (any case, including NoAuth); API-key parameters cannot be named `api_key`, the generated credential
  scheme. Securestring parameters cannot have defaults or dropdown choices.
  OAuth also reserves its grant placeholders such as `ClientId`, `ClientSecret`,
  `State`, `Scopes`, `Code`, `CodeChallenge` and `CodeVerifier`.
- Tokens are allowed only in the hostname, never the port, path or query,
  and must name a declared required `string` parameter. A fixed numeric port is allowed.
  Host choices/defaults must not contain a port.
- If a `serverUrl` parameter has no `allowedValues`, add `hostAllowlist` with
  host names or `*.suffix` patterns to bound the hosts users may choose.
  Explicit lists have at most 50 entries and must cover all finite derived hosts
  when there are at most 50 combinations. Larger combinations require an explicit
  list. Wildcard suffixes need at least two labels.
- A parameter in an OAuth URL must be `required` with `allowedValues`, and each
  OAuth URL may expand to at most 50 hosts.
- `parameters` work only with `serverUrl`. Fixed server hosts omit `hostUrlTemplate`;
  `hostAllowlist` requires a dynamic server-host token.

The connector is created with the default values (or the parameter name when
there is no default) substituted into its host and OAuth URLs, together with the
templates and parameter definitions. Authentication is still encoded in Swagger
security and `oauthRegistration`, not a top-level service `authentication` field.
When OAuth URLs are templated, registration keeps its provider/client/resource
fields and adds authorization, token and refresh templates; no concrete
`refreshUrl` is sent. Input without `parameters` retains the unparameterized
request contract. External OAuth accepts space-separated scopes, such as
`openid offline_access`, and writes each as a distinct Swagger scope.
Entra OAuth still requires a single resource-relative or resource-qualified scope.
Parameter names stay logical in the management request; MCP Platform owns native
OAuth namespacing and policy expressions. For **all** Entra/External OAuth inputs,
the backend stores custom parameters as `token:<logicalName>`, even with fixed
OAuth URLs or unused declarations. NoAuth/APIKey keep plain names; generated
OAuth/API-key credential fields are unchanged. This applies to newly created
connectors, not migration of existing connectors. The allowlist remains an array in this
input, not the native policy's JSON-array string.

**Backend prerequisite:** Per-connection fields require dynamic-host support in
MCP Platform. OAuth URL templates additionally require matching registration
fields and runtime support; dynamic-host support alone is insufficient.
An offline dry-run validates WIQD input only, not backend acceptance or deployment.
The CLI checks bounded hosts, credential-name collisions and securestring
restrictions before authentication; the service remains authoritative for
native lowering and policy execution. No-auth connection setup
must also collect required host values rather than submit an empty parameter map.

### Create a connector from a REST/OpenAPI definition

Use the **same `--input-file` option**, replacing `serverUrl` with an
`apiDefinition` object. The command selects the mode from field presence, not
from URL or operation names. Supplying both fields, neither field, or `operation`
alongside `apiDefinition` is an error.

The embedded document follows **Swagger 2.0 (OpenAPI 2.0)**; the outer
`displayName`, `description`, and `authentication` are connector metadata.
OpenAPI 3.x, YAML, bare API documents, and JSON-encoded definition strings are
not supported. Export a Swagger 2.0 JSON definition and embed it as an object;
the command does not silently convert versions.

Save this as `inventory-api.json`, replacing the illustrative host with your API:

```json
{
  "displayName": "Contoso Inventory",
  "description": "Retrieve inventory items by ID.",
  "authentication": {
    "type": "APIKey",
    "apiKeyLocation": "header",
    "apiKeyName": "X-API-Key"
  },
  "apiDefinition": {
    "swagger": "2.0",
    "info": {
      "title": "Contoso Inventory API",
      "version": "1.0.0"
    },
    "host": "api.contoso.com",
    "basePath": "/v1",
    "schemes": ["https"],
    "produces": ["application/json"],
    "paths": {
      "/items/{itemId}": {
        "get": {
          "operationId": "GetInventoryItem",
          "parameters": [
            {
              "name": "itemId",
              "in": "path",
              "required": true,
              "type": "string"
            }
          ],
          "responses": {
            "200": {
              "description": "The requested inventory item.",
              "schema": { "$ref": "#/definitions/InventoryItem" }
            }
          }
        }
      }
    },
    "definitions": {
      "InventoryItem": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "quantity": { "type": "integer", "format": "int32" }
        }
      }
    }
  }
}
```

```powershell
wiqd connector add --input-file .\inventory-api.json --dry-run --json
```

`apiKeyName` names a header, not an actual API key. The same authentication modes
above apply to both input forms. WIQD translates the outer `authentication`
object into the service's Swagger-based authentication contract. Your explicit
settings replace document security definitions and root requirements, and
operation-level security overrides are removed so every operation inherits the
selected mode. This also prevents an anonymous operation override from weakening
your selected authentication.

The CLI checks the definition version, nonempty host/paths, safe HTTPS backend,
and optional basePath/schemes/tags structure. It preserves methods, schemas,
references, and vendor extensions without adding MCP metadata or fetching any
references. Full Swagger/operation acceptance remains with MCP Platform/CMS:
a successful dry-run does not prove that the service will accept the definition.
The API's host never changes the management endpoint or token audience.

### Production authentication

The production management endpoint and token audience are the default. There are no
`--environment`, `--resource-app-id`, `--local-url`, or `--yes` options.
This does not determine whether your connector's backend uses live or sandbox
credentials; backend authentication is configured separately.

For developer validation, set `WIQD_MCP_PLATFORM_ENV` to target a
non-production or local MCP Platform deployment. Values are case-insensitive; unset or
empty means `prod`, and any other value fails before reading input or signing in.

| Value     | Endpoint origin                                    | Token resource application             |
| --------- | -------------------------------------------------- | -------------------------------------- |
| `prod`    | `https://agent365.svc.cloud.microsoft`             | `ea9ffc3e-8a23-4a7d-836d-234d7c7565c1` |
| `test`    | `https://test.agent365.svc.cloud.dev.microsoft`    | `05879165-0320-489e-b644-f72b33f3edf0` |
| `preprod` | `https://preprod.agent365.svc.cloud.dev.microsoft` | `05879165-0320-489e-b644-f72b33f3edf0` |
| `local`   | `http://localhost:52857`                          | `05879165-0320-489e-b644-f72b33f3edf0` |

PreProd uses the Test application because its own registration is not live.
Your tenant must consent to `AgentTools.PublishMCPServer.All` on the selected
application for the WIQD client. The `endpoint` output shows which deployment
was called; `--mock` output is unaffected.

`local` uses the same Test/PreProd resource and delegated WIQD identity for both
ordinary creation and certification preparation. Start your trusted local MCP
Platform service separately on port **52857** before using it. This is a fixed
loopback HTTP exception, not an arbitrary URL/port override or an authentication
bypass. Redirects are refused, and HTTPS requirements for other management
targets, MCP/REST backends and OAuth URLs remain unchanged. Local creation is
**not a simulation**: your service can still create tenant resources.

```powershell
$env:WIQD_MCP_PLATFORM_ENV = 'test'
wiqd connector add --input-file .\connector.json --prepare-for-certification
Remove-Item Env:WIQD_MCP_PLATFORM_ENV
```

For the local developer service, use `$env:WIQD_MCP_PLATFORM_ENV = 'local'`
instead. Run `--dry-run` first to confirm the localhost endpoint without
authentication or submission, then omit it only when creation is intended.
Remove the variable afterward to restore the default production target.

**Platform login is separate from connector authentication.** Even a `NoAuth`
MCP server or REST API requires an authenticated caller to create its connector. This command
reuses the core WIQD Microsoft 365 client
`7ea7c24c-b1f6-4a20-9d11-9ae12e9e7ac0`, not a new app or the catalog token.
It silently requests delegated `AgentTools.PublishMCPServer.All` on the selected
resource application (production defaults to `ea9ffc3e-8a23-4a7d-836d-234d7c7565c1`).
Run `wiqd auth login --interactive`
first. Your tenant must consent to that permission for this client; the command
does not grant permissions, fall back to another app, or accept app-only tokens.
The signed-in tenant is used; this command does not switch tenants or reuse the
prototype's separately registered login application.

Success reports the connector's logical ID, display name,
and API correlation ID. The service's internal environment ID is not displayed.
When the service returns OAuth redirect URLs, JSON and human-readable output
include its URLs unchanged for registration in your OAuth application. JSON uses
one field, `redirectUris`, always as an array. The service's legacy `redirectUri`
string becomes a one-item array. Both ordinary and certification creation accept
arrays in `redirectUri` or `redirectUris`; legacy values appear first, followed
by plural values. Ordinary creation preserves the order and duplicates.
Certification additionally collects `creationResults[].redirectUri`, then
deduplicates callbacks in first-seen order. There is no scalar `redirectUri`
output field.
Human-readable output lists every URL under **Redirect URIs** for multiple URLs,
or **Redirect URI** for one. Missing/null values and empty arrays are omitted.
Add every listed URI to your OAuth app registration before users sign in.
Only absolute HTTPS values without credentials, whitespace, control characters,
or fragments are accepted. Ordinary values are limited to 8192 characters;
certification values to 2048 characters. One invalid URL rejects the response
rather than returning a partial list. WIQD never constructs, opens, or fetches
callbacks. Certification packaging variants do not create additional callbacks.
Creation confirmation requires only the connector ID and display name, not an
environment ID or an exact response schema. Unknown response fields are ignored;
malformed responses, unsafe redirect URIs, and credential echoes still fail.
Human-readable output remains the default; add `--json` for the standard JSON envelope.
JSON reports the input path once as `inputFile`, plus mode, endpoint,
authentication type, result identifiers, and publication caveat.
It does not echo environment fields, option aliases, execution flags, or the working directory.
**Creation does not establish catalog publication,
a connection, MCP tool readiness, or plugin composition.** Publication depends on
service policy. The service selects creation targets according to its
deployment policy; a single environment ID is not required in the response.
The logical ID is distinct from a catalog title/element ID. To reference it in a
plugin, preserve the source type used for creation:

| Creation input | Plugin connector kind | Manifest node |
| --- | --- | --- |
| `serverUrl` (MCP server) | `--kind remote-mcp` | `toolSource.remoteMcpServer` |
| `apiDefinition` (REST/Swagger API) | `--kind openapi` | `toolSource.openApiConnector` |

The service's internal Swagger wrapper does not turn an MCP server into an
OpenAPI plugin connector. The returned `shared_...` ID and authentication type
do not identify the connector kind. If the original input or request already
identifies it, no additional format choice is needed; if only a reference is
known, establish its type and, for MCP, the endpoint before composing it.

For the Learn MCP example, first create a plugin and save the server's
`tools/list` result (the object containing `tools`) as
`appPackage/learn-mcp-tools.json`. Then use the original endpoint and the exact
returned ID:

```powershell
wiqd plugin add connector --kind remote-mcp --name "Microsoft Learn MCP" --description "Search official Microsoft documentation" --url "https://learn.microsoft.com/api/mcp" --tool-description learn-mcp-tools.json --auth-reference-id "<returned-connectorId>" --dev-preview --folder .\learn-plugin
```

Omitting `--auth-type` with a reference selects `ConnectionVault`, which requires
the explicit `devPreview` manifest opt-in shown above. The tool-description file
must already exist under `appPackage/`; Cowork requires it even when the manifest
schema marks it optional. Adding the reference does not create another connector.

Connector `displayName` is limited to **40 characters**, checked before sign-in
or submission in both input modes and certification preparation. This CMS limit
does not reduce parameter-label limits (256 characters).

Creation is not automatically retried. Sign-in has a 15-second deadline (exit 2)
and the API request to 120 seconds (exit 1 with `CONNECTOR_ADD_OUTCOME_UNKNOWN`);
after the API deadline wiqd waits up to 5 more seconds for transport to stop.
Silent sign-in must finish settling before wiqd returns after its deadline or
cancellation, because the authentication provider shares state.
After a request deadline, malformed response, or server error following
submission, the connector may already exist; the error includes a 32-digit
hexadecimal correlation ID. Valid, sanitized structured service/CMS codes and
messages appear in JSON `error.code`/`error.message` and human diagnostics,
including new codes and updated backend wording. Messages are credential-redacted
and bounded; the CLI does not maintain a display vocabulary of known errors.
For a verified pre-creation code/status receipt in a pure error response
(400/401/403/404/409), correct the reported
input/access/deployment issue; the uncertain-creation warning is omitted.
Unknown codes, human wording and generic validation reasons do not establish
definite rejection. HTTP 408/429/5xx, timeouts, partial certification outcomes and
malformed/unsafe error bodies still report uncertainty, even when safe service
details are shown. Raw bodies, credentials, HTML, stack traces and nested
exceptions are never displayed. Pressing Ctrl+C exits 130 without this warning.
Use the correlation ID to inspect service logs/existing resources before retrying;
absence from `connector list` does not prove creation failed because that command
queries published titles rather than all created connectors.

### Prepare a connector for certification

Use `--prepare-for-certification` (alias `--prepareForCertification`) on both
creation and packaging when preparing certification artifacts:

```powershell
wiqd connector add --input-file .\inventory-api.json --prepare-for-certification --dry-run --json
wiqd connector add --input-file .\inventory-api.json --prepare-for-certification --json
```

The same input file is validated and translated into a nested
`{ "connector": { ... } }` creation request, submitted once to
`POST https://agent365.svc.cloud.microsoft/agents/connectors/certification`.
Do not wrap your input file in `connector`; WIQD supplies the API envelope.
Do not supply `connectionVaultId`: the service derives the credential-storage
key from the creation response, removing only its trailing `-<tenantId>` suffix.
MCP Platform owns tenant service-connector creation and Marketplace staging of
static OAuth client credentials. NoAuth/APIKey have no static OAuth credentials
to stage. WIQD never calls CMS or Marketplace directly.
This requires deployment of the connector-creation certification API and its
tenant-scoped CMS service API. A credentials-only HTTP 204 or partial HTTP 207
is not successful creation. Deployment failures do not fall back to ordinary add.

Copy the returned **`connectorId` exactly**: `shared_<apiId>-<tenantId>`, with
a terminal nonzero, 36-character tenant GUID and at most 128 characters total.
Only the final `-<GUID>` is the tenant suffix, so `shared_ronak-test-<tenantId>`
has primary reference `shared_ronak-test`; hyphens and underscores in API IDs are
preserved. Live creation checks that suffix against the validated token's `tid`,
case-insensitively, without exposing token claims. A mismatch rejects the response
as unconfirmed creation; inspect the existing connector before retrying.
Do not construct the ID from the display name. Success additionally reports
`prepareForCertification: true` and `validationConnectorId` (the same complete ID,
not an ID ending in `_validation`). This does not create a connection, compose a plugin, or certify,
approve, or publish anything.

Compose the complete returned ID into a plugin separately, after opting into the
preview shape, **preserving the original MCP or REST source type**. For the
Inventory REST API example:

```powershell
wiqd plugin add connector --kind openapi --name "Inventory" --description "Inventory API" --auth-reference-id "<returned-connectorId>" --dev-preview --folder .\inventory-plugin
wiqd plugin package --path .\inventory-plugin --offline --prepare-for-certification --output .\dist\inventory.zip --json
```

For an MCP server, use the `--kind remote-mcp` command above with its original
URL, tool-description file, and complete certification `connectorId` instead.
Certification preparation changes packaging references, not connector kind.

Use normal provisioned packaging without `--offline` when needed. Packaging
produces `inventory.zip` with `shared_<apiId>` references and
`inventory.validation.zip` with the exact returned `shared_<apiId>-<tenantId>`
references. Only the primary ZIP removes the tenant suffix; neither appends
`_validation`. Both paths must be new. See
[certification packaging](/cli/plugin-package/#certification-packages).
Offline packaging checks the canonical shape without authentication or network;
it cannot establish which tenant is currently signed in.
Offline dry-run reports the selected endpoint without staging credentials;
mock creation stays explicitly simulated and reads no input file.

## Find a connector

```bash
wiqd connector list --search "Azure DevOps"
```

```text
Selector          Title                Connector         Kind             Authorization    Reference            Connector ID
Azure DevOps MCP  Azure DevOps Plugin  Azure DevOps MCP  remoteMcpServer  ConnectionVault  shared_adomcpserver  5947d764-f2cc-48b8-8634-743e3fb7d438
```

| Option        | Description                                                                 |
| ------------- | --------------------------------------------------------------------------- |
| `--search`    | Case-insensitive match on title, connector, description, ID, or reference   |
| `--auth-type` | Exact authorization type, such as `ConnectionVault` or `OAuthPluginVault`   |
| `--top`       | Return at most this many connectors (positive integer)                      |

Copy the **Selector** value into `show` or `plugin add connector --selector`. It is
usually the connector's display name. When two materially different connectors share a name, the
selector becomes an opaque `<title-id>::<connector-id>` value instead; copy it as-is. You never
need a separate title ID.

## Inspect a connector

```bash
wiqd connector show "Azure DevOps MCP"
```

`show` prints the title, IDs, kind, authorization, and the exact `agentConnectors` node that would
be added to your plugin, including its `toolSource`. For a remote MCP connector it ends with the
command that adds it:

```text
  Next steps:
    1. wiqd plugin add connector --selector "Azure DevOps MCP" — Add this connector to a plugin
```

`show` leaves this step out when the selector contains a character that a shell could act on in
the pasted command: `"`, a typographic double quote (`“`, `”`, `„`), `$`, `` ` ``, `\`, `!`, `%`,
`&`, `|`, `<`, `>`, `^`, or a line break. `list` and `show` still print the selector, so you can
quote it for your shell yourself.

## Add a connector to a plugin

Run this from a plugin project, or point `--folder` at one:

```bash
wiqd plugin add connector --selector "Azure DevOps MCP"
```

```text
Catalog connector "Azure DevOps MCP" is now in the plugin
Details

  Id         5947d764-f2cc-48b8-8634-743e3fb7d438
  Kind       remoteMcpServer
  Auth       ConnectionVault (shared_adomcpserver)
  Manifest   appPackage/manifest.json
```

The command:

- append the catalog's exact `agentConnectors` node to `appPackage/manifest.json`, preserving its
  authorization block;
- expose the connector capability automatically from that root manifest collection;
- move the app manifest to the `devPreview` schema, because catalog connectors follow the catalog's
  connector shape rather than wiqd's numbered manual-authoring subset.

Re-running with the same selector is a no-op that reports **already present**. A different
connector that reuses the same ID fails with `DUPLICATE_CONNECTOR` and leaves the manifest
unchanged.

`--selector` replaces the manual options: combining it with `--name`, `--description`, `--kind`,
`--url`, `--tool-description`, `--auth-type`, `--auth-reference-id`, or `--dev-preview` fails with
`INCOMPATIBLE_CONNECTOR_OPTION` before anything is written. Without `--selector`,
`wiqd plugin add connector` authors a connector from the manual options as before.

### What catalog composition does not do

- **OpenAPI connectors.** `list` and `show` include `openApiConnector` results, but adding one by
  selector fails with `CONNECTOR_CATALOG_PREVIEW_CONFIRMATION_REQUIRED`. After confirming you want
  the preview shape, use its **Reference** value with
  `wiqd plugin add connector --kind openapi --dev-preview`; see
  [Existing OpenAPI custom connectors](/getting-started/plugin-reference/#existing-openapi-custom-connectors).
- **Inline tool lists.** A catalog node that embeds its MCP tool list fails with
  `UNSUPPORTED_CATALOG_CONNECTOR_TOOL_DESCRIPTION`. Save the server's `tools/list` output under
  `appPackage/` and author the connector with `wiqd plugin add connector --tool-description <file>`.
- **Project scope.** `--selector` targets structurally recognized plugin projects with contained
  `m365agents.yml` and `appPackage/manifest.json`.

## JSON output

Every command supports `--json`. The envelope `command` is `connector.list`, `connector.show`, or `connector-add`;
`wiqd plugin add connector --selector` reports `plugin.add.connector`:

```json
{
  "status": "success",
  "command": "plugin.add.connector",
  "data": {
    "id": "5947d764-f2cc-48b8-8634-743e3fb7d438",
    "displayName": "Azure DevOps MCP",
    "kind": "remoteMcpServer",
    "authType": "ConnectionVault",
    "titleId": "P_8d7e60b7-3dfa-21d8-162d-b91232776ed8",
    "connectorId": "5947d764-f2cc-48b8-8634-743e3fb7d438",
    "referenceId": "shared_adomcpserver",
    "manifestVersion": "devPreview",
    "added": true,
    "alreadyPresent": false,
    "warnings": []
  }
}
```

## Exit codes

| Code  | Meaning                                                                          |
| ----- | -------------------------------------------------------------------------------- |
| `0`   | Discovery, inspection, composition, or connector creation succeeded                                    |
| `1`   | Invalid input, unknown or ambiguous selector, catalog or connector API failure, or local conflict      |
| `2`   | Not a plugin project, not signed in to Microsoft 365, or missing MCP Platform permission               |
| `130` | Cancelled                                                                                              |

## Related commands

- [`wiqd plugin add connector`](/cli/reference/#wiqd-plugin-add-connector) — add a catalog
  connector with `--selector`, or author a remote MCP or OpenAPI connector manually.
- [`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) — validate the plugin after adding
  a connector.
- [Plugin authoring reference](/getting-started/plugin-reference/#discover-and-compose-catalog-connectors)
  — connector identities, types, and connections.
- [Command reference](/cli/reference/#wiqd-connector) — every flag for every `wiqd connector`
  command.
