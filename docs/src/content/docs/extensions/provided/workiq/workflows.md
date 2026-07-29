---
title: Work IQ · Agentic workflows
description: The Copilot orchestrator workflow and reference files the Work IQ extension contributes
---

# Work IQ · Agentic workflows

The Work IQ extension ships an **agentic playbook** for working with deployed agents. When you ask Copilot to monitor, ask, or list agents, the wiqd Copilot orchestrator loads the workflow below and pulls in matching reference files on demand.

## Workflow

| File | Scenarios |
|------|-----------|
| `workflows/workiq.md` | Monitor agent behavior, ask agents directly, list deployed agents, check health. |

## Reference files

Loaded on demand when the workflow needs deep context on a specific topic.

| File | Topic |
|------|-------|
| `monitor.md` | Asking the Insights Agent about a specific agent's performance and usage. |
| `ask.md` | Sending messages to an agent by ID or display name. |
| `list.md` | Listing and filtering deployed agents in the tenant. |
