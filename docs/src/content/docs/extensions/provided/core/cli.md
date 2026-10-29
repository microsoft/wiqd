---
title: wiqd Core · CLI commands
description: Commands contributed by the native wiqd Core extension
---

# wiqd Core · CLI commands

The commands below are backed by the in-process fx-core adapter contributed by `microsoft.wiqd.core`.

## Plugin authoring and lifecycle

Start with the plugin, then compose the components it needs. The command tree is
alpha and enabled by default.

| Command | What it does |
| --- | --- |
| [`wiqd plugin create`](/cli/reference/#wiqd-plugin-create) | Scaffold the plugin app package. |
| [`wiqd plugin add agent`](/cli/reference/#wiqd-plugin-add-agent) | Compose a declarative-agent component. |
| [`wiqd plugin add skill`](/cli/reference/#wiqd-plugin-add-skill) | Compose a root plugin skill. |
| [`wiqd plugin add connector`](/cli/reference/#wiqd-plugin-add-connector) | Compose a connector or reuse one from the catalog. |
| [`wiqd plugin show`](/cli/reference/#wiqd-plugin-show), [`list`](/cli/reference/#wiqd-plugin-list) | Inspect a plugin or discover local projects. |
| [`wiqd plugin provision`](/cli/reference/#wiqd-plugin-provision) | Register the plugin and write its environment before packaging or sharing. |
| [`wiqd plugin package`](/cli/reference/#wiqd-plugin-package) | Build the distributable ZIP. |
| [`wiqd plugin publish`](/cli/reference/#wiqd-plugin-publish) | Submit to the tenant catalog for administrator approval. |
| [`wiqd plugin share`](/cli/reference/#wiqd-plugin-share) | Grant direct access to users or the tenant. |
| [`wiqd plugin import`](/cli/reference/#wiqd-plugin-import), [`export`](/cli/reference/#wiqd-plugin-export) | Convert supported plugin formats, subject to format limitations. |
| [`wiqd plugin delete`](/cli/reference/#wiqd-plugin-delete) | Remove provisioned cloud resources. |

[`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) is contributed by
the Validate extension. Static mode checks the declarative-agent surface; deep
mode delegates to Core to validate an already-built app package.

## Agent-component authoring

Existing `wiqd agent` projects remain supported. Use these commands for their
agent-specific workflow, not as a prerequisite for every plugin.

| Command | What it does |
| --- | --- |
| [`wiqd agent create`](/cli/reference/#wiqd-agent-create) | Scaffold a new declarative agent project. |
| [`wiqd agent create list`](/cli/reference/#wiqd-agent-create-list) | List available declarative-agent templates. |
| [`wiqd agent show`](/cli/reference/#wiqd-agent-show) | Show a local summary of the agent project. |
| [`wiqd agent add action`](/cli/reference/#wiqd-agent-add-action) | Add an OpenAPI or remote MCP action. |
| [`wiqd agent add skill`](/cli/reference/#wiqd-agent-add-skill) | Add a skill to the agent. |
| [`wiqd agent add auth`](/cli/reference/#wiqd-agent-add-auth) | Add an auth configuration to a plugin manifest. |

## Existing agent-project lifecycle

| Command | What it does |
| --- | --- |
| [`wiqd agent provision`](/cli/reference/#wiqd-agent-provision) | Provision the agent into an environment. |
| [`wiqd agent package`](/cli/reference/#wiqd-agent-package) | Build the deployable `.zip`. |
| [`wiqd agent publish`](/cli/reference/#wiqd-agent-publish) | Publish to the org catalog. |
| [`wiqd agent delete`](/cli/reference/#wiqd-agent-delete) (alias `uninstall`) | Delete cloud resources by env or title ID. |
| [`wiqd agent env`](/cli/reference/#wiqd-agent-env) | List, add, and reset environments. |
| `wiqd agent validate --mode deep` | Delegate deep validation to the core runtime. |

## Collaboration

| Command | What it does |
| --- | --- |
| [`wiqd agent share`](/cli/reference/#wiqd-agent-share) | Share with users or the tenant. |
| [`wiqd agent share collaborator`](/cli/reference/#wiqd-agent-share-collaborator) | Manage agent collaborators. |
