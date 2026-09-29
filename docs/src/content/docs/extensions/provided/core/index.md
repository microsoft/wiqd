---
title: wiqd Core
description: Native fx-core declarative-agent lifecycle backend
---

# wiqd Core

**Extension ID:** `microsoft.wiqd.core` · **Package:** `@microsoft/wiqd-ext-core` · **Runtime:** in-process `@microsoft/teamsfx-core`

## What it does

The wiqd Core extension owns the declarative-agent and standalone-plugin lifecycle: scaffold, add actions/skills/auth, validate deeply, provision, package, share, publish, inspect, and delete. It is the only default lifecycle provider. The retired ATK subprocess extension is removed during upgrade and cannot be selected with a flag or environment variable.

## Workflow walkthrough

```bash
wiqd agent create --name MyAgent
cd MyAgent
wiqd agent validate
wiqd agent provision --env local
wiqd agent package
wiqd agent share --scope users --email dev@example.com
```

## Where to look in the codebase

- `packages/wiqd-ext-core/wiqd-extension.json` — manifest declaring commands, auth, doctor, flags, workflows, and references.
- `packages/wiqd-ext-core/references/` — guidance loaded by the wiqd orchestrator.
- `packages/wiqd-ext-core/workflows/` — agent/plugin lifecycle workflows.
- [Host vs. extensions](../../../concepts/host-vs-extensions.md) — how the host delegates lifecycle behavior to extensions.

## Go deeper

- [CLI commands](/extensions/provided/core/cli/) — lifecycle commands contributed by this extension.
- [Agentic workflows](/extensions/provided/core/workflows/) — workflow and reference inventory.
- [Agent plugins](/extensions/provided/core/skills/) — natural-language scenarios routed to this extension.
