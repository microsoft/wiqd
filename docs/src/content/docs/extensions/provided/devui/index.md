---
title: Work IQ DevUI
description: A local Fluent UI web app for interactively testing and debugging declarative agents
---

# Work IQ DevUI

**Extension ID:** `microsoft.devui` · **Package:** `@microsoft/wiqd-ext-devui` · **Upstream:** bundled `devui` server, authenticating via the [`workiq`](https://www.npmjs.com/package/@microsoft/workiq) CLI

## What it does

The DevUI extension launches a **local, fully self-contained web app** — the Work IQ DevUI — for interactively testing and debugging Microsoft 365 Copilot declarative agents. It's a visual companion to the terminal-based `wiqd agent ask` / `wiqd agent monitor` commands: pick an agent, send prompts, and watch the turn run live in a polished Fluent UI interface with full developer detail (matched/selected plugins, retrieval, citations, request/conversation/task IDs, and raw JSON).

DevUI authenticates to M365 Copilot with a token minted by the `workiq` CLI (`workiq dev token`) and, by default, streams over the **A2A cloud transport** for live token-by-token answers. Because the experience is still evolving, it is hidden behind the `devui` preview flag:

```bash
wiqd config flags set devui true
```

## Workflow walkthrough

```bash
# 0. One-time: opt into the preview flag
wiqd config flags set devui true

# 1. Launch (or reuse) the local DevUI and open it in the browser
wiqd devui start

# 2. Preselect an agent by id or name
wiqd devui start --agent "Sales Copilot Assistant"

# 3. Ask an agent and watch the turn run live in the browser
wiqd devui ask -q "Summarize the latest sales deck" --agent "Sales Copilot Assistant"

# 4. Mint tokens with your own Entra app registration instead of the workiq CLI
wiqd devui config --client-id <your-app-id> --tenant contoso.onmicrosoft.com

# 5. Stop the server when you're done
wiqd devui stop
```

`wiqd devui start` returns immediately once the server is healthy, and a healthy running instance is reused rather than started twice. On Windows, interactively, the server runs in its own console window you can Ctrl+C; on a piped/CI run, with `--no-window`, or on macOS/Linux it runs headlessly and is stopped with `wiqd devui stop`.

## Where to look in the codebase

- `packages/wiqd-ext-devui/wiqd-extension.json` — manifest declaring the `start`/`ask`/`stop`/`config` commands and the `devui` feature flag.
- `packages/wiqd-ext-devui/server/` — the Express bridge that spawns/proxies `workiq` and serves the built client.
- `packages/wiqd-ext-devui/client/` — the Vite + React + Fluent UI v9 web app.
- `packages/wiqd-cli/src/manifest/manifest-executor.ts` — the host runtime that drives each command through this manifest.

## Go deeper

- [CLI commands](cli.md) — every `wiqd ...` command this extension contributes.
- [Agentic workflows](workflows.md) — the playbook and reference files the wiqd Copilot orchestrator loads for DevUI-driven tasks.
- [Copilot skills](skills.md) — this extension contributes no Copilot skills; see why.
