---
title: Declarative agents
description: What declarative agents are and why Work IQ Dev Tools are built around them
---

# Declarative agents

A **declarative agent** is a Microsoft 365 Copilot agent you build by *describing* what it should do — its name, instructions, knowledge sources, actions, and conversation starters — rather than by writing code. Copilot itself provides the language model, the orchestrator, and the runtime. You provide the configuration.

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

Work IQ Dev Tools give you one command surface for the entire lifecycle — scaffold, edit, validate, package, provision, publish, monitor, share, evaluate — so you can move from idea to deployed agent without learning four different tools.

## What Work IQ Dev Tools don't change

Work IQ Dev Tools do **not** replace Copilot, ATK, or the M365 platform. Under the hood they shell out to the right tool for each step: the Agents Toolkit for provisioning, the Work IQ service for monitoring, and so on. You can always drop down to those tools directly if you need to — Work IQ Dev Tools just make the common path fast and consistent.

## Go deeper

- [Agent lifecycle](/concepts/agent-lifecycle/) — the end-to-end flow `wiqd` automates
- [Host vs extensions](/concepts/host-vs-extensions/) — how Work IQ Dev Tools route each command
- [`wiqd agent create`](/cli/reference/#wiqd-agent-create) — scaffold your first agent
- [`wiqd agent show`](/cli/reference/#wiqd-agent-show) — see what's in a project
- [Agents Toolkit extension](/extensions/provided/atk/) — the upstream tool that owns the manifest format
