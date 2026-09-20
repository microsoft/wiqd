# Remediation Patterns Reference

This reference covers remediation strategies and templates for each root cause category identified during eval result analysis.

---

## 1. Recommendation Structure

Every recommendation must follow this format exactly. Vague recommendations are not actionable — each field must be concrete and specific.

```
### [Priority N] Fix [description] — [Root Cause Category]
**Target file**: [exact file path]
**Change type**: add | modify | remove
**Change**: [specific text addition/modification — concrete, not vague]
**Rationale**: [which evals fail and why, linked to root cause]
**Impacted evals**: [list of eval indices or prompt summaries]
**Effort**: low | medium | high
```

**Example:**

```
### Priority 1 Fix grounding source for Benefits queries — Grounding Issue
**Target file**: appPackage/declarativeAgent.json
**Change type**: add
**Change**: Add "https://contoso.sharepoint.com/sites/Benefits" to the OneDriveAndSharePoint capability's siteUrls array
**Rationale**: Evals 2, 5, and 8 all ask about benefits policies and receive hallucinated data. The Benefits SharePoint site is not listed in capabilities.
**Impacted evals**: [2, 5, 8]
**Effort**: medium
```

---

## 2. Prioritization Logic

Order recommendations by impact-to-effort ratio. Use this formula to rank:

**Score = (number of failing evals addressed) / (effort weight)**

Effort weights:

| Effort Level | Weight | Applies to                                   |
| ------------ | ------ | -------------------------------------------- |
| low          | 1      | Instruction changes, eval fixes              |
| medium       | 2      | Grounding configuration changes              |
| high         | 3      | Capability additions, new action definitions |

Higher score = higher priority. When scores are tied, prefer the recommendation that addresses a broader failure pattern (e.g., a fix that resolves failures across multiple eval categories over one that fixes a single category).

---

## 3. Remediation by Category

### Instruction Issue

**Signals:** Low Relevance, Coherence, or Groundedness where grounding sources exist but are not used, or where response does not follow expected behavioral patterns.

**Target file:** System instructions — typically the `instructions` field in `appPackage/declarativeAgent.json`, or the referenced `.txt` or `.md` instructions file if instructions are stored externally.

**Change patterns:**

- Add missing behavioral constraints: "Always respond in the user's language"
- Add source-usage directives: "When answering questions about [topic], always consult your knowledge base before responding"
- Add formatting requirements: "Structure responses as a numbered list when presenting multiple options"
- Clarify scope boundaries: "Only answer questions related to [declared domain]. For other topics, direct users to [resource]"

**Template:**

```
Add to instructions: '[specific instruction text that directly addresses the gap identified in failing evals]'
```

Do not use vague additions like "improve clarity." Write the exact text to add.

---

### Tool/Action Issue

**Signals:** Manual transcript review (or low `Similarity`/`Relevance` against a precise `expected_response`) shows the agent called the wrong tool, called the correct tool with wrong or missing parameters, or failed to call a tool when the prompt required one. `ToolCallAccuracy` is not currently a supported evaluator — see [gaps.md](gaps.md) — so this category cannot be detected from a score alone.

**Target file:** `appPackage/ai-plugin.json` or the action definition file referenced by it.

**Checks to perform before recommending a fix:**

1. Does the function name clearly communicate what the action does? Agents infer intent from descriptions.
2. Do parameter names reflect their purpose? Ambiguous names (e.g., `id` vs `userId`) cause wrong-parameter errors.
3. Are parameter descriptions specific enough to disambiguate from similar parameters?
4. Are required parameters marked as `required` in the schema?
5. Is the overall action description specific enough that the agent selects it over similar actions?

**Change patterns:**

- Rename ambiguous parameters to be self-describing
- Improve action description to be more specific about when to invoke it
- Fix required parameter declarations (add missing `required` array entries)
- Add parameter descriptions that clarify expected format or content

---

### Grounding Issue

**Signals:** Low Groundedness where instructions correctly direct the agent to use sources, but the agent returns hallucinated or incorrect data.

