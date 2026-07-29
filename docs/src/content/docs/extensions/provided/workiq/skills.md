---
title: Work IQ · Agent plugins
description: The natural-language scenarios the Work IQ extension powers in Copilot Chat
---

# Work IQ · Agent plugins

When you talk to Copilot Chat with the wiqd plugin loaded, the Work IQ extension's workflow shows up as the **"WorkIQ tasks"** routing entry. Saying any of the trigger phrases below lifts the right Work IQ flow into the conversation.

## Scenarios unlocked

The Work IQ workflow covers the **Preview** stage of the agent journey — confirming that a deployed agent behaves correctly in the tenant before publishing it broadly:

- **Monitor** — ask the Insights Agent natural-language questions about an agent's performance, usage, and health.
- **Ask** — send a test message to a deployed agent by ID or by display name and inspect the response.
- **List** — enumerate every declarative agent in the tenant, optionally filtered by name.
- **Check health** — combine monitor + ask to confirm an agent is responsive end-to-end.

## Trigger phrases

Saying any of these in Copilot Chat routes the orchestrator into the Work IQ workflow:

> monitor my agent · observe my agent · how is my agent doing · check agent health · invoke my agent · talk to my agent · send a message · ask my agent · list my agents · show deployed agents · find agent by name

## Where Work IQ sits in the journey

Work IQ is **stage 3 of 4** in the wiqd agent journey — the **Preview** stage. It runs after [Eval](/extensions/provided/eval/skills/) confirms the agent meets its quality bar. This is the final stage before the agent is published to its target audience.
