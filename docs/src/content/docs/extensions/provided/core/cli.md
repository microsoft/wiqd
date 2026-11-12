---
title: wiqd Core · CLI commands
description: Commands contributed by the native wiqd Core extension
---

# wiqd Core · CLI commands

Use these commands to author and deliver Microsoft 365 plugins.

## Plugin authoring and lifecycle

Start with the plugin, then compose the components it needs. The command tree is
alpha and enabled by default.

| Command | What it does |
| --- | --- |
| [`wiqd plugin create`](/cli/reference/#wiqd-plugin-create) | Scaffold the plugin app package. |
| [`wiqd plugin add agent`](/cli/reference/#wiqd-plugin-add-agent) | Compose a declarative-agent component. |
| [`wiqd plugin add skill`](/cli/reference/#wiqd-plugin-add-skill) | Compose a root plugin skill. |
| [`wiqd plugin add connector`](/cli/reference/#wiqd-plugin-add-connector) | Compose a connector or reuse one from the catalog. |
| [`wiqd plugin list templates`](/cli/reference/#wiqd-plugin-list-templates) | List templates accepted by `plugin add agent`. |
| [`wiqd plugin show`](/cli/reference/#wiqd-plugin-show), [`list`](/cli/reference/#wiqd-plugin-list) | Inspect a plugin or discover local projects. |
| [`wiqd plugin list environments`](/cli/reference/#wiqd-plugin-list-environments) | List deployment environments; sibling add/reset commands manage them. |
| [`wiqd plugin provision`](/cli/reference/#wiqd-plugin-provision) | Register the plugin and write its environment before packaging or sharing. |
| [`wiqd plugin provision package`](/cli/reference/#wiqd-plugin-provision-package) | Prepare or personally sideload an exact ZIP without a source project. |
| [`wiqd plugin package`](/cli/reference/#wiqd-plugin-package) | Build the distributable ZIP. |
| [`wiqd plugin publish`](/cli/reference/#wiqd-plugin-publish) | Submit to the tenant catalog for administrator approval. |
| [`wiqd plugin share`](/cli/reference/#wiqd-plugin-share) | Grant direct usage access to users or the tenant. |
| [`wiqd plugin remove access`](/cli/reference/#wiqd-plugin-remove-access) | Revoke usage or existing shared-access grants with partial-effect reporting. |
| [`wiqd plugin add collaborator`](/cli/reference/#wiqd-plugin-add-collaborator) / [`list collaborators`](/cli/reference/#wiqd-plugin-list-collaborators) | Add or list M365 title co-owners without changing usage sharing. |
| [`wiqd plugin import`](/cli/reference/#wiqd-plugin-import), [`export`](/cli/reference/#wiqd-plugin-export) | Convert supported plugin formats, subject to format limitations. |
| [`wiqd plugin delete`](/cli/reference/#wiqd-plugin-delete) | Remove provisioned cloud resources. |

[`wiqd plugin validate`](/cli/plugin-validate/) is contributed by the Validate
extension. Explicit source mode checks saved declarative-agent source offline.
Package (default) uploads an existing ZIP to Teams Developer Portal; Marketplace adds
StoreOps checks on the same ZIP. Validation never builds automatically.

## Agent-component authoring

Use these retained `wiqd agent` commands only for the embedded agent component.
Project identity and lifecycle stay under `wiqd plugin`.

| Command | What it does |
| --- | --- |
| [`wiqd agent add action`](/cli/reference/#wiqd-agent-add-action) | Add an OpenAPI or remote MCP action. |
| [`wiqd agent add skill`](/cli/reference/#wiqd-agent-add-skill) | Add a skill to the agent. |
| [`wiqd agent add auth`](/cli/reference/#wiqd-agent-add-auth) | Add an auth configuration to a plugin manifest. |