**Target file:** `appPackage/declarativeAgent.json` capabilities section (groundingSources or OneDriveAndSharePoint capability).

**Change patterns:**

- Add missing SharePoint site URL to the `siteUrls` array in the OneDriveAndSharePoint capability
- Add a Graph connector reference if data lives in a non-SharePoint system
- Verify SharePoint site permissions — the agent's service account must have read access
- Verify the source is indexed — new SharePoint sites may not be indexed by Microsoft Search yet

**Additional checks:**

- Confirm the data actually exists in the source (not just that the source is declared)
- Confirm the source contains content relevant to the failing eval prompts
- If the source is a Graph connector, confirm the connector is active and returning results

---

### Citation Issue

**Signals:** Low Citations where Groundedness is acceptable — the agent retrieved correct information but did not attribute it to a source.

**Target file:** System instructions (`appPackage/declarativeAgent.json` instructions field or referenced file).

**Change:**

Add an explicit citation requirement to instructions. Example text:

```
Always cite the source document when providing information from your knowledge base. Include the document title and a link if available.
```

Place this instruction near the section that describes how the agent should respond to information-retrieval prompts.

---

### Eval Issue

**Signals:** One or more of the bad eval heuristics triggered (scope clarification pattern, capability disclaimer, consistent category failures, instruction echo), or the actual_response appears correct but scores poorly against expected_response.

**Target file:** `evals/evals.json`

**Change:** Update `expected_response` at the flagged index to reflect what a correctly functioning agent actually produces.

**Process — do NOT auto-fix:**

1. Present the flagged eval to the user with the specific heuristic that triggered
2. Show the current `expected_response` and the `actual_response` side by side
3. Propose a revised `expected_response` but wait for user confirmation before recommending the edit

**Template for presenting to user:**

```
Eval [N] prompt: '[prompt text]'
Current expected_response expects: [summary of what expected_response requires]
Agent actual_response: [summary of what agent actually said]
Issue: [which heuristic triggered and why this suggests an eval problem]
Suggested fix: Update expected_response to '[revised expectation that matches correct agent behavior]'
Awaiting your confirmation before including this as an implementation task.
```

---

### Capability Gap

**Signals:** The agent is unable to perform an action because the required capability is not declared in the manifest. Typically appears as a mismatch found during manual transcript review, combined with capability disclaimer language in the actual_response.

**Target file:** Either `appPackage/declarativeAgent.json` capabilities section, or `evals/evals.json`.

**Two options — present both to the user:**

**Option A — Add the capability:**
Add the missing capability to the `capabilities` array in `appPackage/declarativeAgent.json`. Specify the exact capability type and any required configuration (e.g., connector ID, site URL, action name).

**Option B — Remove the eval:**
If the capability is intentionally absent from the agent's design, the eval is testing out-of-scope behavior. Remove or update the eval at the relevant index in `evals/evals.json`.

Do not select between options automatically. Present both with their tradeoffs and wait for user direction.

---

## 4. Coding-Agent Output Format

After completing analysis and generating recommendations, format all actionable items as a structured task list. This format is designed to be directly consumed by a coding agent.

```markdown
## Implementation Tasks

- [ ] Fix grounding source: Add https://contoso.sharepoint.com/sites/Benefits to OneDriveAndSharePoint capability siteUrls in appPackage/declarativeAgent.json
- [ ] Fix instruction: Add "Always cite source documents when providing information from your knowledge base" to agent instructions in appPackage/declarativeAgent.json
- [ ] Fix action parameter: Rename parameter `id` to `userId` in the getUserProfile action in appPackage/ai-plugin.json
- [ ] Fix eval: Update expected_response for eval index 7 in evals/evals.json — pending user confirmation
```

**Rules for this section:**

- Each task is one discrete change to one file
- Tasks are ordered by priority (highest priority first)
- Eval fixes that require user confirmation are listed last and marked as pending
- Do not combine multiple file changes into a single task
- Use exact file paths, not generic descriptions
