---
title: Eval · Agent plugins
description: The natural-language scenarios the Eval extension powers in Copilot Chat
---

# Eval · Agent plugins

When you talk to Copilot Chat with the wiqd plugin loaded, the Eval extension's workflow shows up as the **"Eval tasks"** routing entry. Saying any of the trigger phrases below lifts the right Eval flow into the conversation.

## Scenarios unlocked

The Eval workflow covers the **Improve** stage of the agent journey, after the manifest is structurally valid and before you preview the agent in the tenant:

- **Generate evals** — propose a starter `evals.yaml` from the agent's instructions, capabilities, and actions.
- **Run evals** — execute the full suite or a single category; surface a pass-rate and per-prompt deltas.
- **Analyze results** — interpret scores, compare two runs head-to-head, identify regressions.
- **Remediate** — propose manifest edits that move failing prompts back to passing without weakening the suite.
- **Safeguard the suite** — block deletion, evaluator removal, or threshold weakening. The orchestrator owns every change to `evals/evals.json`.

## Trigger phrases

Saying any of these in Copilot Chat routes the orchestrator into the Eval workflow:

> evaluate my agent · test my agent · run my evals · run my tests · check my agent · is my agent correct · my agent isn't working · generate evals · propose eval updates · analyze eval results · modify evals · edit evals · weaken evals · delete evals

## Where Eval sits in the journey

Eval is **stage 2 of 4** in the wiqd agent journey — the **Improve** stage. It runs after [ATK](/extensions/provided/atk/skills/) builds a valid manifest, and before [Work IQ](/extensions/provided/workiq/skills/) takes the agent into Preview. The exit gate is "evals pass at acceptable rate."
