---
title: DevUI · Agent plugins
description: Why the Work IQ DevUI extension has no dedicated Copilot skill scenario
---

# DevUI · Agent plugins

The DevUI extension does **not** expose its own Copilot skill scenario. Its manifest declares no `skills` capability — only `commands`, `workflows`, and `references`.

When you ask Copilot to "open devui", "debug my agent visually", or "watch my agent answer live", the wiqd orchestrator routes those phrases through its **DevUI** agentic workflow entry (see [Agentic workflows](/extensions/provided/devui/workflows/)), which calls `wiqd devui start` / `wiqd devui ask` directly. That workflow-level routing is what lifts DevUI into a Copilot Chat conversation — there is no separate Copilot skill package to author or maintain.

## Trigger phrases

The phrases below route into the DevUI workflow rather than a Copilot skill:

> open devui · launch devui · start devui · open the agent debugger · debug my agent · test my agent visually · watch my agent run live · see it run in the browser · ask in devui · run this in the web ui · debug ui · inspect plugins and citations · watch the agent respond · open the debugger

## Why no skill

Copilot skills are the right shape for a scenario a user names and repeatedly invokes as a standalone task (create an agent, submit feedback). DevUI is a **debugging surface**, not a standalone task — it's most useful as a launch step inside another workflow (ATK edit-and-validate, Work IQ ask/monitor) rather than as its own conversational destination. Encoding it as a workflow + reference pair keeps that "launch, then hand off to the browser" shape without the overhead of a skill wrapper.
