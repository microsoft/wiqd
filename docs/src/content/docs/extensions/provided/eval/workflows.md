---
title: Eval · Agentic workflows
description: The Copilot orchestrator workflow and reference files the Eval extension contributes
---

# Eval · Agentic workflows

The Eval extension ships an **agentic playbook** for evaluating declarative agents. When you ask Copilot to test, score, or remediate an agent, the wiqd Copilot orchestrator loads the workflow below and pulls in matching reference files on demand.

Every invocation starts with a blocking dataset choice: use an existing compatible eval document discovered under `evals/**/*.json`, or generate a new dataset. When multiple datasets exist, the orchestrator asks which one to use before separately asking whether to run it, propose updates, or analyze prior results. The choice is never inferred from filenames or previous runs.

## Workflow

| File | Scenarios |
|------|-----------|
| `workflows/eval.md` | Generate and run evals with the GitHub Copilot judge, produce a timestamped HTML scorecard, correlate results with agent artifacts, recommend targeted improvements, compare runs, and safeguard evaluation suites. |

## Reference files

Loaded on demand when the workflow needs deep context on a specific topic.

| File | Topic |
|------|-------|
| `azure-setup.md` | Setting up the Azure resources required for evaluation runs. |
| `eval-templates.md` | Starter `evals.yaml` templates for common agent shapes. |
| `gaps.md` | Known gaps in the Evals CLI and this skill's integration (e.g. `ToolCallAccuracy` is unsupported). |
| `guardrails.md` | Guardrails that prevent suite weakening, deletion, or evaluator removal. |
| `judge-backends.md` | `--judge-backend` options and the evaluator compatibility matrix (GHCP vs. Azure). |
| `output-schema.md` | Eval run output JSON schema. |
| `pra-framework.md` | The Perceive-Reason-Act framework the workflow follows. |
| `remediation-patterns.md` | How to fix common failure modes surfaced by evals. |
| `result-analysis.md` | Interpreting scores, deltas, and regressions. |
| `workflow.md` | Step-by-step orchestration the skill follows. |
