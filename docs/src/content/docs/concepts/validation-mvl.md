---
title: Validation & MVL
description: Static and deep validation of declarative agent manifests
---

# Validation & MVL

Validation is the single fastest feedback loop in Work IQ Dev Tools. You run it before every commit, before every provision, and in CI on every PR. It tells you whether your manifest is well-formed against the *current* shipping declarative-agent schema — and it does it in well under a second.

## Two modes

```bash
wiqd agent validate              # static (default)
wiqd agent validate --mode deep  # static + ATK semantic checks
```

### Static mode

Static mode runs the **Microsoft Validation Layer (MVL)** — the same engine the M365 platform uses to accept a manifest. It's offline, needs no auth, and finishes in sub-second on a normal project. It catches:

- Schema violations (missing required fields, wrong types, bad enum values).
- Cross-file references that don't resolve (e.g., a capability that points to a file that isn't there).
- Constraints the M365 platform enforces but a JSON schema alone can't (e.g., maximum number of conversation starters).

This is the mode you should run on every save, on every commit hook, and on every PR.

### Deep mode

Deep mode runs everything static does, then hands off to the Agents Toolkit's semantic validator. That covers things only ATK knows about — for example, whether an action's OpenAPI spec is reachable and well-formed, whether a referenced plugin manifest declares the right auth scheme, and platform-specific manifest constraints that change with the M365 release cadence.

Deep mode is slower (a few seconds) and needs ATK installed. Use it before you provision or publish.

## Real-time validation in VS Code

The [VS Code extension](/concepts/vscode-extension/) starts a `wiqd agent lsp` server that streams the same MVL diagnostics into the editor as you type. No save-and-run loop — squigglies appear inline, with hover details and quick fixes where MVL can suggest them.

## Where validation fits in the lifecycle

```text
edit ─▶ validate ─▶ provision ─▶ package ─▶ publish
          │
          ├── static  (every save, every commit, every PR)
          └── deep    (before provision/publish, in CI)
```

Treat validation as a precondition for every other command in the pipeline. Work IQ Dev Tools don't *force* you to validate before provisioning, but if you don't, you'll find out the same problems the slow way — through an upstream error halfway through a deploy.

## Exit codes

```text
0    No diagnostics
1    Validation errors (your manifest needs fixing)
2    Infrastructure error (not an agent project, missing binary)
130  Cancelled (Ctrl+C)
```

This is the same shape every Work IQ Dev Tools command uses — see [Exit codes & output](/concepts/exit-codes-output/) for the contract.

## Go deeper

- [`wiqd agent validate`](/cli/reference/#wiqd-agent-validate) — the command itself
- [`wiqd agent lsp`](/extensions/provided/validate/cli/) — the editor integration
- [Validate extension](/extensions/provided/validate/) — the MVL engine + LSP server
- [VS Code extension](/concepts/vscode-extension/) — installing the live editor experience
- [Agent lifecycle](/concepts/agent-lifecycle/) — where validation sits in the flow
