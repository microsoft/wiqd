---
title: wiqd Core · Agent plugins
description: Natural-language scenarios powered by the wiqd Core extension
---

# wiqd Core · Agent plugins

With WIQD's coding-assistant plugin loaded, describe the Microsoft 365 plugin
you want to build. It guides you through composition and delivery. Declarative agents are
optional components, alongside skills and connectors.

## Scenarios unlocked

- **Scaffold and compose** — create a plugin, then add skills, connectors, and an optional declarative agent.
- **Edit** — modify instructions, capabilities, actions, plugins, auth, and localization.
- **Source prechecks** — use explicit offline source checks during edit/package/provision flows.
  Explicit validation and finding-bound repair route to the [Validate workflow](/extensions/provided/validate/skills/).
- **Plugin validation** — route explicit source, final-package and Marketplace checks to the Validate workflow; package checks require an existing ZIP.
- **Provision** — register the plugin in an environment.
- **Package** — build the deployable `.zip`.
- **Share / collaborate** — grant user, tenant, or collaborator access.
- **Publish** — submit the plugin to the tenant catalog for administrator approval.
- **Delete / show / environments** — inspect, manage, and tear down resources.

## Trigger phrases

> create a standalone plugin · add a skill to my plugin · add a connector to my plugin · add an agent to my plugin · validate my plugin · provision my plugin · package my plugin · share my plugin · publish my plugin

Existing agent-focused workflows also remain available:

> create agent · new agent · scaffold agent · edit my agent · update my agent · add a capability · add a plugin · provision my agent · deploy my agent · package my agent · share my agent · delete my agent · show my agent · manage environments · localize my agent

Explicit agent validation and finding repair route to the canonical Validate workflow.

Improve the plugin through validation, repairs, and testing in its target
experience. When it includes a deployed declarative agent,
[Eval](/extensions/provided/eval/skills/) can evaluate that component. Agent
evaluation is not whole-plugin validation, and observation features depend on
the installed extensions and access.
