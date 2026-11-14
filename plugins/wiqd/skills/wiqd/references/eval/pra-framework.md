# PRA Framework: Perceive-Reason-Act for Agent and Plugin Evaluation

## Overview

The Perceive-Reason-Act (PRA) framework categorizes eval scenarios by the cognitive layer of the agent being tested. It maps directly to common agent failure modes:

- **Perceive** — the agent fails to find or use the right information
- **Reason** — the agent draws wrong conclusions or violates constraints
- **Act** — the agent calls the wrong tool or cites incorrectly

PRA determines **what to test**. It is orthogonal to Eval CLI metrics, which measure **how well** the agent performed on a given scenario. See [Relationship to Eval CLI Metrics](#relationship-to-eval-cli-metrics).

Using PRA ensures eval suites are structurally complete — they cover the agent's full cognitive loop rather than clustering tests around a single failure mode.

---

## Category Definitions

### Perceive — Retrieval and Grounding

**What it tests:** Whether the agent retrieves relevant information from declared grounding sources and uses it faithfully in responses.

**Applicability:** ONLY include Perceive evals IF the manifest declares at least one grounding source (SharePoint sites, Graph connectors, knowledge bases, or equivalent).

**Tests:**

- Retrieval accuracy: does the agent return information that exists in the grounding source?
- Context relevance: is retrieved content germane to the query?
- Grounding source coverage: are all declared sources exercised across the eval set?
- Retrieval edge cases: queries at the boundary of what the source contains (e.g., near-miss topics, slightly out-of-scope questions)

**Common failure modes:**

- Agent retrieves content from the wrong source
- Agent ignores grounding sources and generates from parametric memory
- Agent hallucinates when the source contains no matching content, rather than saying it doesn't know
- Agent retrieves stale or partially matching content and presents it as authoritative

**Example prompt types:**

- "What is the company policy on [topic covered in SharePoint]?"
- "Find the latest [document type] from [connector source]."
- "What does [source] say about [topic not in source]?" (tests graceful handling)
- "Compare [item A] and [item B] using the knowledge base."

---

### Reason — Logic, Coherence, and Instruction Adherence

**What it tests:** Whether the agent follows its system instructions, avoids hallucination, and produces logically coherent responses.

**Applicability:** Applies to Agent instructions and Plugin skill/instruction
constraints. For connector-only Plugins, derive Reason from verified tool task
descriptions, required inputs and constraints; missing instructions alone must not
block generation. A usable behavioral definition is still required.

**Tests:**

- Response coherence: does the answer make sense given the question?
- Hallucination resistance: does the agent avoid inventing facts not in context?
- Instruction adherence: does the agent respect constraints (tone, scope, persona, topic limits) defined in system instructions?
- Reasoning edge cases: ambiguous queries, multi-step reasoning, conflicting information

**Common failure modes:**

- Agent makes up facts not present in grounding or instructions
- Agent ignores explicit scope constraints (e.g., answers questions it was told to decline)
- Agent gives contradictory answers across turns
- Agent applies the wrong persona or tone
- Agent fails multi-step reasoning that the instructions imply it should handle

**Example prompt types:**

- "What can you help me with?" (tests scope adherence)
- "[Question outside declared scope]" (tests constraint enforcement)
- "You said X earlier, but now you're saying Y — which is correct?" (tests coherence)
- "[Ambiguous query that requires inferring user intent]"
- "[Multi-step question requiring chained reasoning]"

---

### Act — Tool Invocation and Citations

**What it tests:** Whether the agent correctly selects and invokes declared capabilities/actions, passes correct parameters, handles errors gracefully, and cites sources accurately.

**Applicability:** ONLY include Act evals IF the manifest declares at least one capability or action (plugins, API connectors, function tools, or equivalent).

**Tests:**

- Action invocation accuracy: does the agent call the right action for the task?
- Tool selection: when multiple actions are available, does the agent pick the appropriate one?
- Citation accuracy: are citations accurate, present when required, and absent when not applicable?
- Action error handling: does the agent respond gracefully when an action fails or returns no results?

**Common failure modes:**

- Agent calls the wrong action for the user's intent
- Agent passes malformed or missing parameters to an action
- Agent omits required citations after retrieving or acting
- Agent fabricates citations
- Agent fails silently when an action errors, rather than informing the user
- Agent invokes an action when none was needed

**Example prompt types:**

- "[Task that maps directly to a declared action]"
- "[Task that maps to one of several available actions]" (tests tool selection)
- "[Task where no action applies]" (tests restraint — agent should not invoke tools)
- "[Request that requires chaining two actions]"
- "[Scenario where the action would return an error or empty result]"

---

## Applicability Rules

The following table determines which PRA categories apply based on manifest contents.

| Manifest Contents                              | Perceive    | Reason | Act | Notes                                   |
| ---------------------------------------------- | ----------- | ------ | --- | --------------------------------------- |
| System instructions + grounding + capabilities | YES         | YES    | YES | Full PRA                                |
| System instructions + grounding only           | YES         | YES    | NO  | No actions declared                     |
| System instructions + capabilities only        | NO          | YES    | YES | No grounding sources                    |
| System instructions only                       | NO          | YES    | NO  | No grounding or actions                 |
| Connector-only Plugin with verified tools      | If grounded | YES    | YES | Reason uses tool/task/input constraints |
| Agent without system instructions              | ERROR       | —      | —   | Ask for Agent instructions              |

**Grounding sources** include: SharePoint sites, Graph connectors, knowledge bases, file uploads, web search plugins when scoped.

**Capabilities/actions** include: plugins, API connectors, function tools, external service integrations declared in the manifest.

Do not infer grounding from a connector's existence or tools from a skill name.
Read the registered definitions. An MCP URL without tool metadata leaves callable
inventory unknown; obtain metadata or clarify before recommending tool coverage.
Root Plugin `agentSkills[]`/`agentConnectors[]` are distinct from an Agent's
embedded skills/actions. Resolve the evaluation target before applying this table.
For Plugin grounding/reference-answer scenarios, use Groundedness with actual
source context or Similarity with a specific reference response, never Citations
or Retrieval evaluators. These alternatives assess answers, not citation
correctness or retrieval queries/results/ranking. Report that coverage limitation;
do not fabricate source/reference content or silently rewrite an existing suite.

---

## Slot Allocation

When generating a manifest-aware eval suite, the total target count is determined by a complexity-based assessment presented to the user before generation.

### Complexity tiers

Apply tiers in priority order — use the **first matching tier**:

Count callable functions/tools inside referenced plugin files rather than only top-level action references.

| Complexity Tier | Criteria (apply first match)                   | Recommended Eval Count |
| --------------- | ---------------------------------------------- | ---------------------- |
| Complex         | 9+ callable actions                            | 20–25 evals            |
| Medium          | 4–8 actions, OR any grounding sources declared | 12–18 evals            |
| Simple          | ≤3 actions AND no grounding sources            | 8–10 evals             |

### Allocation ratios (T = confirmed target count)

Distribute the confirmed target count proportionally across applicable PRA categories:

| Applicable categories | Perceive | Reason    | Act      |
| --------------------- | -------- | --------- | -------- |
| P + R + A             | 40% of T | 40% of T  | 20% of T |
| P + R                 | 50% of T | 50% of T  | —        |
| R + A                 | —        | 60% of T  | 40% of T |
| R only                | —        | 100% of T | —        |

Round each slot to the nearest integer. If rounding produces a total that differs from T by 1, adjust the Reason category by ±1 to match (Reason is always present and is the largest or joint-largest allocation). Do not allocate 0 slots to any applicable PRA category: if rounding would produce 0 for an applicable category, borrow 1 slot from the largest category (breaking ties in favor of Reason) so that every applicable category has at least 1 slot.

**Minimum T rule:** The confirmed target count **must be at least the number of applicable PRA categories** (e.g., T ≥ 3 for P+R+A, T ≥ 2 for P+R or R+A, T ≥ 1 for R only). If the user supplies a smaller T, treat this as an error/warning and re-prompt for a larger T that satisfies this rule.
**Examples (T = 20, P+R+A):** 8 Perceive / 8 Reason / 4 Act

**Examples (T = 18, P+R):** 9 Perceive / 9 Reason

**Examples (T = 25, R+A):** 15 Reason / 10 Act

### Within-category prioritization

For each category, allocate slots in this order:

1. **Coverage-first:** Ensure every declared grounding source (Perceive) or every declared capability (Act) is exercised by at least one eval before spending slots on edge cases.
2. **Edge cases second:** After coverage is satisfied, fill remaining slots with edge cases, adversarial prompts, and boundary conditions.
3. **Reasoning:** For Reason, prioritize one eval per distinct constraint or persona rule declared in system instructions before adding general coherence/hallucination tests.

Include declared skill starter prompts within the approved total. If sources,
callable tools, constraints or starters exceed the available slots, explain the
coverage tradeoff and ask whether to increase the count or prioritize coverage.
Never silently exceed the exact approved total.

---

## Exclusion Reporting

Report exclusions to the user only when a PRA category is omitted due to missing manifest declarations. Do not report included categories unless providing a final summary count.

**When to report:**

- Perceive excluded: "Skipping Perceive evals — no grounding sources declared in manifest."
- Act excluded: "Skipping Act evals — no capabilities or actions declared in manifest."
- Both excluded: Report each omission separately.

**When not to report:**

- Do not announce that Reason evals are included (they always are).
- Do not list all three categories and mark them included/excluded unless the user requests a summary.

**Error case — Agent without system instructions:**
If the Agent contains no system instructions, halt Agent generation and inform the user:
"Cannot generate evals — no system instructions found in manifest. System instructions are required to determine agent scope, constraints, and persona."

This error does not apply to a connector-only Plugin with sufficient verified tool
and task constraints; use Reason/Act and include Perceive only with grounding.

---

## Relationship to Eval CLI Metrics

PRA and Eval CLI metrics are orthogonal. They answer different questions:

| Dimension         | PRA Framework                             | Eval CLI Metrics                                          |
| ----------------- | ----------------------------------------- | --------------------------------------------------------- |
| Question answered | What cognitive layer is being tested?     | How well did the agent perform on this eval?              |
| Applied at        | Eval design time (scenario generation)    | Eval execution time (result scoring)                      |
| Examples          | Perceive, Reason, Act                     | Relevance, Coherence, Groundedness, Similarity, Citations |
| Scope             | Structural completeness of the eval suite | Quality of individual agent responses                     |

PRA ensures the eval suite covers the right failure modes. Eval CLI metrics score the agent's responses against those scenarios. A well-formed eval suite uses PRA to select scenarios and Eval CLI metrics to judge results.

---

## PRA → Evaluator Mapping

When generating evals, translate each PRA category into the following evaluator configuration. Apply this mapping to every prompt in the eval suite. See [eval-templates.md](eval-templates.md) for full JSON examples including the `context` field.

| PRA Category                        | Evaluators to assign                                              | `evaluators_mode`  | Notes                                                                                                                                                 |
| ----------------------------------- | ----------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Perceive**                        | `Groundedness` (threshold: 4); Agent-only `Citations`             | `extend` (default) | Raise Groundedness and provide actual source `context`. Add Citations only for Agents, never Plugins.                                                 |
| **Reason**                          | `Coherence` (threshold: 4, optional)                              | `extend` (default) | Defaults usually suffice. Only add Coherence override for structure-critical prompts. May omit `evaluators` entirely if no threshold override needed. |
| **Act**                             | Optional `Similarity`, V2 `ToolCallSelection`/`ToolCallExecution` | `extend` (default) | Use schema V2 and verified tool identities/runtime evidence; review arguments separately.                                                             |
| **Boundary** (out-of-scope refusal) | `PartialMatch`                                                    | **`replace`**      | Replace all LLM evaluators — only string match is meaningful for refusal responses.                                                                   |
| **Deterministic** (exact output)    | `ExactMatch`                                                      | **`replace`**      | Replace all LLM evaluators — only exact string match is appropriate.                                                                                  |

Plugin defaults and every item/turn override allow only Relevance, Coherence,
Groundedness, Similarity, PartialMatch, ExactMatch, ToolCallSelection and
ToolCallExecution. Tool-call checks require V2 preview/schema V2 and configured
`calls[].tool` identities; see [eval-templates.md](eval-templates.md).
Do not generate Citations, Retrieval or ToolCallAccuracy for Plugins. Check
existing datasets at all scopes and propose a separately approved adaptation rather
than silently dropping evaluators. Agent-only examples must not be copied unchanged
into Plugin suites. Skill output-format constraints are Reason scenarios;
Groundedness checks factual content, not JSON/schema syntax.

### `extend` vs `replace` mode

- **`extend`** (default when `evaluators_mode` is omitted): The prompt's `evaluators` are merged with the file's `default_evaluators`. Per-prompt evaluators can add new evaluators or override options (e.g., raise a threshold) for existing ones.
- **`replace`**: The prompt's `evaluators` completely replace the file's `default_evaluators` for that prompt. The LLM-based evaluators (Relevance, Coherence, Groundedness) do NOT run on this prompt.

Use `replace` for:

- **Boundary/refusal prompts** — LLM evaluators score refusal responses poorly even when the refusal is correct. String match is more appropriate.
- **Deterministic prompts** — when the expected output is an exact string (e.g., a specific phrase, URL, or number), LLM scoring adds noise.

Use `extend` for:

- All other prompts — Perceive, Reason, and Act prompts that add specialized evaluators on top of the defaults.

### `context` field for Perceive prompts

The `context` field supplies the actual source text to the Groundedness evaluator. It must be:

- The **actual content** from the knowledge source the agent is expected to retrieve (SharePoint page body, OneDrive document excerpt, Graph connector data payload)
- Representative of what the agent will see at runtime — not a paraphrase or summary
- Populated for **every Perceive prompt** where Groundedness is evaluated

When source content is not available at generation time:

1. Obtain actual source text through an authorized read or request a source fixture.
2. If unavailable, flag the gap in the preview. A draft may use
   `[[TO_BE_REPLACED_WITH_REAL_SOURCE_CONTEXT]]`, but it must be replaced with actual
   source text before execution. Never synthesize source evidence from a URL/topic.

Do not conflate PRA category with evaluator assignment. Groundedness is already
a file-level default; Perceive overrides its threshold to 4 with actual context.
Only Agents add Citations. Plugins never do. Omitting the override leaves
Groundedness at the default threshold, not the required Perceive threshold.
