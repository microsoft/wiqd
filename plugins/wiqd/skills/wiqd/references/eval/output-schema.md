# M365 Agent Evaluator — Output Schema Reference

Defines the structured output format for the `m365-agent-evaluator` skill, both for human-readable summaries and programmatic callers.

---

## Human-Readable Summary Format

Present results in this format after running and analyzing evals:

```
## Eval Suite Summary

| Category    | Total | Pass | Needs Improvement | Fail |
|-------------|-------|------|-------------------|------|
| Perceive    | N     | N    | N                 | N    |
| Reason      | N     | N    | N                 | N    |
| Act         | N     | N    | N                 | N    |

### Root Cause Breakdown
| Root Cause        | Affected Evals |
|-------------------|----------------|
| Instruction Issue | N              |
| Grounding Issue   | N              |
| Tool/Action Issue | N              |
| Eval Issue        | N (flagged for review) |

### Recommendations
[Prioritized list — see Phase 6 format in workflow.md]

### Next Steps
1. [Actionable recommendation]
2. [Actionable recommendation]
```

---

## Structured Output (Programmatic Callers)

When called programmatically, the skill returns:

```json
{
  "status": "success",
  "workflow": "generated",
  "file_path": "evals/evals.json",
  "results_file": "./.evals/scorecard-<timestamp>.html",
  "results_url": "file:///C:/absolute/path/to/.evals/scorecard-<timestamp>.html",
  "debug_log": "./.evals/runevals-<timestamp>.debug.log",
  "eval_count": 50,
  "by_category": { "Perceive": 20, "Reason": 20, "Act": 10 },
  "errors": []
}
```

---

## Output Files

| File                                      | When Created                      | Description                    |
| ----------------------------------------- | --------------------------------- | ------------------------------ |
| `evals/evals.json`                        | New generation                    | Starter eval suite             |
| `evals/generated-evals.json`              | Generate when evals.json exists   | Additional generated evals     |
| `./.evals/scorecard-<timestamp>.html`     | After default skill run           | Human-readable HTML scorecard  |
| `./.evals/runevals-<timestamp>.debug.log` | After eval run                    | Complete combined terminal log |
| `./.evals/results-<timestamp>.json`       | When JSON is explicitly requested | Machine-readable results       |
