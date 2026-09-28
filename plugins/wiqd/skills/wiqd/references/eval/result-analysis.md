# Result Analysis Reference

This reference covers how to interpret and categorize eval results from the M365 Copilot Eval CLI.

---

## 1. Result JSON Schema

Eval CLI 1.15 writes JSON output as a schema-compliant eval document:
`schemaVersion`, `metadata`, optional `default_evaluators`, and `items`. Each
item or turn has an authoritative `status`; each score is an object whose
`result` is `pass`, `fail`, or `error`. The exact pinned schema is vendored at
`references/eval/output-schema.json`.

### Legacy aggregate shape (migration reference only)

The older aggregate example below is retained only to help recognize and
migrate pre-1.15 artifacts. It is **not** the shape emitted by the pinned CLI
and must not be used to implement current result parsing.

```json
{
  "summary": {
    "total_prompts": 30,
    "pass_count": 24,
    "fail_count": 6,
    "pass_rate": 0.8
  },
  "aggregate": {
    "Relevance": {
      "mean_score": 4.2,
      "pass_count": 22,
      "fail_count": 3,
      "prompts_evaluated": 25
    },
    "Groundedness": {
      "mean_score": 3.8,
      "pass_count": 16,
      "fail_count": 4,
      "prompts_evaluated": 20
    },
    "Similarity": {
      "mean_score": 4.5,
      "pass_count": 8,
      "fail_count": 0,
      "prompts_evaluated": 8
    },
    "Citations": {
      "mean_score": 3.1,
      "pass_count": 14,
      "fail_count": 6,
      "prompts_evaluated": 20
    }
  },
  "results": [
    {
      "prompt": "What is the company's policy on remote work equipment reimbursement?",
      "actual_response": "...",
      "expected_response": "...",
      "scores": {
        "Relevance": 4.2,
        "Coherence": 4.5,
        "Groundedness": 3.1,
        "Citations": 2.8
      }
    },
    {
      "prompt": "Please submit an expense report for my business trip.",
      "actual_response": "...",
      "expected_response": "...",
      "scores": {
        "Relevance": 4.6,
        "Coherence": 4.3,
        "Groundedness": 4.1,
        "Similarity": 4.8
      }
    },
    {
      "prompt": "Can you help me write a marketing email?",
      "actual_response": "...",
      "expected_response": "...",
      "scores": {
        "PartialMatch": 1.0
      }
    }
  ]
}
```

### Key schema differences from the flat-array format

| Concept               | Old (flat array)                  | New (eval document)                                     |
| --------------------- | --------------------------------- | ------------------------------------------------------- |
| Score keys per prompt | Always all evaluators (some null) | Only evaluators that ran (sparse)                       |
| Missing score key     | Evaluator ran and returned null   | Evaluator did NOT run on this prompt                    |
| `null` score          | Tool not invoked                  | Not used — key is absent instead                        |
| Aggregate stats       | Per-metric mean only              | `prompts_evaluated` alongside `pass_count`/`fail_count` |
| Pass rate             | `pass_count / total_prompts`      | `pass_count / (pass_count + fail_count)`                |

**Critical:** A missing score key does NOT mean the evaluator failed — it means the evaluator was not configured to run on that prompt. Do not treat absence as failure.

---

## 2. Interpreting Per-Prompt Scores

For Eval CLI 1.15 output, use item/turn `status` as authoritative. If status is
absent in an older compatible eval document, require every present
`scores.*.result` value to be `pass`. Never count `partial` or `error` as a
passing item.

The numeric-score guidance below applies only to the legacy aggregate shape.

When analyzing individual prompt results:

1. **Check which evaluators ran**: Look at the keys in `scores`. Only keys present were evaluated.
2. **Correlate with PRA category**: Perceive prompts should have Groundedness + Citations scores; Act prompts typically use `Relevance`/`Coherence`/`Similarity` against a precise `expected_response` (`ToolCallAccuracy` is currently unsupported — see [gaps.md](gaps.md)); Boundary prompts should have only PartialMatch or ExactMatch.
3. **Apply thresholds by evaluator type**:

