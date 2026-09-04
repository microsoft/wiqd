---
title: Eval
description: Quality evaluations against deployed declarative agents
---

# Eval

**Extension ID:** `microsoft.eval` · **Package:** `@microsoft/wiqd-ext-eval` · **Upstream:** [`@microsoft/m365-copilot-eval`](https://www.npmjs.com/package/@microsoft/m365-copilot-eval)

## What it does

The Eval extension runs **quality evaluations** against a provisioned declarative agent. You write a JSON prompts file, and the extension drives the agent through each prompt and scores the response. Use it to catch regressions before publishing or to enforce a quality threshold in CI.

The wiqd installer and `wiqd doctor` pre-warm the extension's exact Eval CLI pin into
managed `~/.wiqd/extensions/microsoft.eval/` state. If pre-warm was skipped or failed,
the first Eval command retries through the same managed lifecycle. You do not need to
install the Eval CLI globally; host and `PATH` copies do not satisfy this prerequisite.
The managed generation survives host updates and reinstalls, and refreshes
automatically when a new wiqd release changes the extension pin.

## Workflow walkthrough

```bash
# 1. Copy the bundled starter suite to evals/prompts.json
wiqd agent eval init

# 2. Edit the prompts and evaluators for your agent
$EDITOR evals/prompts.json

# 3. Provision the agent (eval needs a deployed target)
wiqd agent provision --env local

# 4. Run the full suite
wiqd agent eval

# 5. Increase concurrency, up to the supported maximum of 5
wiqd agent eval --concurrency 5

# 6. Enforce an 85% quality bar in CI
wiqd agent eval --threshold 0.85 --json | tee eval-results.json
```

A completed run exits `0` when any configured threshold is met. Failures exit `1`; in JSON mode, `error.code` distinguishes a threshold miss (`EXIT_CONDITION_MET`) from an upstream failure (`UPSTREAM_ERROR`). wiqd preflight or validation errors exit `2`, required EULA acceptance exits `3`, and cancellation exits `130`.

## Where to look in the codebase

- `packages/wiqd-ext-eval/wiqd-extension.json` — manifest.
- `packages/wiqd/src/manifest/manifest-executor.ts` — host runtime that drives each command.

> **Note:** `wiqd agent eval` evaluates the **deployed M365 Copilot declarative agent** — not the wiqd CLI itself. The eval suite for wiqd's own behaviour lives in `packages/evals/` and is run via `./scripts/run-evals.ps1`. These are two unrelated evaluation systems that happen to share a name.

## Go deeper

- [CLI commands](/extensions/provided/eval/cli/) — every `wiqd ...` command this extension contributes.
- [Agentic workflows](/extensions/provided/eval/workflows/) — the playbook and reference files the wiqd Copilot orchestrator loads for Eval-driven tasks.
- [Copilot skills](/extensions/provided/eval/skills/) — the natural-language scenarios this extension powers in Copilot Chat.
