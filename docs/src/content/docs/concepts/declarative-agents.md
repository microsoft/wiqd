---
title: Declarative agents
description: Declarative agents are optional conversational components of the Microsoft 365 Copilot plugins you build with WIQD.
---

# Declarative agents

A **declarative agent** is a Microsoft 365 Copilot agent you build by *describing* what it should do — its name, instructions, knowledge sources, actions, and conversation starters — rather than by writing code. Copilot itself provides the language model, the orchestrator, and the runtime. You provide the configuration.

In WIQD, the **[plugin](/concepts/plugins/) is the app package you build and
ship**. A declarative agent is one component you can compose into that package,
alongside skills and connectors. It adds a conversational experience; it is
not required for skill-only or connector-only plugins.

For a new project, start with `wiqd plugin create`, then use
`wiqd plugin add agent` when you need this component. Existing `wiqd agent`
projects and commands remain supported; they represent the agent-focused
app-package workflow, not a requirement to start every plugin with an agent.

That configuration lives in a small set of JSON files inside an "app package":

- `appPackage/manifest.json` — the M365 app shell (id, version, icons, permissions, where the agent shows up).
- `appPackage/declarativeAgent.json` — the agent itself (name, description, instructions, capabilities, actions, conversation starters).
- `appPackage/instructions.txt` — the natural-language system prompt.
- Optional API plugin manifests for actions that call REST APIs you own.

## Why a CLI for this?

Editing JSON by hand works, but you quickly hit friction:

- The manifest schema is large and changes over time.
- Provisioning, packaging, and publishing involve several different services (Teams Toolkit, the M365 catalog, your tenant).
- Validation runs against the *current* shipping schema, not last week's.
- You want the same workflow on your laptop, in CI, and inside VS Code.

Work IQ Dev Tools guide the whole plugin lifecycle — compose, validate,
provision, package, share, and submit to your tenant catalog — through natural
language or the CLI. Agent-specific commands let you evaluate a deployed
declarative-agent component; they do not evaluate all plugin capabilities.

## What Work IQ Dev Tools don't change

Work IQ Dev Tools do **not** replace Copilot or the M365 platform. Under the hood they use the bundled wiqd Core lifecycle backend for scaffold/provision/package/share/publish/delete, and the Work IQ service for monitoring. You can still drop down to platform tools directly when you need to — Work IQ Dev Tools make the common path fast and consistent.

## Go deeper

- [Build a Plugin](/getting-started/build-a-plugin/) — the end-to-end plugin lifecycle
- [Agent component lifecycle](/concepts/agent-lifecycle/) — the agent-specific flow and existing projects
- [Host vs extensions](/concepts/host-vs-extensions/) — how Work IQ Dev Tools route each command
- [`wiqd plugin add agent`](/cli/reference/#wiqd-plugin-add-agent) — compose an agent into your plugin
- [`wiqd agent create`](/cli/reference/#wiqd-agent-create) — the supported agent-focused project workflow
- [`wiqd agent show`](/cli/reference/#wiqd-agent-show) — see what's in a project
- [wiqd Core extension](/extensions/provided/core/) — the upstream tool that owns the manifest format
