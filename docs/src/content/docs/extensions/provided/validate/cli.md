---
title: Validate · CLI commands
description: Every command contributed by Work IQ Dev Tools' Validate extension
---

# Validate · CLI commands

The Validate extension contributes two commands, both under `wiqd agent`:

| Command | What it does |
|---------|--------------|
| [`wiqd agent validate`](/cli/reference/#wiqd-agent-validate) | Static (default) or deep (delegates to ATK) manifest validation. |
| `wiqd agent lsp` | Language Server Protocol server for editor integration (hidden from `--help`). |

`wiqd agent validate --mode deep` hands off to the [ATK extension](/extensions/provided/atk/) for semantic checks. `wiqd agent lsp` is invoked automatically by the [VS Code extension](/concepts/vscode-extension/) — you almost never run it by hand.
