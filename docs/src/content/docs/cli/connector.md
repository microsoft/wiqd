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
sign-in, not a plugin project. The `connector` commands are read-only; adding a connector is a
plugin step, like every other `plugin add` capability:

```bash
wiqd connector list [--search <text>] [--auth-type <type>] [--top <n>]
wiqd connector show <selector>

# Add a connector you found to a plugin
wiqd plugin add connector --selector <selector> [--folder <plugin>]
```

Sign in first with `wiqd auth login`. The commands use the same Microsoft 365 identity as the rest
of the plugin lifecycle and read the catalog directly; they never create connections, register
credentials, or change tenant state.

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
- update the `wiqd.plugin.json` capability list;
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
- **Agent projects.** `--selector` targets plugin projects (folders with `wiqd.plugin.json`) only.

## JSON output

Every command supports `--json`. The envelope `command` is `connector.list` or `connector.show`;
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
| `0`   | Discovery, inspection, or composition succeeded                                  |
| `1`   | Invalid input, unknown or ambiguous selector, catalog failure, or local conflict |
| `2`   | Not a plugin project, or not signed in to Microsoft 365                          |
| `130` | Cancelled                                                                        |

## Related commands

- [`wiqd plugin add connector`](/cli/reference/#wiqd-plugin-add-connector) — add a catalog
  connector with `--selector`, or author a remote MCP or OpenAPI connector manually.
- [`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) — validate the plugin after adding
  a connector.
- [Plugin authoring reference](/getting-started/plugin-reference/#discover-and-compose-catalog-connectors)
  — connector identities, types, and connections.
- [Command reference](/cli/reference/#wiqd-connector) — every flag for every `wiqd connector`
  command.