| Evaluator         | Pass threshold                            | Type                        |
| ----------------- | ----------------------------------------- | --------------------------- |
| `Relevance`       | ≥ 4.0                                     | LLM (1–5 scale)             |
| `Coherence`       | ≥ 4.0                                     | LLM (1–5 scale)             |
| `Groundedness`    | ≥ 4.0 (default) or ≥ configured threshold | LLM (1–5 scale)             |
| `Similarity`      | ≥ 4.0                                     | LLM (1–5 scale)             |
| `Citations`       | ≥ configured minimum count                | Count-based (deterministic) |
| `RetrievalQuery`  | pass                                      | Non-LLM (deterministic)     |
| `RetrievalResult` | pass                                      | Non-LLM (deterministic)     |
| `ExactMatch`      | = 1.0                                     | String (pass/fail)          |
| `PartialMatch`    | ≥ configured threshold (default 0.7)      | String (0–1 similarity)     |

> `ToolCallAccuracy` is not currently a supported evaluator (see [gaps.md](gaps.md)) — it will never appear in a `scores` object.

**Outcome classification** is determined by the lowest score among evaluators that ran:

| Outcome           | Condition                                             |
| ----------------- | ----------------------------------------------------- |
| Pass              | All scores meet their thresholds                      |
| Needs Improvement | Lowest score 2.5–3.9 (LLM) or 0.5–0.69 (PartialMatch) |
| Fail              | Any score below 2.5 (LLM) or 0 (ExactMatch)           |

---

## 3. Interpreting Aggregate Statistics

Eval CLI 1.15 JSON output has no top-level `aggregate` section. The HTML
scorecard computes aggregates across prompts where each evaluator ran. The
table below documents the legacy aggregate shape only.

| Field               | Meaning                                                    |
| ------------------- | ---------------------------------------------------------- |
| `mean_score`        | Average score across prompts where this evaluator ran      |
| `pass_count`        | Number of prompts where this evaluator passed              |
| `fail_count`        | Number of prompts where this evaluator failed              |
| `prompts_evaluated` | Number of prompts where this evaluator ran (= pass + fail) |

**Pass rate** for a given evaluator = `pass_count / prompts_evaluated` (NOT `pass_count / total_prompts`).

When summarizing results, always report `prompts_evaluated` alongside pass/fail counts:

- ✅ "Groundedness: 16/20 passed (80%) across 20 Perceive prompts"
- ❌ "Groundedness: 16/30 passed" (misleading — denominator should be prompts evaluated, not total)

---

## 4. HTML Report Visual Cues

The HTML report includes visual indicators for per-prompt evaluator configuration:

| Visual element                             | Meaning                                                                 |
| ------------------------------------------ | ----------------------------------------------------------------------- |
| **Evaluator badges** on prompt cards       | Color-coded: blue = LLM evaluator (1–5 scale), green = string evaluator |
| **Prompts: X/Y** column in aggregate table | How many prompts each evaluator ran on (X) out of total prompts (Y)     |
| Per-prompt score table                     | Only shows evaluators that ran on that prompt                           |
| Summary banner                             | Total passed/failed counts and overall pass rate                        |

When analyzing the HTML report, use evaluator badges to quickly identify which category a prompt belongs to (e.g., a prompt with only green badges is a Boundary/Deterministic prompt; a prompt with blue badges is a Perceive/Act prompt).

After a successful skill-driven run, analyze the generated HTML scorecard immediately and return its absolute `file:///` URL. Correlate each major failure with the available agent artifacts before recommending a change:

| Layer                 | Evidence to inspect                                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Instructions          | Required behavior, scope, source priority, refusal rules, examples, and response format                            |
| Tools/actions         | Whether a declared API/MCP action can perform the task and whether its descriptions guide selection and parameters |
| Knowledge sources     | Whether the expected information is covered, accessible, prioritized, and required for grounding                   |
| Manifest/capabilities | Whether the evaluated capability is enabled and wired to the agent                                                 |
| Evaluation design     | Whether the prompt is answerable and the expectation, evaluator, and threshold match the requirement               |

