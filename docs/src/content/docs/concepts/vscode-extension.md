---
title: VS Code extension
description: Real-time manifest validation, diagnostics, and language features in your editor
---

# VS Code extension

The Work IQ Dev Tools VS Code extension brings the same validation engine that powers `wiqd agent validate` directly into your editor. As you type, schema problems show up as squigglies, hovers explain the rule that was violated, and quick fixes appear where the validator can suggest one. You don't have to save the file, switch to a terminal, or re-run a command — feedback is immediate.

This page explains what the extension does and where it fits. For installation steps, see [Installation](/getting-started/installation/).

## What you get

- **Live diagnostics on every keystroke.** Open a `declarativeAgent.json` or `manifest.json` and the extension lights up the file with errors, warnings, and informational diagnostics from the Microsoft Validation Layer (MVL) — the same engine the M365 platform uses to accept a manifest.
- **Hovers and quick fixes.** Hover an underline to read the full diagnostic. When the validator knows a safe fix (for example, normalising a casing inconsistency), VS Code offers it as a code action.
- **Schema-aware completion.** Manifest fields, enums, and capability shapes auto-complete because the schema is bundled with the extension.
- **A consistent story across local CLI and editor.** Whatever you see in VS Code is exactly what `wiqd agent validate` will say at the terminal and what CI will say on the next push. No "works in my editor" surprises.

## How it works

The extension is a thin client. The real work happens in the `wiqd agent lsp` Language Server, which the extension launches automatically when you open a workspace that contains a declarative-agent manifest. The server speaks the standard Language Server Protocol, watches the open files, runs MVL on every change, and streams diagnostics back to VS Code.

Because the server is just the Work IQ Dev Tools CLI in a different mode, it shares everything else with the terminal: the same validation engine, the same exit-code semantics, and the same diagnostic catalogue. Upgrading Work IQ Dev Tools upgrades the editor experience too.

## When to use it

- **Always**, if you edit manifests by hand. The roundtrip from "I typed something" to "I see whether it's valid" drops from seconds to milliseconds.
- **During scaffolding**, to catch malformed capability blocks the moment you paste them in.
- **During reviews**, to load a teammate's branch and immediately see whether the manifest is well-formed.

The extension is not a substitute for `wiqd agent validate` in CI — CI still runs the CLI to gate merges. The editor experience is for the inner loop.

## Installation

The fastest path is `wiqd install --vscode` from any terminal where `wiqd` is on your PATH. That command resolves the latest version, downloads the VSIX, and installs it into VS Code and VS Code Insiders if you have them. See [Installation](/getting-started/installation/) for the full set of options, including manual install and Insiders-only mode.

Once installed, open any project that contains a declarative-agent manifest and the LSP server starts on its own. There is no command to run and no settings to configure.

## Go deeper

- [`wiqd agent lsp`](/extensions/provided/validate/cli/) — the language server the extension launches
- [Validation & MVL](/concepts/validation-mvl/) — what the validator checks and why
- [Validate extension](/extensions/provided/validate/) — the bundled extension that ships the validator and LSP server
- [Installation](/getting-started/installation/) — install or update the VS Code extension
- Source on GitHub — the extension package and LSP client
