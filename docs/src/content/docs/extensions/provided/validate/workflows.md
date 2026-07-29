---
title: Validate · Agentic workflows
description: How the Validate extension plugs into other workflows
---

# Validate · Agentic workflows

The Validate extension does **not** ship a standalone agentic workflow or reference files. Validation is a tool that other workflows invoke at the right step — for example, the [ATK workflow](/extensions/provided/atk/workflows/) runs `wiqd agent validate` before provisioning, and the wiqd Copilot orchestrator runs static validation any time the user edits a manifest.

What Validate does ship is the **MVL engine itself** — the same engine the M365 platform uses to accept a manifest — and the **LSP server** that powers live diagnostics in VS Code. Both surfaces are described on the [overview page](/extensions/provided/validate/) and the [VS Code extension concept](/concepts/vscode-extension/).

## Workflow

| File | Scenarios |
|------|-----------|
| _none_ | The Validate extension contributes no workflow file. It is invoked **inside** the ATK workflow at the `validate my agent` step, and inside any orchestrator turn that edits a manifest. |

## Reference files

| File | Topic |
|------|-------|
| _none_ | The Validate extension contributes no reference files. The relevant references — schema, deep-validation behaviour — live in the ATK extension's [reference set](/extensions/provided/atk/workflows/#reference-files). |
