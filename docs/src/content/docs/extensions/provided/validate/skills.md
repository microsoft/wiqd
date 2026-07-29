---
title: Validate · Agent plugins
description: Why the Validate extension has no dedicated Copilot skill scenario
---

# Validate · Agent plugins

The Validate extension does **not** expose its own Copilot skill scenario. It is a **substrate** — a tool that other workflows use — not a user-facing intent on its own.

When you ask Copilot to "validate my agent" or "fix my agent manifest", the wiqd orchestrator routes those phrases into the **ATK workflow** (see [ATK · Copilot skills](/extensions/provided/atk/skills/)), which calls `wiqd agent validate` as part of its larger flow. The diagnostics come from this extension, but the user-facing routing is owned by ATK.

The editor-side surface — live diagnostics in VS Code — is described in the [VS Code extension concept](/concepts/vscode-extension/). It is also not a Copilot Chat skill — it runs inside your editor automatically.

## Trigger phrases

The phrases below are caught by the [ATK skill](/extensions/provided/atk/skills/), which then invokes `wiqd agent validate` on your behalf:

> validate my agent · fix my agent manifest

There is no Validate-specific routing entry in the orchestrator.
