---
title: Work IQ
description: Monitor, ask, and list deployed declarative agents
---

# Work IQ

**Extension ID:** `microsoft.workiq` · **Package:** `@microsoft/wiqd-ext-workiq` · **Upstream:** [`@microsoft/workiq`](https://www.npmjs.com/package/@microsoft/workiq) `1.0.0`

## What it does

The Work IQ extension is your window into agents that are **already deployed in the tenant**. It lets you list every declarative agent in the tenant, send messages to any of them by ID or name, and query the **Insights Agent** about a specific agent's performance, usage, and health.

The wiqd installer and `wiqd doctor` pre-warm the extension's exact Work IQ pin into
managed `~/.wiqd/extensions/microsoft.workiq/` state. If pre-warm was skipped or
failed, the first Work IQ command retries through the same managed lifecycle. You do
not need to install Work IQ globally; wiqd ignores unrelated host or `PATH` copies.
The managed generation survives host updates and reinstalls, and refreshes
automatically when a new wiqd release ships a different extension pin.

`wiqd ext list` remains read-only. An explicit `WORKIQ_PATH` override is shown there as
unvalidated and is checked by `wiqd doctor` or immediately before command execution.

These commands need authentication to the Work IQ service (covered by `wiqd auth login`). Because the surface is still evolving, every command in this extension requires `experimental=true` in your wiqd config:

```bash
wiqd config set experimental true
```

## Workflow walkthrough

```bash
# 0. One-time: enable experimental features
wiqd config set experimental true

# 1. List every declarative agent deployed in the tenant
wiqd agent list

# 2. Filter by name
wiqd agent list --name "Sales"

# 3. Send a test message to an agent by ID
wiqd agent ask --agent-id "T_b6bd...declarativeAgent" -q "Hello, summarize the latest sales deck."

# 4. Or send it by display name
wiqd agent ask --agent-name "Sales Copilot Assistant" -q "..."

# 5. Ask the Insights Agent how a specific agent is doing
wiqd agent monitor --path ./my-agent --env staging --query "How often was this agent askd last week?"
```

`wiqd agent monitor` is the most useful command in this extension day-to-day — it lets you ask natural-language questions about an agent's metrics rather than digging through a dashboard.

## Where to look in the codebase

- `packages/wiqd-ext-workiq/wiqd-extension.json` — manifest.
- `packages/wiqd/src/manifest/manifest-executor.ts` — host runtime.

> **Authentication note:** these commands require an authenticated Work IQ session. Run `wiqd auth login` (or `wiqd auth status` to check state) before first use; if you hit auth errors during `wiqd doctor`, re-run `wiqd auth login`.

## Go deeper

- [CLI commands](/extensions/provided/workiq/cli/) — every `wiqd ...` command this extension contributes.
- [Agentic workflows](/extensions/provided/workiq/workflows/) — the playbook and reference files the wiqd Copilot orchestrator loads for Work IQ-driven tasks.
- [Copilot skills](/extensions/provided/workiq/skills/) — the natural-language scenarios this extension powers in Copilot Chat.
