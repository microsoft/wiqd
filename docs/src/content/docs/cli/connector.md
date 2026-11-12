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
wiqd connector add --input-file <private-json> [--dry-run] [--json]

# Add a connector you found to a plugin
wiqd plugin add connector --selector <selector> [--folder <plugin>]
```

Sign in first with `wiqd auth login`. The commands use the same Microsoft 365 identity as the rest
of the plugin lifecycle. Discovery reads the catalog directly and does not change tenant state.

## Create a connector from an MCP server

`connector add` wraps an HTTPS MCP URL in a Swagger definition and calls
`POST https://agent365.svc.cloud.microsoft/agents/connectors/add`. It works outside
a plugin project and always targets production; alternate environments are not
supported. It does not change
`connector list` or `connector show`, which still query the titles catalog.

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

Supply one OAuth scope without whitespace. For Entra, prefer a resource-qualified
scope such as `api://<resource-app-id>/access_as_user` or
`https://api.contoso.com/read`: WIQD separates the resource URI from the scope
name. A resource URI without a scope suffix is not a resource-qualified scope.
Legacy relative scopes retain the supplied value as the resource setting.

Keep OAuth input files private and out of source control. Secrets are not accepted
as command-line flags or included in output. Valid input submits immediately
without a confirmation prompt; use `--dry-run` to validate without creating.
`--mock` returns an explicitly labeled fixture
without reading the input file or creating anything.

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
The API's host never changes the fixed production management endpoint or token audience.

### Production authentication

The management endpoint and token audience are fixed. There are no
`--environment`, `--resource-app-id`, `--local-url`, or `--yes` options.
This does not determine whether your connector's backend uses live or sandbox
credentials; backend authentication is configured separately.

**Platform login is separate from connector authentication.** Even a `NoAuth`
MCP server or REST API requires an authenticated caller to create its connector. This command
reuses the core WIQD Microsoft 365 client
`7ea7c24c-b1f6-4a20-9d11-9ae12e9e7ac0`, not a new app or the catalog token.
It silently requests delegated `AgentTools.PublishMCPServer.All` on the
production resource application `ea9ffc3e-8a23-4a7d-836d-234d7c7565c1`.
Run `wiqd auth login --interactive`
first. Your tenant must consent to that permission for this client; the command
does not grant permissions, fall back to another app, or accept app-only tokens.
The signed-in tenant is used; this command does not switch tenants or reuse the
prototype's separately registered login application.

Success reports the connector's logical ID, display name,
and API correlation ID. The service's internal environment ID is not displayed.
When the service returns an OAuth `redirectUri`, JSON and human-readable output
include it unchanged for registration in your OAuth application. Missing or null
redirect URIs are omitted; wiqd does not open the URL.
Creation confirmation requires only the connector ID and display name, not an
environment ID or an exact response schema. Unknown response fields are ignored;
malformed responses, unsafe redirect URIs, and credential echoes still fail.
Human-readable output remains the default; add `--json` for the standard JSON envelope.
JSON reports the input path once as `inputFile`, plus mode, endpoint,
authentication type, result identifiers, and publication caveat.
It does not echo environment fields, option aliases, execution flags, or the working directory.
**Creation does not establish catalog publication,
a connection, MCP tool readiness, or plugin composition.** Publication depends on
service policy. The service selects an MCC or Cowork environment according to its
deployment policy. The logical ID is distinct from a catalog title/element ID; use
the separate explicit OpenAPI preview authoring flow when referencing it in a plugin.

Creation is not automatically retried. Sign-in has a 15-second deadline (exit 2)
and the API request to 120 seconds (exit 1 with `CONNECTOR_ADD_OUTCOME_UNKNOWN`);
after the API deadline wiqd waits up to 5 more seconds for transport to stop.
Silent sign-in must finish settling before wiqd returns after its deadline or
cancellation, because the authentication provider shares state.
After a request deadline, malformed response, or server error following
submission, the connector may already exist; the error includes a 32-digit
hexadecimal correlation ID. Pressing Ctrl+C exits 130 without this warning.
Use the correlation ID to inspect service logs/existing resources before retrying;
absence from `connector list` does not prove creation failed because that command
queries published titles rather than all created connectors.

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