Do not recommend an instruction change for a missing tool, capability, or knowledge source. Mark unavailable artifact evidence explicitly instead of guessing.

---

## 5. Failure Diagnosis

### By evaluator type

| Evaluator failing  | Likely cause                                                           | What to check                                                                                                                                                                                                        |
| ------------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Relevance`        | Agent not understanding query; system instructions too broad or narrow | Review system instructions scope; check if query is within declared domain                                                                                                                                           |
| `Groundedness`     | Agent hallucinating facts not in knowledge sources                     | Check `context` field matches actual knowledge source content; verify source is accessible and indexed                                                                                                               |
| `Coherence`        | Response disorganized or hard to follow                                | Add structure guidance to system instructions                                                                                                                                                                        |
| `Citations`        | Agent not citing sources or wrong citation format                      | Verify `--citation-format` flag in runevals command; check knowledge source config                                                                                                                                   |
| `Similarity` (Act) | Response wording diverges from expected confirmation/action outcome    | Review action manifest and parameter descriptions; verify agent transcript for wrong tool/parameters — `ToolCallAccuracy` is currently unsupported (see [gaps.md](gaps.md)), so manual transcript review is required |
| `ExactMatch`       | Agent adding extra text or rephrasing                                  | Consider switching to `PartialMatch` if exact wording isn't critical                                                                                                                                                 |
| `PartialMatch`     | Expected substring not found or similarity below threshold             | Check if agent uses completely different wording; verify expected_response contains realistic substring                                                                                                              |

### Cross-cutting patterns

| Pattern                                               | Likely cause                                                                             |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `Relevance` + `Groundedness` both fail                | Off-topic AND hallucinating → system instruction scoping issue                           |
| `Groundedness` fails, `Relevance` passes              | Understood the question but fabricated the answer → knowledge source gap                 |
| `Similarity` fails on Act prompts, `Relevance` passes | Understood intent but wrong tool/parameters (verify manually) → action manifest mismatch |
| All Boundary prompts fail                             | System instructions don't define what's out of scope                                     |
| `Citations` fails across all Perceive prompts         | Knowledge source grounding not returning citable references                              |
| `Coherence` fails across all Reason prompts           | Systematic gap in instruction quality affecting response structure                       |

### Correlating failures with PRA categories

Group failures by which evaluators were present in the failing prompt's `scores` object to identify which PRA category is problematic:

- Failures with `Groundedness`/`Citations` scores → **Perceive failures** → knowledge source issues
- Failures with `Coherence`/`Relevance` scores only → **Reason failures** → instruction issues
- Failures on Act-category prompts (identify by prompt content/PRA label, not by a `ToolCallAccuracy` score — it doesn't exist) → **Act failures** → action/manifest issues, confirm via manual transcript review
- Failures with only `PartialMatch`/`ExactMatch` scores → **Boundary/Deterministic failures** → scope definition issues

---

## 6. Root Cause Categories

For each failing or degraded eval, identify the root cause category before recommending fixes. Use the signals and distinguishing questions below.

| Category          | Signals                                                                                                                                                     | Distinguishing Question                                                                          |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Instruction Issue | Low Relevance, Coherence, or Groundedness across Reason prompts                                                                                             | Is the agent ignoring or misapplying its instructions?                                           |
| Tool/Action Issue | Low `Similarity`/`Relevance` on Act prompts, or manual transcript review shows a mismatch (no `ToolCallAccuracy` evaluator exists — see [gaps.md](gaps.md)) | Did the agent call the wrong tool, use wrong parameters, or fail to call a tool when required?   |
| Grounding Issue   | Low Groundedness despite correct instructions, on Perceive prompts                                                                                          | Does the grounding source exist and contain relevant data? Does `context` match the real source? |
| Citation Issue    | Low Citations on Perceive prompts                                                                                                                           | Did the agent retrieve correctly but forget to cite sources?                                     |
| Eval Issue        | Agent seems correct but eval fails                                                                                                                          | Does the expected_response match what a well-functioning agent would actually produce?           |
| Capability Gap    | Agent unable to perform action                                                                                                                              | Is the required capability missing from the manifest?                                            |

---

## 7. Distinguishing Instruction vs Grounding Issues

Both Instruction Issues and Grounding Issues can produce low Groundedness scores. Use these signals to tell them apart:

**Instruction Issue:**

- The agent's response is generic or ignores available context
- The agent does not attempt to use grounding sources at all
- The manifest declares no grounding sources, or instructions do not direct the agent to use them
- Fix target: system instructions (add source-usage directives)

**Grounding Issue:**

- The agent's response attempts to answer but uses wrong or hallucinated data
- The manifest declares grounding sources, but the agent cannot retrieve relevant content
- The `context` field in the eval contains content the agent should have referenced but didn't
- The grounding source may be missing, inaccessible, not indexed, or lack relevant content
- Fix target: grounding configuration (add/correct source URL, verify permissions, verify indexing)

**Decision rule:** Check the manifest first. If no grounding sources are declared, the failure is always an Instruction Issue — the agent was never told to use sources. If sources are declared, investigate whether the source exists, is accessible, and contains relevant content. Compare the actual response against the `context` field to determine if the agent had access to the right data.

---

## 8. Bad Eval Detection

Some eval failures are caused by poorly written test cases rather than agent defects. Flag the following patterns for **human review** — do NOT auto-fix the agent or mark as agent failure.

**Heuristic 1 — Scope clarification pattern:**
Response contains phrases such as "I can only...", "I don't have information about...", "My scope is limited to..."
This suggests the prompt asks about something outside the agent's declared scope. The eval may be testing a capability the agent was never designed to provide.

**Heuristic 2 — Capability disclaimer:**
Response contains phrases such as "I cannot perform...", "You'll need to use...", "That action is not available..."
This suggests the eval expected an action the agent does not have. Check whether the capability is absent intentionally.

**Heuristic 3 — Consistent category failures:**
Three or more evals with similar prompt patterns all fail with similar scores and response content. This indicates a systematic scope or capability mismatch introduced during eval generation, not a targeted agent defect.

**Heuristic 4 — Instruction echo:**
The agent quotes or paraphrases its own system instructions or constraints in the response. This suggests the eval prompt violates declared limitations and the agent is correctly refusing or redirecting.

**When flagged:** Report as "Potential Eval Issue — review expected_response before assuming agent failure." Present the flagged evals to the user with the specific heuristic that triggered, and do not issue agent fix recommendations until the eval is confirmed valid.

---

## 9. Pattern Identification

After classifying individual evals, group failures to identify patterns that can be resolved with a single fix. Grouping dimensions:

- **Root cause category** — multiple evals sharing the same category often share a fix
- **Eval category (P/R/A/Boundary)** — failures concentrated in one PRA category point to different layers of the agent
- **Grounding source or action** — failures tied to a specific source or action isolate the broken component
- **Evaluator** — all failures on a specific evaluator (e.g., all Citations failures) often have a single systemic cause

**Example patterns:**

- "3 Perceive evals failed Groundedness — `context` references SharePoint source that returns 404" — fixing source URL resolves all three
- "All Act evals for [action Y] fail with low `Similarity`/`Relevance` and manual transcript review shows the wrong action was invoked" — the action definition or parameter descriptions need updating
- "Low Coherence across all Reason evals" — a systematic gap in instruction quality affecting response structure
- "All Boundary prompts fail PartialMatch" — expected_response substrings don't match the agent's actual refusal wording; update expected_response or adjust system instructions

Report identified patterns before listing individual recommendations. A pattern-level fix is always higher priority than an isolated fix.
