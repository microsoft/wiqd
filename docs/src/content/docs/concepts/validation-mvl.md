---
title: Validation & MVL
description: Static and deep validation of declarative agent manifests
---

# Validation & MVL

Validation is the single fastest feedback loop in Work IQ Dev Tools. You run it before every commit, before every provision, and in CI on every PR. It tells you whether your manifest is well-formed against the *current* shipping declarative-agent schema — and it does it in well under a second.

## Two modes

```bash
wiqd agent validate              # static (default)
wiqd agent validate --mode deep  # validate the resolved app package through wiqd Core
```

### Static mode

Static mode runs the **Microsoft Validation Layer (MVL)** — the same engine the M365 platform uses to accept a manifest. It's offline, needs no auth, and finishes in sub-second on a normal project. It catches:

- Schema violations (missing required fields, wrong types, bad enum values).
- Cross-file references that don't resolve (e.g., a capability that points to a file that isn't there).
- Constraints the M365 platform enforces but a JSON schema alone can't (e.g., maximum number of conversation starters).

This is the mode you should run on every save, on every commit hook, and on every PR.

### Deep mode

Deep mode resolves an already-built app package and hands it to wiqd Core's
in-process validation handler for platform-aware package checks. It does not
build the package or run static validation first. Run the three steps explicitly:

```bash
wiqd agent validate
wiqd agent package
wiqd agent validate --mode deep
```

Deep mode is slower (a few seconds) and does not require the ATK CLI. Use it
before you provision or publish.

## Real-time validation in VS Code

The [VS Code extension](/concepts/vscode-extension/) starts a `wiqd agent lsp` server that streams the same MVL diagnostics into the editor as you type. No save-and-run loop — squigglies appear inline, with hover details and quick fixes where MVL can suggest them.

## Where validation fits in the lifecycle

```text
edit ─▶ static validate ─▶ package ─▶ deep validate ─▶ provision/publish
```

Treat validation as a precondition for every other command in the pipeline. Work IQ Dev Tools don't *force* you to validate before provisioning, but if you don't, you'll find out the same problems the slow way — through an upstream error halfway through a deploy.

## Exit codes

```text
0    Command completed; for deep JSON output, inspect data.valid
1    Static validation errors (your manifest needs fixing)
2    Infrastructure error (not an agent project, missing binary)
130  Cancelled (Ctrl+C)
```

Deep validation findings are a designed domain outcome: the command can exit `0`
with `data.valid: false`. Automation must inspect that field rather than relying
only on the process exit code. See [Exit codes & output](/concepts/exit-codes-output/)
for the shared command contract.

## Go deeper

- [`wiqd agent validate`](/cli/reference/#wiqd-agent-validate) — the command itself
- [`wiqd agent lsp`](/extensions/provided/validate/cli/) — the editor integration
- [Validate extension](/extensions/provided/validate/) — the MVL engine + LSP server
- [VS Code extension](/concepts/vscode-extension/) — installing the live editor experience
- [Agent lifecycle](/concepts/agent-lifecycle/) — where validation sits in the flow
