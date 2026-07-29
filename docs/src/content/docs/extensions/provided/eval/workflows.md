---
title: Eval · Agentic workflows
description: The Copilot orchestrator workflow and reference files the Eval extension contributes
---

# Eval · Agentic workflows

The Eval extension ships an **agentic playbook** for evaluating declarative agents. When you ask Copilot to test, score, or remediate an agent, the wiqd Copilot orchestrator loads the workflow below and pulls in matching reference files on demand.

## Workflow

| File | Scenarios |
|------|-----------|
| `workflows/eval.md` | Generate, run, analyze, compare, and safeguard evaluation suites using the Perceive-Reason-Act (PRA) framework. |

## Reference files

Loaded on demand when the workflow needs deep context on a specific topic.

| File | Topic |
|------|-------|
| `azure-setup.md` | Setting up the Azure resources required for evaluation runs. |
| `eval-templates.md` | Starter `evals.yaml` templates for common agent shapes. |
| `guardrails.md` | Guardrails that prevent suite weakening, deletion, or evaluator removal. |
| `output-schema.md` | Eval run output JSON schema. |
| `pra-framework.md` | The Perceive-Reason-Act framework the workflow follows. |
| `remediation-patterns.md` | How to fix common failure modes surfaced by evals. |
| `result-analysis.md` | Interpreting scores, deltas, and regressions. |
| `workflow.md` | Step-by-step orchestration the skill follows. |
