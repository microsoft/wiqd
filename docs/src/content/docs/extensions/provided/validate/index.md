---
title: Validate
description: Source diagnostics, final-package and Marketplace validation, and the VS Code LSP server
---

# Validate

**Extension ID:** `microsoft.validate` · **Package:** `@microsoft/wiqd-ext-validate`

## What it does

Validate checks **saved source**, **final packages**, and **Marketplace readiness**.
Marketplace includes package and policy checks on the same captured ZIP. The extension
also provides **Language Server Protocol (LSP)** editor diagnostics.

Source reuses the editor's diagnostics service for the saved DA file registered in
`appPackage/manifest.json` (commonly `appPackage/declarativeAgent.json`),
without network, authentication, ZIPs or reports. Package is the default mode and may require
sign-in; source must be selected explicitly. Validation never builds or publishes automatically.

## Workflow walkthrough

```bash
# 1. Offline saved-source checks
wiqd plugin validate --mode source --path . --env local

# 2. Validate an existing final package
wiqd plugin validate --mode package --package-file ./final.zip

# 3. CI gate: machine-readable output
wiqd plugin validate --mode source --path . --env local --json

# 4. Editor integration — install the VS Code extension
wiqd component vscode install

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
- [Copilot skills](/extensions/provided/validate/skills/) — validation and authorized repair.
- [VS Code extension concept](/concepts/vscode-extension/) — the editor-side surface this extension powers.
