# M365 Agent Evaluator — Workflow Reference

Detailed workflow phases for the `m365-agent-evaluator` skill. Load this file when executing any phase of the eval lifecycle.

---

## Phase 0: Project Validation

### ATK Detection

- Discover `.env.local` and `.env.dev` in the project root and `env/`. If both exist and the user did not specify `--env`, ask which environment to use.
- **Primary check**: the selected base environment contains `M365_TITLE_ID`
- **Secondary check**: `m365agents.yml` exists at project root (either condition alone is sufficient to confirm an ATK project; both absent means not an ATK project)
- If NOT an ATK project: display the following error and EXIT

> "This skill requires an M365 Agents Toolkit (ATK) project. Evals must be source-controlled alongside the agent they test. Please run this skill from within an ATK project directory."

### Judge Backend Selection

The Eval CLI (`runevals`) can score its four built-in LLM evaluators with two judge backends. wiqd **defaults `wiqd agent eval` to `github-copilot`** — it needs no Azure setup — but the choice constrains which evaluators can run. See [references/judge-backends.md](judge-backends.md) for the full, authoritative matrix; summary:

| Judge backend                     | Setup                                                                     | Evaluators it can judge                                                                                                |
| --------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `github-copilot` (wiqd's default) | `gh auth login` / `GITHUB_TOKEN`                                          | `Relevance`, `Coherence`, `Groundedness`, `Similarity` — everything except custom `.prompty` evaluators                |
| `azure` (`runevals`' own default) | Azure OpenAI deployment (see [references/azure-setup.md](azure-setup.md)) | Everything, including custom `.prompty` evaluators (which always require Azure OpenAI regardless of `--judge-backend`) |

`Citations`, `RetrievalQuery`, `RetrievalResult`, `ExactMatch`, and `PartialMatch` are deterministic/count-based — they call no judge model and run identically under either backend. **`ToolCallAccuracy` is not currently a supported evaluator** — do not generate or run it under either backend (see [references/gaps.md](gaps.md)).

**Before running evals**, read the target `evaluators`/`default_evaluators` declared in the prompts file (see [eval-templates.md](eval-templates.md)) and cross-check them against the matrix above:

- If `--judge-backend github-copilot` (or no flag, since it's wiqd's default) is selected and the file declares a custom `.prompty` evaluator, **do not run as-is**. Tell the user:

> "This dataset uses the custom evaluator `<name>`, which always requires Azure OpenAI. Rerun with `--judge-backend azure` (see references/azure-setup.md), or remove `<name>` from this dataset."

- If the file declares `ToolCallAccuracy`, tell the user it is currently unsupported and should be removed, regardless of judge backend.
- Only proceed silently when every declared evaluator is judge-model-free or is one of the four GHCP-eligible built-ins.

### Credential Check

- If `--judge-backend github-copilot` (wiqd's default): confirm the user is signed in (`gh auth login` / `GITHUB_TOKEN`). No Azure credentials are required for this path.
- If `--judge-backend azure` is selected, load [references/judge-backends.md](judge-backends.md) and select one route:
  - GPT-4.x local Azure: require `AZURE_AI_OPENAI_ENDPOINT`, `AZURE_AI_API_VERSION`, and `AZURE_AI_MODEL_NAME`; use `AZURE_AI_API_KEY` when present, otherwise `DefaultAzureCredential`; keep `AZURE_AI_PROJECT_ENDPOINT` unset.
  - GPT-5.x/o-series Foundry: require `AZURE_AI_PROJECT_ENDPOINT` and `AZURE_AI_MODEL_NAME`; use Entra authentication and do not require `AZURE_AI_API_KEY`, `AZURE_AI_OPENAI_ENDPOINT`, or `AZURE_AI_API_VERSION`.
- A custom `.prompty` evaluator requires the local Azure OpenAI configuration even if Foundry variables are present.
- If any Azure credentials are missing: offer the user a choice:
  1. Interactive setup — guided credential entry (see [references/azure-setup.md](azure-setup.md))
  2. Manual guidance — direct user to:
     - Azure OpenAI endpoint + key: [Azure Portal](https://portal.azure.com) → Azure OpenAI resource → Keys and Endpoint
     - Tenant ID: [Azure Portal](https://portal.azure.com) → Microsoft Entra ID → Overview → Tenant ID
     - Configure credentials in the selected `.env.local.user` or `.env.dev.user` override
     - See references/azure-setup.md for full setup walkthrough
- If all present (or GHCP was selected and no Azure-only evaluator is in play): continue without prompting

### Interactive Credential Setup

- Prompt for each missing credential one at a time
- Before writing each credential: verify the entered value is non-empty. If blank input is provided, reject and re-prompt once before aborting.
- Before writing: check if the value already exists in the selected `.user` file — if so, ask for confirmation before overwriting
- Write to the selected `.env.local.user` or `.env.dev.user` and confirm success
- After writing: check that the selected `.user` file is gitignored. If it is not, warn the user:

> "⚠ The selected `.env.<environment>.user` file is not gitignored. Add `.env.local.user`, `.env.dev.user`, and `env/.env.*.user` now to prevent accidentally committing credentials."

- Note: credentials are passed through to the Eval CLI / Azure AI Eval SDK — no format validation is performed

### Eval CLI Check

- Check the extension-managed CLI with `wiqd exec runevals --version`.
- wiqd installs or refreshes the exact extension pin automatically; do not install
  the Eval CLI globally.
- Change to the agent project directory and run `wiqd exec runevals --init-only`
  to complete Python environment and dependency downloads.

### Mandatory Dataset Choice

- Check if `evals/evals.json.tmp` or `evals/generated-evals.json.tmp` exists. If so, warn that a previous generation may have been interrupted and do not continue until the user confirms deletion or deletes it manually.
- Enumerate `evals/**/*.json`. Parse each candidate and retain only files with a top-level `items` array. These are the compatible existing datasets. Do not treat files under `.evals/` as datasets.
- Before validation, generation, execution, or analysis, always use `ask_user`:

> "Which dataset path should this evaluation use?
>
> 1. **Use an existing dataset**
> 2. **Generate a new dataset**"

- This is a blocking gate on every invocation. Never infer or reuse the answer from request wording, conventional filenames, previous runs, or cached session state.
- If the user selects **Use an existing dataset**:
  - If none were discovered, tell the user and use `ask_user` to request an exact path or let them choose generation instead.
  - If exactly one was discovered, select it and state its relative path.
  - If multiple were discovered, use `ask_user` to list their relative paths and require one selection.
  - Parse the selected dataset. If it is empty, invalid JSON, or lacks a top-level `items` array, warn the user and return to dataset selection. Do not offer Run or Propose Updates for an invalid dataset.
  - Use a separate `ask_user` prompt:

    > "What would you like to do with `<selected-path>`?
    >
    > 1. **Run** the selected dataset
    > 2. **Propose updates** based on the current manifest
    > 3. **Analyze previous results** from `./.evals/`"

- If the user selects **Analyze previous results**:
  - List `.json` files in `./.evals/` sorted by timestamp (newest first).
  - If multiple exist, show the 3 most recent and ask which to analyze (default: latest).
  - If none exist: "No results found in `./.evals/`. Run evals first to generate results."
  - Proceed to Results Analysis with the selected result file.
- If the user selects **Generate a new dataset**, proceed to manifest analysis and eval generation. Write to `evals/evals.json` when no compatible dataset exists; otherwise write to `evals/generated-evals.json`.

---

## Phase 1: Manifest Analysis

### Locate manifest

- Primary location: `appPackage/declarativeAgent.json`
- If multiple manifest files are found: ask the user to specify which one
- Supported formats: JSON and YAML

### Parse manifest — extract:

- Agent name, description, version
- System instructions (inline text OR external URL reference)
  - If external URL: fetch with a 10-second timeout
  - If URL unreachable: warn user and skip instruction-based evals; do not fail completely if other manifest data exists
  - If instructions are empty or missing: EXIT with error:

> "Cannot generate evals without system instructions. Please add instructions to your agent manifest."

- Declared capabilities (actions, plugins, connectors)
- Grounding sources (knowledge bases, SharePoint sites, Graph connectors)

### PRA Category Determination (see [pra-framework.md](pra-framework.md))

PRA Category Gating Rules:

- **Perceive**: Include ONLY IF manifest declares grounding sources (SharePoint, Graph connectors, knowledge bases)
- **Reason**: Include IF system instructions exist (instructions are required to generate any evals at all)
- **Act**: Include ONLY IF manifest declares capabilities or actions

- Determine which PRA categories apply based on manifest contents
- Report ONLY excluded categories (e.g., "Skipping Act evals — no actions declared")
- Do NOT report included categories unless giving a final summary

### Complexity Assessment and Eval Count Recommendation

After PRA category determination, compute the agent's complexity tier and recommended eval count. Apply tiers in priority order — use the **first matching tier**:

Count callable functions/tools inside referenced plugin files rather than only top-level action references.

| Complexity Tier | Criteria (apply first match)                   | Recommended Eval Count |
| --------------- | ---------------------------------------------- | ---------------------- |
| Complex         | 9+ callable actions                            | 20–25 evals            |
| Medium          | 4–8 actions, OR any grounding sources declared | 12–18 evals            |
| Simple          | ≤3 actions AND no grounding sources            | 8–10 evals             |

Use the midpoint of the range as the default recommendation (e.g., ~9 for Simple, ~15 for Medium, ~23 for Complex).

**Present the recommendation and ask the user before proceeding:**

> "Based on your agent's [N] callable action(s) and [M] grounding source(s), I recommend ~[X] evals ([Tier] complexity).
> Generate ~[X] or a different number?"

- Accept any valid number the user provides; use the recommendation as the default
- Do NOT silently choose a count — always ask
- After confirmation, store the agreed count as the target for Phase 2
- Do not run `wiqd agent eval init` for this path. Generate exactly the agreed number, write it only after approval, and verify the saved `items.length`.

---

## Phase 2: Starter Eval Generation

### Generate `expected_response` using LLM (see [eval-templates.md](eval-templates.md))

- For each eval scenario: prompt the LLM with manifest context (instructions + capabilities + grounding sources) to generate a realistic expected agent behavior
- Do NOT use static templates — each `expected_response` must reflect the specific agent

### Create `evals/` directory if it does not exist

### Generate evals per PRA category (capped at confirmed target count)

- Use the user-confirmed eval count (default: complexity-based recommendation; maximum: 50) as the target for this run
- Slot allocation (proportional to confirmed total, T = confirmed target):
  - Determine which PRA categories apply for the agent (P, R, A) and use the corresponding ratios:
    - All three apply (P+R+A): 40% Perceive / 40% Reason / 20% Act
    - Two apply (P+R only): 50% Perceive / 50% Reason
    - Two apply (R+A only): 60% Reason / 40% Act
    - One applies (R only): 100% Reason
  - Convert ratios to integer counts by computing `count = round(T * ratio)` for each applicable category.
  - If the sum of the rounded category counts does not equal T (rounding drift), adjust the Reason count by ±1 as a tie-break (per `pra-framework.md`) until the total matches T. Do not adjust Perceive or Act.
- Within each category: prioritize coverage of declared sources and capabilities first, then edge cases
- See [eval-templates.md](eval-templates.md) for prompt patterns per category

### Output

- If generation fails mid-batch (LLM error, timeout, or cancellation): do NOT write a partial file. Report how many evals were successfully generated (e.g., "Generated 12 of 25 Perceive evals before failure") and ask the user: "Write the partial set or abort?" Only write if the user confirms.
- Write to a temporary file first (`evals/evals.json.tmp` or `evals/generated-evals.json.tmp`), then rename to the final filename on success. This prevents a corrupt file if writing is interrupted.
- Final filename: `evals/evals.json` (new generation) or `evals/generated-evals.json` (if `evals/evals.json` already exists)
- JSON format:

```json
[{ "prompt": "...", "expected_response": "..." }]
```

- Report generation summary: total evals, count by PRA category, file location

---

## Phase 3: Advanced Eval Suggestions

After starter generation:

- Generate a list of suggested advanced eval scenarios (edge cases, adversarial prompts, multi-step reasoning, domain-specific failure modes)
- Present to user:

> "Here are X advanced eval scenarios I suggest based on your agent's capabilities. Would you like to add any to your evals file?"

- User selects which to add, or declines all
- Add selected evals to the output file

---

## Phase 4: Run Existing Evals

When the user chooses to run evals:

### Credential Loading

The Eval CLI loads dotenv files natively. Select `.env.local` or `.env.dev` from the project root or `env/`; credentials belong in the matching `.env.local.user` or `.env.dev.user` file in the same supported locations. If both base environments exist and `--env` was not supplied, ask the user which one to use.

Store Azure OpenAI credentials in the selected `.user` file:

```
AZURE_AI_OPENAI_ENDPOINT=https://your-endpoint.openai.azure.com
AZURE_AI_API_KEY=your-key-here
TENANT_ID=your-tenant-id-here
AZURE_AI_API_VERSION=2024-12-01-preview
AZURE_AI_MODEL_NAME=gpt-4o
```

### Running Evals

> ⚠️ **CRITICAL: Always use absolute paths for `--prompts-file` and `--output`.** The `runevals` CLI spawns a Python subprocess that may resolve paths from a different working directory. Relative paths will fail with `[Errno 2] No such file or directory`.

- Prefer `wiqd agent eval` (wraps the same invocation, defaults `--judge-backend github-copilot` and `--eval-log-level debug`, and resolves paths automatically). Pass `--judge-backend azure` only when the dataset needs it (see Judge Backend Selection above).
- For the agentic skill path, always request a new timestamped HTML output and preserve a timestamped debug log:

  ```powershell
  $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ss")
  $scorecard = ".evals\scorecard-$timestamp.html"
  $log = ".evals\runevals-$timestamp.debug.log"
  New-Item -ItemType Directory -Force -Path ".evals" | Out-Null

  Write-Output "Command preview: wiqd agent eval --judge-backend github-copilot --eval-log-level debug --output `"$scorecard`""
  wiqd agent eval --skill wiqd --workflow eval `
    --judge-backend github-copilot `
    --eval-log-level debug `
    --output $scorecard 2>&1 |
    Tee-Object -FilePath $log

  $exitCode = $LASTEXITCODE
  Write-Output "wiqd agent eval exit code: $exitCode"
  ```

- Pass `--env local` or `--env dev` whenever environment discovery selected a base environment. Add `--path`, `--config`, or `--agent-id` when discovery does not resolve the intended workspace, dataset, or deployed agent.
- Show the resolved tenant ID, deployed agent ID, scorecard path, debug-log path, and full command preview before execution. Never show any other environment values.
- When running the managed Eval CLI manually:
- Create `./.evals/` directory if it doesn't exist
- Invoke with timestamped output, always passing `--judge-backend` and runevals `--log-level debug` explicitly so failures carry enough detail to diagnose without re-running:
  ```bash
  # Bash (macOS/Linux):
  TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%S)
  mkdir -p .evals
  wiqd exec runevals --judge-backend github-copilot --log-level debug --prompts-file "$(realpath evals/evals.json)" --output "$(pwd)/.evals/scorecard-${TIMESTAMP}.html"
  ```
  ```powershell
  # PowerShell (Windows):
  $TIMESTAMP = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ss")
  New-Item -ItemType Directory -Force -Path ".evals" | Out-Null
  wiqd exec runevals --judge-backend github-copilot --log-level debug --prompts-file ([System.IO.Path]::GetFullPath("evals/evals.json")) --output ([System.IO.Path]::GetFullPath(".evals\scorecard-$TIMESTAMP.html"))
  ```
- HTML is the default skill output because it is the scorecard used for both human review and post-run analysis. Use JSON only when the user explicitly requests it.
- Forward only the selected route's variables: local GPT-4.x uses `AZURE_AI_OPENAI_ENDPOINT`, `AZURE_AI_API_VERSION`, `AZURE_AI_MODEL_NAME`, and optional `AZURE_AI_API_KEY`; Foundry GPT-5.x/o-series uses `AZURE_AI_PROJECT_ENDPOINT`, `AZURE_AI_MODEL_NAME`, and optional `AZURE_TENANT_ID`. Both retain `TENANT_ID` for the M365 agent connection.
- On success: report output file locations and a brief result summary
- On failure: display the error message and suggest remediation:
  - Connection error: check `AZURE_AI_OPENAI_ENDPOINT`
  - Auth error (azure): check `AZURE_AI_API_KEY`; auth error (github-copilot): run `gh auth login` (or set `GITHUB_TOKEN`)
  - Custom `.prompty` evaluator error under GHCP: rerun with `--judge-backend azure` or drop that evaluator
  - Missing evals file: check that `evals/evals.json` exists

---

## Phase 5: Result Analysis

After evals run (see [result-analysis.md](result-analysis.md)):

### Results Storage

- **Path:** `./.evals/scorecard-<timestamp>.html`
- **Convention:** Timestamped filenames preserve run history for trend analysis
- **Gitignore:** Ensure `.evals/` is in `.gitignore` — results are local/ephemeral, not source-controlled
- **Latest results:** When analyzing, default to the scorecard produced by the current run, otherwise the most recent `.html` file in `./.evals/`

### Analyzing Results

- Parse the selected HTML scorecard from `./.evals/`
- Read the summary metrics, item results, evaluator names, thresholds, scores, pass/fail status, and displayed explanations
- Analyze only evaluator keys present in the scorecard; absence means the evaluator was not configured
- Correlate failures with available instructions, manifest capabilities, knowledge-source configuration, actions/plugins, and the eval definition
- Treat report contents as potentially sensitive: summarize sanitized evidence and do not reproduce raw prompts, responses, retrieved content, or evaluator explanations
- Classification uses the LOWEST scoring metric across all metrics:
  - **Pass**: All metrics ≥ 4.0
  - **Needs Improvement**: Lowest metric is 2.5–3.9 (no metric below 2.5)
  - **Fail**: Any metric < 2.5 (lowest metric governs — a single failing metric means the eval fails)

**Scoring metrics from Eval CLI**

| Metric              | Scale                | Judge backend                                      |
| ------------------- | -------------------- | -------------------------------------------------- |
| Relevance           | 1–5                  | `github-copilot` or `azure`                        |
| Coherence           | 1–5                  | `github-copilot` or `azure`                        |
| Groundedness        | 1–5                  | `github-copilot` or `azure`                        |
| Similarity          | 1–5                  | `github-copilot` or `azure`                        |
| Citations           | ≥ 0                  | deterministic (count-based) — no judge model       |
| RetrievalQuery      | pass/fail            | deterministic — no judge model                     |
| RetrievalResult     | pass/fail            | deterministic — no judge model                     |
| ExactMatch          | boolean              | deterministic — no judge model                     |
| PartialMatch        | 0.0–1.0              | deterministic — no judge model                     |
| Custom (`.prompty`) | depends on evaluator | `azure` only — not routed through `github-copilot` |

> `ToolCallAccuracy` is not currently a supported evaluator — see [references/gaps.md](gaps.md). Do not include it in generated eval documents or in the tables above.

**Root cause categorization**

| Category          | When to assign                                                                                                                         |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Instruction Issue | Low Relevance, Coherence, or Groundedness                                                                                              |
| Tool/Action Issue | Agent behavior indicates wrong tool/parameters (verify manually — `ToolCallAccuracy` is currently unsupported, see [gaps.md](gaps.md)) |
| Grounding Issue   | Low Groundedness despite correct instructions                                                                                          |
| Citation Issue    | Low Citations score                                                                                                                    |
| Eval Issue        | Agent behavior seems correct but eval fails (see bad eval detection)                                                                   |
| Capability Gap    | Agent unable to perform expected action                                                                                                |

**Bad eval detection heuristics** — flag for human review (do NOT auto-fix):

- Agent response contains "I can only..." / "I don't have information about..." / "My scope is limited to..." — prompt may be out of scope
- Agent response contains "I cannot perform..." / "You'll need to..." — eval expected an unavailable action
- 3 or more evals with similar prompt patterns all fail — systematic scope mismatch
- Agent quotes its own constraints — eval violates declared limitations

**Pattern identification**

- Group failures by root cause
- Correlate low Groundedness: is it an instruction gap (agent not told to use sources) OR a grounding issue (sources missing or inaccessible)?
- For Act-category prompts, since `ToolCallAccuracy` is currently unsupported, use `ExactMatch`/`PartialMatch` against an `expected_response` that states the expected action, or manual review of the agent's transcript, to spot wrong tool/parameters/missed calls.

---

## Phase 6: Remediation Recommendations

Structure recommendations as actionable tasks (see [remediation-patterns.md](remediation-patterns.md)). For each major issue, provide both score evidence and artifact evidence:

```
Primary issue: <one-sentence failure theme>
Evidence: <sanitized score or aggregate observation>
Correlated gap: <instructions, tool, knowledge source, manifest, eval, or setup>
Artifact evidence: <file path and field/section, or "not available">
Recommended change: <specific targeted change>
Expected effect: <evaluator expected to improve and why>
```

Prioritize by: (1) number of failing evals addressed, (2) effort — instruction changes are lower effort than grounding config changes, which are lower effort than adding new capabilities.

For each recommendation type:

- **Instruction issue**: specify the instruction file path and suggest specific text changes or additions
- **Grounding issue**: identify the problematic source and suggest config or data fixes
- **Eval issue**: identify the eval by index and prompt, then suggest a corrected `expected_response`
- **Capability gap**: suggest adding the capability to the manifest OR removing the eval

Always finish with:

```markdown
[Open evaluation scorecard](file:///C:/absolute/path/to/.evals/scorecard-<timestamp>.html)
```

---

## Phase 7: Eval Iteration

When the user requests "propose updates to my evals":

- Compare the current manifest to existing `evals/evals.json`
- Identify: new capabilities needing new evals, removed capabilities with orphaned evals, instruction changes requiring eval updates
- Present as a diff-style proposal:
  - `+ ADD`: new evals for new capabilities or instructions
  - `- REMOVE`: evals for removed capabilities
  - `~ UPDATE`: evals where `expected_response` needs updating
- Ask for user approval BEFORE modifying `evals/evals.json`
- Apply only approved changes
