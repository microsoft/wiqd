---
title: Validate
description: Offline MVL static validation and the VS Code LSP server
---

# Validate

**Extension ID:** `microsoft.validate` · **Package:** `@microsoft/wiqd-ext-validate` · **Upstream:** bundled `wiqd-validate` .NET binary

## What it does

The Validate extension provides the fastest feedback loop in Work IQ Dev Tools: **offline static validation** of declarative agent manifests against the current shipping schema. It also hosts the **Language Server Protocol (LSP)** server that powers the VS Code live-diagnostics experience.

Static validation runs the **Microsoft Validation Layer (MVL)** engine — the same one the M365 platform uses to accept a manifest. No network, no auth, sub-second on a normal project. Deep validation hands off to the [Agents Toolkit](/extensions/provided/atk/) for ATK's semantic checks.

This is the only extension that ships a .NET binary. The MVL engine depends on `Microsoft.DeclarativeAgents.Manifest.dll`, a platform-owned .NET assembly with no TypeScript port. Everything else in the Work IQ Dev Tools ecosystem is TypeScript/Node.

## Workflow walkthrough

```bash
# 1. Fast static validation — run before every commit
wiqd agent validate

# 2. Deep validation including ATK semantic checks
wiqd agent validate --mode deep

# 3. CI gate: machine-readable output
wiqd agent validate --json | jq '.data.diagnostics'

# 4. Editor integration — install the VS Code extension
wiqd install --vscode

# 5. The LSP server starts automatically when you open a project with the VS Code extension
#    No command to run manually, but if you want to debug it:
wiqd agent lsp --verbose
```

In VS Code, you'll see MVL diagnostics inline as you type — squigglies on schema violations, hovers with details, and quick fixes where MVL can suggest them.

## Where to look in the codebase

- `packages/wiqd-ext-validate/wiqd-extension.json` — manifest.
- `packages/wiqd-ext-validate/src/WorkIQ.Dev.Validation/` — MVL invocation.
- `packages/wiqd-ext-validate/src/WorkIQ.Dev.LSP/` — LSP server.
- `packages/wiqd-vscode/` — VS Code extension that hosts the LSP client.

## Go deeper

- [CLI commands](/extensions/provided/validate/cli/) — every `wiqd ...` command this extension contributes.
- [Agentic workflows](/extensions/provided/validate/workflows/) — how Validate plugs into other extensions' workflows.
- [Copilot skills](/extensions/provided/validate/skills/) — why Validate has no dedicated skill scenario.
- [VS Code extension concept](/concepts/vscode-extension/) — the editor-side surface this extension powers.
