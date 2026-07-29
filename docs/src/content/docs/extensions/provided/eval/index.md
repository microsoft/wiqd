---
title: Eval
description: Quality evaluations against deployed declarative agents
---

# Eval

**Extension ID:** `microsoft.eval` · **Package:** `@microsoft/wiqd-ext-eval` · **Upstream:** [`@microsoft/m365-copilot-eval`](https://www.npmjs.com/package/@microsoft/m365-copilot-eval)

## What it does

The Eval extension runs **quality evaluations** against a provisioned declarative agent. You write a YAML eval suite (prompts + expected behaviours), and the extension drives the agent through each prompt and scores the response. Use it to catch regressions before publishing, to enforce a quality threshold in CI, or to compare two versions of the same agent head-to-head.

## Workflow walkthrough

```bash
# 1. Scaffold a starter evals.yaml from the agent's name/description
wiqd agent eval init

# 2. Edit evals.yaml — add your prompts, expected behaviours, categories
$EDITOR evals.yaml

# 3. Provision the agent (eval needs a deployed target)
wiqd agent provision --env local

# 4. Run the full suite
wiqd agent eval

# 5. Run a single category with more workers
wiqd agent eval --category Domain --concurrency 10

# 6. Enforce a quality bar in CI — fail the build if score drops below 85
wiqd agent eval --threshold 85 --json | tee eval-results.json
```

A passing run exits `0`. A run that finishes but scores below `--threshold` exits `1`. Infrastructure problems (no agent provisioned, no config file) exit `2`.

## Where to look in the codebase

- `packages/wiqd-ext-eval/wiqd-extension.json` — manifest.
- `packages/wiqd-cli/src/manifest/manifest-executor.ts` — host runtime that drives each command.

> **Note:** `wiqd agent eval` evaluates the **deployed M365 Copilot declarative agent** — not the wiqd CLI itself. The eval suite for wiqd's own behaviour lives in `packages/evals/` and is run via `./scripts/run-evals.ps1`. These are two unrelated evaluation systems that happen to share a name.

## Go deeper

- [CLI commands](/extensions/provided/eval/cli/) — every `wiqd ...` command this extension contributes.
- [Agentic workflows](/extensions/provided/eval/workflows/) — the playbook and reference files the wiqd Copilot orchestrator loads for Eval-driven tasks.
- [Copilot skills](/extensions/provided/eval/skills/) — the natural-language scenarios this extension powers in Copilot Chat.
