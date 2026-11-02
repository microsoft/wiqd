---
title: Validate · CLI commands
description: Every command contributed by Work IQ Dev Tools' Validate extension
---

# Validate · CLI commands

The Validate extension contributes validation, listing helpers and the hidden editor protocol entry:

| Command | What it does |
|---------|--------------|
| [`wiqd agent validate`](/cli/agent/agent-validate/) | Source, package (default), or Marketplace including package checks. |
| `wiqd agent validate add-market-listing` / `get-market-listing` / `preview-market-listing` | Save/read listing data and generate the whole-listing HTML review; no validation or publication. |
| `wiqd agent lsp` | Language Server Protocol server for editor integration (hidden from `--help`). |
| `wiqd plugin validate` | Standalone-plugin `static`/`deep` checks. |

`--mode source` runs offline one-shot diagnostics on saved source through the shared diagnostics
service. It does not start LSP, require a ZIP/sign-in, or write reports. Package uploads captured
ZIP bytes to TDP through Core; Marketplace includes TDP and StoreOps checks on those same bytes.
No validation mode builds automatically. See the [command guide](/cli/agent/agent-validate/) for inputs,
same-mode repair and upgrade notes.

## Plugin validation JSON

Static mode (default) checks a plugin's declarative-agent surface; a plugin without
that surface passes vacuously. Read `data.diagnostics` on success or
`error.data.diagnostics` on a completed failure. Each item has `message` and `severity`;
mock results are marked `simulated`. Older unwrapped JSON consumers must use these
envelope paths and lowercase keys. Deep mode uses Core package validation.

## Editor protocol entry

`wiqd agent lsp` is invoked automatically by the [VS Code extension](/concepts/vscode-extension/).
It speaks LSP 3.17 over JSON-RPC stdio and is hidden from default help. Stdout belongs
to the protocol; diagnostics use stderr.

Do not use global `--json` with LSP: it fails before spawn with
`EXTENSION_PROTOCOL_FORMAT_UNSUPPORTED` and exit 2. Rerun without `--json` so protocol bytes remain
unmodified. Normal LSP shutdown exits 0; cancellation exits 130. Use `--mode source` for a
finite offline CI check rather than launching a long-lived editor server.
