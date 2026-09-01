---
title: Agents Toolkit (ATK)
description: Full agent lifecycle — scaffold, edit, validate, package, provision, publish
---

# Agents Toolkit (ATK)

**Extension ID:** `microsoft.atk` · **Package:** `@microsoft/wiqd-ext-atk` · **Upstream:** [`@microsoft/m365agentstoolkit-cli`](https://www.npmjs.com/package/@microsoft/m365agentstoolkit-cli) `>=1.1.0 <2.0.0`

## What it does

The ATK extension is the heart of the declarative-agent lifecycle. It wraps the upstream **Agents Toolkit** (`atk`) CLI and exposes its full lifecycle — scaffold, edit, provision, package, publish, share, delete — under the `wiqd agent` namespace. Every command runs `atk` in non-interactive mode (`-i false`) so Work IQ Dev Tools own the prompt experience, validate filesystem postconditions after each run, and turn raw upstream errors into actionable messages.

When a command needs ATK but it's not installed, you get a clear error (exit code `2`) with an install prompt. In an interactive terminal, you are offered to install with explicit consent; in CI, the remediation command is printed and the command exits.

## Workflow walkthrough

A typical end-to-end session against the `local` environment:

```bash
# 1. Scaffold
wiqd agent create --name my-agent
cd my-agent

# 2. Look at what you got
wiqd agent show

# 3. Add an action backed by an OpenAPI spec
wiqd agent add action --openapi-spec ./specs/weather.yaml --operations "GET /weather"

# 4. Validate before deploying
wiqd agent validate --mode deep

# 5. Provision into the local environment
wiqd agent provision --env local

# 6. Build the distributable package
wiqd agent package

# 7. Share with a teammate
wiqd agent share --email alice@contoso.com

# 8. Publish to the org catalog when ready
wiqd agent publish --env prod
```

Behind every command, Work IQ Dev Tools are shelling out to `atk` with the right arguments, validating that the expected files exist after the run, and presenting the result through its standard table or JSON output.

## Where to look in the codebase

- `packages/wiqd-ext-atk/wiqd-extension.json` — manifest declaring every command.
- `packages/wiqd-ext-atk/transforms/*.mjs` — per-command transform scripts.
- `packages/wiqd/src/manifest/manifest-executor.ts` — the host runtime that drives each command through this manifest.

## Go deeper

- [CLI commands](/extensions/provided/atk/cli/) — every `wiqd ...` command this extension contributes.
- [Agentic workflows](/extensions/provided/atk/workflows/) — the playbook and reference files the wiqd Copilot orchestrator loads for ATK-driven tasks.
- [Copilot skills](/extensions/provided/atk/skills/) — the natural-language scenarios this extension powers in Copilot Chat.
