---
title: ATK · CLI commands
description: Every command contributed by Work IQ Dev Tools' Agents Toolkit extension
---

# ATK · CLI commands

Every command below lives under `wiqd agent`. They are all backed by the upstream `atk` CLI, invoked non-interactively, with Work IQ Dev Tools validating filesystem postconditions and shaping the output.

## Authoring

| Command | What it does |
|---------|--------------|
| [`wiqd agent show`](/cli/reference/#wiqd-agent-show) | Show a local summary of the agent project. |
| [`wiqd agent create`](/cli/reference/#wiqd-agent-create) | Scaffold a new declarative agent project. |
| [`wiqd agent create list`](/cli/reference/#wiqd-agent-create-list) | List available declarative-agent templates. |
| [`wiqd agent add action`](/cli/reference/#wiqd-agent-add-action) | Add an OpenAPI-spec action. |
| [`wiqd agent add skill`](/cli/reference/#wiqd-agent-add-skill) | Add a skill to the agent. |
| [`wiqd agent add auth`](/cli/reference/#wiqd-agent-add-auth) | Add an auth configuration to a plugin manifest. |

## Lifecycle

| Command | What it does |
|---------|--------------|
| [`wiqd agent provision`](/cli/reference/#wiqd-agent-provision) | Provision the agent into an environment. |
| [`wiqd agent package`](/cli/reference/#wiqd-agent-package) | Build the deployable `.zip`. |
| [`wiqd agent publish`](/cli/reference/#wiqd-agent-publish) | Publish to the org catalog. |
| [`wiqd agent delete`](/cli/reference/#wiqd-agent-delete) (alias `uninstall`) | Delete cloud resources — by env (project-based) or by `--title-id` with no local project required. |
| [`wiqd agent env`](/cli/reference/#wiqd-agent-env) | List, add, and reset environments. |

## Collaboration

| Command | What it does |
|---------|--------------|
| [`wiqd agent share`](/cli/reference/#wiqd-agent-share) | Share with users or the tenant. |
| [`wiqd agent collaborator`](/cli/reference/#wiqd-agent-share-collaborator) | Manage agent collaborators. |

## Validation hand-off

| Command | What it does |
|---------|--------------|
| `wiqd agent validate --mode deep` | Deep semantic validation, combined with the [Validate extension](/extensions/provided/validate/). |

`wiqd agent validate` (static mode) and `wiqd agent lsp` are owned by the [Validate extension](/extensions/provided/validate/), not this one. They feel like the same surface to users.
