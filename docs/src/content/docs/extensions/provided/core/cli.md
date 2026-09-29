---
title: wiqd Core · CLI commands
description: Commands contributed by the native wiqd Core extension
---

# wiqd Core · CLI commands

The commands below are backed by the in-process fx-core adapter contributed by `microsoft.wiqd.core`.

## Authoring

| Command | What it does |
| --- | --- |
| [`wiqd agent create`](/cli/reference/#wiqd-agent-create) | Scaffold a new declarative agent project. |
| [`wiqd agent create list`](/cli/reference/#wiqd-agent-create-list) | List available declarative-agent templates. |
| [`wiqd agent show`](/cli/reference/#wiqd-agent-show) | Show a local summary of the agent project. |
| [`wiqd agent add action`](/cli/reference/#wiqd-agent-add-action) | Add an OpenAPI or remote MCP action. |
| [`wiqd agent add skill`](/cli/reference/#wiqd-agent-add-skill) | Add a skill to the agent. |
| [`wiqd agent add auth`](/cli/reference/#wiqd-agent-add-auth) | Add an auth configuration to a plugin manifest. |

## Lifecycle

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
