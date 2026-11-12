---
title: VS Code extension
description: Real-time manifest validation, diagnostics, and language features in your editor
---

# VS Code extension

The Work IQ Dev Tools VS Code extension brings the diagnostics engine used by
`wiqd plugin validate --mode source` into your editor. As you type, schema problems show up as
squigglies, hovers explain the violated rule, and quick fixes appear where supported. The editor
can check unsaved buffers; the source command checks saved files. Package/Marketplace validation
uses captured ZIP bytes and has a different scope.

This page explains what the extension does and where it fits. For installation steps, see [Installation](/getting-started/installation/).

## What you get

- **Live diagnostics on every keystroke.** Open a `declarativeAgent.json` or `manifest.json` and the extension lights up the file with errors, warnings, and informational diagnostics from the Microsoft Validation Layer (MVL) — the same engine the M365 platform uses to accept a manifest.
- **Hovers and quick fixes.** Hover an underline to read the full diagnostic. When the validator knows a safe fix (for example, normalising a casing inconsistency), VS Code offers it as a code action.
- **Schema-aware completion.** Manifest fields, enums, and capability shapes auto-complete because the schema is bundled with the extension.
- **Shared source diagnostics, distinct scopes.** `wiqd plugin validate --mode source` reuses the
  editor's diagnostics service on saved files. Unsaved buffers and editing-only advisory checks
  can differ; package/Marketplace checks evaluate captured ZIPs, not the editor buffer.

## When to use it

- **Always**, if you edit manifests by hand. The roundtrip from "I typed something" to "I see whether it's valid" drops from seconds to milliseconds.
- **During scaffolding**, to catch malformed capability blocks the moment you paste them in.
- **During reviews**, to load a teammate's branch and immediately see whether the manifest is well-formed.

The extension is not a substitute for `wiqd plugin validate --mode source` in offline CI.
Build and explicitly validate the final ZIP when package acceptance is required. The editor
experience is for the inner loop, not proof of deployment/publication approval.

## Installation

Run `wiqd component vscode install` from a terminal where `wiqd` is on your PATH.
Use `wiqd component vscode install --insiders` for VS Code Insiders. These install
the VS Code extension, not the coding-assistant marketplace plugin.
See [Installation](/getting-started/installation/) for the other setup paths.

Once installed, open a project that contains a declarative-agent manifest.
Diagnostics start automatically; no separate validation command is needed.

## Go deeper

- [Validation & MVL](/concepts/validation-mvl/) — what the validator checks and why
- [Validate extension](/extensions/provided/validate/) — the bundled extension that ships the validator and LSP server
- [Installation](/getting-started/installation/) — install or update the VS Code extension
