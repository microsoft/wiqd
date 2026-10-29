---
title: wiqd Core
description: Plugin composition and lifecycle, with declarative-agent components, powered by the native fx-core backend.
---

# wiqd Core

**Extension ID:** `microsoft.wiqd.core` · **Package:** `@microsoft/wiqd-ext-core` · **Runtime:** in-process `@microsoft/teamsfx-core`

## What it does

The wiqd Core extension powers the **plugin lifecycle**: scaffold a plugin,
compose skills, connectors, and optional declarative agents, then provision,
package, share, publish, inspect, and delete. It also owns agent-component
authoring and the supported `wiqd agent` project workflow. It is the only
default lifecycle provider. The retired ATK subprocess extension is removed
during upgrade and cannot be selected with a flag or environment variable.

## Workflow walkthrough

```bash
wiqd plugin create --name my-plugin
cd my-plugin
wiqd plugin add skill --name "Triage Issues"
wiqd plugin add agent
wiqd plugin validate --env dev
wiqd plugin provision --env dev
wiqd plugin package --env dev
wiqd plugin validate --mode deep --env dev
wiqd plugin share --scope users --email dev@example.com --env dev
```

Static validation checks the declarative-agent surface, not the entire plugin.
Deep validation checks the built package. For publishing and tenant
administrator approval, follow [Build a Plugin](/getting-started/build-a-plugin/).

## Where to look in the codebase

- `packages/wiqd-ext-core/wiqd-extension.json` — manifest declaring commands, auth, doctor, flags, workflows, and references.
- `packages/wiqd-ext-core/references/` — guidance loaded by the wiqd orchestrator.
- `packages/wiqd-ext-core/workflows/` — agent/plugin lifecycle workflows.
- [Host vs. extensions](../../../concepts/host-vs-extensions.md) — how the host delegates lifecycle behavior to extensions.

## Go deeper

- [CLI commands](/extensions/provided/core/cli/) — lifecycle commands contributed by this extension.
- [Agentic workflows](/extensions/provided/core/workflows/) — workflow and reference inventory.
- [Agent plugins](/extensions/provided/core/skills/) — natural-language scenarios routed to this extension.
