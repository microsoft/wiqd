---
title: DevUI · Agentic workflows
description: The Copilot orchestrator workflow and reference files the DevUI extension contributes
---

# DevUI · Agentic workflows

The DevUI extension ships an **agentic playbook** for launching and driving the local Work IQ DevUI. When you ask Copilot to open the agent debugger or watch a turn run live in the browser, the wiqd Copilot orchestrator loads the workflow below and pulls in the matching reference file on demand.

## Workflow

| File | Scenarios |
|------|-----------|
| `workflows/devui.md` | Launch the local DevUI web app, and ask an agent while watching the turn run live with full developer detail. |

## Reference files

Loaded on demand when the workflow needs deep context on a specific command.

| File | Topic |
|------|-------|
| `start.md` | Starting (or reusing) the local DevUI and opening it in the browser. |
| `ask.md` | Asking an agent and watching the turn run live, deep-linked and auto-sent. |
