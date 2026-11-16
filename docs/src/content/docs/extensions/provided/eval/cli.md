---
title: Eval · CLI commands
description: Every command contributed by Work IQ Dev Tools' Eval extension
---

# Eval · CLI commands

The Eval extension evaluates deployed Agents and installed M365 Copilot Plugins:

| Command                                                                          | What it does                                                  |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [`wiqd agent eval`](/cli/reference/#wiqd-agent-eval)                  | Run quality evaluations against a deployed declarative agent  |
| [`wiqd agent eval init`](/cli/reference/#wiqd-agent-eval-init)        | Scaffold a starter `evals/prompts.json` for the agent         |
| `wiqd plugin eval` | Evaluate Plugin skills/connectors through Copilot mainline |

`wiqd agent eval init` requires an ATK project and emits a fixed seven-item bootstrap for the default ATK declarative-agent template. It is not the manifest-aware generator and has no prompt-count option. When the wiqd eval skill recommends or the user selects a count, the skill writes and verifies exactly that many generated items without substituting `eval init`.

Newly scaffolded projects may already contain `evals/prompts.json`. In that case, `wiqd agent eval init` validates and preserves the existing eval document, reports that evaluations are already initialized, and still merges available evaluator settings into `env/.env.<env>.user`. Supported legacy prompt arrays are also preserved. Empty, malformed, or schema-invalid prompts files are never overwritten, and output paths that resolve outside the project through a symlink or junction are rejected before either project file is changed.

`wiqd agent eval` does **not** require `m365agents.yml` or a provisioned ATK project. It needs only (1) a prompts file and (2) a resolvable agent title ID — sourced from `env/.env.<env>` (`M365_TITLE_ID`) or from `--agent-id`.

## Running against an evals-only folder

You can run `wiqd agent eval` from a folder that holds only `evals/prompts.json` plus `env/.env.<env>` carrying `M365_TITLE_ID` — no `m365agents.yml` required. The title ID is read from the env file automatically, so no `--agent-id` is needed:

```bash
wiqd agent eval --path <folder> --env dev
```

## Evaluating a deployed agent directly

Pass `--agent-id <id>` to run evals against an already-deployed agent from any folder that holds only a prompts file — no `m365agents.yml` or `env/.env.<env>` required:

```bash
wiqd agent eval --path <folder> --agent-id <id> -c prompts.json --env dev
```

When `--agent-id` is set, the title ID is sourced from the option rather than from `env/.env.<env>`.

### Options

| Flag             | Type     | Default              | Description                                                                                                        |
| ---------------- | -------- | -------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `--path`         | `string` | `.`                  | Path to project or prompts folder (defaults to CWD)                                                                |
| `--env`          | `string` | `local`              | Target environment (project mode only)                                                                             |
| `--config`, `-c` | `string` | `evals/prompts.json` | Path to eval prompts file                                                                                          |
| `--output`, `-o` | `string` | `.evals/results.json` | Result file path relative to `--path`. Use a timestamped `.html` path for a human-readable scorecard.              |
| `--agent-id`     | `string` | _(none)_             | Title ID of a deployed agent to evaluate directly (e.g. `T_xxx`). When set, sources the title ID from this option instead of `env/.env.<env>`. |
| `--account`      | `string` | _(none)_             | Optional email/UPN used by the Eval CLI to select a cached MSAL account or prefill interactive sign-in.           |
| `--judge-backend` | `string` | `github-copilot`    | LLM judge backend for `Relevance`/`Coherence`/`Groundedness`/`Similarity`: `github-copilot` (`gh auth login --hostname github.com` for GitHub.com, or `GITHUB_TOKEN`) or `azure` (Azure OpenAI). Custom `.prompty` evaluators always need `azure`. |
| `--eval-log-level` | `string` | `debug` | Verbosity forwarded as runevals `--log-level`, distinct from wiqd global logging |
| `--concurrency`  | `int`    | Eval CLI default     | Optional concurrent scenario override (1-5)                                                                        |
| `--threshold`    | `float`  | _(none)_             | Minimum pass-rate (0-1) to succeed. Exit 1 if score falls below this.                                              |

## Scorecard workflow

The wiqd eval skill runs with the GitHub Copilot judge and requests a new timestamped HTML scorecard:

```powershell
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ss")
wiqd agent eval --env dev --judge-backend github-copilot --eval-log-level debug `
  --output ".evals\scorecard-$timestamp.html"
```

The skill does not override concurrency. When the user supplies `--concurrency`, wiqd forwards it; otherwise wiqd omits the flag and lets the Eval CLI choose its default (currently **5**).

## Authentication boundaries

`wiqd agent eval` does not reuse the Microsoft 365 session created by `wiqd auth login`. The Eval CLI authenticates the deployed-agent connection itself using the selected tenant ID, its encrypted MSAL cache under `~/.m365-copilot-agent-evals/`, and the platform broker when interactive authentication is required. Tenant admin approval for the WORKIQ client app is required. Use `--account` to select the intended cached identity when multiple accounts are available.

Judge authentication is separate: GitHub Copilot uses GitHub authentication, while Azure/Foundry uses the configured Azure credential. EULA acceptance is a third, independent prerequisite. wiqd detects a missing or stale Eval CLI EULA marker and blocks for explicit human consent before authentication begins.

After the run, the skill opens the scorecard data, correlates failures with the agent's instructions, tools, knowledge sources, and manifest, and returns targeted recommendations plus a `file:///` link to the scorecard.

## Evaluation workflow

The wiqd eval skill owns the complete improvement loop:

1. Resolve Agent versus Plugin from explicit intent or root manifest registrations; ask if unclear.
2. Discover eval documents and ask existing versus new dataset, then analyze the selected definition.
3. Generate a PRA-balanced eval document when needed.
4. Run the current suite to a timestamped HTML scorecard.
5. Interpret every configured evaluator and classify root causes.
6. Recommend the smallest justified change to the eval suite, instructions, capabilities, knowledge sources, or action definitions.
7. Re-run the unchanged suite after agent improvements for an apples-to-apples comparison.

The suite is the behavioral specification. The skill will not remove evaluators, lower thresholds, or delete difficult scenarios merely to improve the pass rate.

## Find an Agent or Plugin title ID

Open [copilot.microsoft.com](https://copilot.microsoft.com), select **Plugins** or
**Agents** in the left rail, find your Plugin or Agent, and select **Share**.
Copy the `T_...` title ID at the end of the share URL (for example, `T_1234`),
not the entire URL.

For Agent execution, use it as `--agent-id` or `M365_TITLE_ID`. For Plugin
tool-call expectations, use the Plugin's title ID as `calls[].tool.plugin_id`;
it does not select the execution target. Never set `M365_AGENT_ID` or `AGENT_ID`
for a Plugin run.

## Plugin evaluations (v2 preview)

`wiqd plugin eval` uses the separate `plugin-eval` workflow and defaults to
`evals/plugin-evals.json`. It forwards
`runevals --target m365-copilot --prompts-file <absolute-path>` without an Agent ID
or component. Copilot mainline selects installed Plugin skills/connectors; this
command does not install or isolate a Plugin, and scores alone do not prove attribution.

This requires published **Evals CLI V2 preview (`>=2.0.0-preview1`)**.
The skill automatically resolves npm's `preview` tag to an exact
`2.x >=2.0.0-preview1` by SemVer precedence and upgrades older CLIs without a V1/V2 choice
or upgrade prompt. It does not use the unqualified npm `latest` tag (currently
V1), install a future major, reinstall the same version or downgrade a newer
compatible V2. Prereleases remain Preview.

The stable managed pin stays unchanged. The skill
installs the exact release in a separate user-local version directory and uses
its validated absolute `M365_COPILOT_EVAL_PATH` override for every command,
without changing global PATH or shell profiles. The command still checks
`--help` for target support before execution. If registry lookup or upgrade fails,
it reports that the latest V2 could not be ensured; a verified compatible installed
V2 may continue with that limitation disclosed, but V1 is not a fallback.
Automatic CLI setup does not bypass EULA consent, authentication, tool consent,
or dataset migration/write approvals.

```powershell
wiqd plugin eval --path <plugin-workspace> --config evals/plugin-evals.json `
  --judge-backend github-copilot --eval-log-level debug
```

Plugin options match the Agent options above except `--agent-id` is absent and
`--config` defaults to `evals/plugin-evals.json`. No `M365_TITLE_ID` or
`m365agents.yml` is required. Because upstream infers Agent execution from
`M365_AGENT_ID`/`AGENT_ID`, the command rejects these values when inherited in its
environment, and rejects `--path` that differs from the current directory because
`runevals` loads environment files from the working directory.

Generation reads root `agentSkills[]`, registered `SKILL.md` frontmatter/body and
references, instructions and grounding, and `agentConnectors[]` API/MCP tool
definitions. A connector-only Plugin can generate scenarios from verified tool
descriptions/input constraints without instructions. MCP URLs alone are not tool
inventory. Mixed packages require an explicit evaluation target.

Plugin evaluators are limited to **Relevance, Coherence, Similarity, Groundedness,
PartialMatch, ExactMatch, ToolCallSelection and ToolCallExecution** at every scope,
including multi-turn overrides. Tool-call checks require **V2 and schema V2**.
**Citations and Retrieval evaluators remain unsupported for Plugins.** Perceive uses
actual source `context` and Groundedness threshold 4. For new Plugin datasets,
use Groundedness or Similarity with a specific reference `expected_response`
instead of Citations/Retrieval. Do not invent missing source/reference content.
These alternatives assess response quality, not citation correctness, retrieval
queries/results or ranking; the generation preview discloses that limitation.
Format constraints
become Reason scenarios; Groundedness does not validate syntax. Refusal and
deterministic scenarios replace defaults with literal PartialMatch/ExactMatch
expectations. Compatibility changes to an existing suite require approval, not
silent evaluator removal.

For either target, recommend the first matching band: 9+ callable tools/actions
means 20-25 items; 4-8 or any grounding means 12-18; at most 3 without grounding
means 8-10. Approve an exact total before generation, include skill starter prompts
inside it, and allocate P/R/A 40/40/20, P/R 50/50, R/A 60/40, or all Reason.
Cover sources/tools/constraints before edge cases. Preview prompts, expectations,
evaluators and gaps, obtain separate write approval, then save atomically and
validate the schema and exact count. Never run placeholder grounding context.

To reduce judge throttling, manifest-aware generation recommends 8–10 items for simple agents, 12–18 for medium agents, and 20–25 for complex agents. Users can choose a different count; the selected count is verified after the file is written.

## Eval document schema

The Eval CLI consumes an eval document with `schemaVersion`, optional metadata, `default_evaluators`, and an `items` array:

```json
{
  "schemaVersion": "1.6.0",
  "default_evaluators": {
    "Relevance": {},
    "Coherence": {},
    "Groundedness": {}
  },
  "items": [
    {
      "prompt": "A realistic user request",
      "expected_response": "The required behavior"
    }
  ]
}
```

Evaluator names are case-sensitive. Per-item evaluator overrides supplement or replace defaults according to the Eval CLI schema.

### Tool-call datasets (V2 preview)

For Agents and Plugins with callable MCP, connector or API plugin tools, WIQD
generation must include **both ToolCallSelection and ToolCallExecution** on each
item/turn expecting successful tool use, with threshold `1.0` and verified expected
calls. This is checked before dataset preview/write; missing identities block
affected cases rather than silently producing response-only coverage. Cover each
verified tool within the approved count, or explicitly agree a count/coverage
tradeoff. Positive calls are not required for clarification, refusal, no-tool or
expected-failure cases; retrieval-only connectors do not imply callable tools.

Use `schemaVersion: "2.0.0"` and validate against the selected CLI's
`schema/v2/eval-document.schema.json`; the bundled V1 bootstrap schema is not
a V2 validator. Both deterministic evaluators work with either judge backend
for Agents and Plugins:

| Evaluator | Checks | Does not prove |
| --------- | ------ | -------------- |
| `ToolCallSelection` | Expected tool identities were selected; optional `allow_additional_calls: false` rejects extras | Execution success, arguments, order or call count |
| `ToolCallExecution` | A distinct matching HTTP 200-299 execution per expected call; repeat identities for multiplicity | Correct arguments, sequencing or business outcome |

Configure nonempty `calls` arrays with `calls[].tool.plugin_id` (deployed package
Title ID), `toolset_id` (Agent action ID or Plugin connector ID), and
`function_name`. All three fields are case-sensitive; use verified identities,
not illustrative IDs or consent strings. Use `--list-tools <agent-id>` for Agents; standalone Plugin discovery requires
returned Developer Info, registered connector IDs and the deployed Title ID,
not an ID-less `--list-tools` call. Inspect `diagnostics.tool_calls` from
authorized runs where available. Missing identity or runtime
evidence is an explicit coverage gap/error, never a passing score.

`allowed_tools` and `default_allowed_tools` grant confirmation consent separately
from evaluator expectations. Obtain explicit approval before adding them;
expectations do not authorize or force invocation. A tool without confirmation
is not controlled by this list. Consent can persist across runs and grouped
actions; do not generate side-effecting scenarios without approval.

For selection/execution examples, identity discovery, telemetry semantics and
consent identifiers, follow the
[tool-call evaluator guide](https://github.com/microsoft/M365-Copilot-Agent-Evals/blob/main/docs/tool-call-evaluators.md).
CLI V2 and schema V2 are separate lifecycles: when schema V2 is active,
all datasets need migration, even without tool-call evaluators. Earlier
execution-only previews can still use their supported V1 response-quality schema.
Migrations require approval; changing the version alone cannot recover missing
tool identities. See the
[V2 upgrade guide](https://github.com/microsoft/M365-Copilot-Agent-Evals/blob/main/docs/upgrade-to-v2.md).
Retain response-quality evaluators as separate answer-quality checks.

## Perceive-Reason-Act (PRA) framework

Generated suites use PRA to cover the agent's declared behavior:

| Category | What it validates | Included when |
| -------- | ----------------- | ------------- |
| Perceive | Grounding; Agent-only citations | Actual grounding sources are declared |
| Reason | Instructions, skill constraints, synthesis, boundaries, output quality | Instructions or verified connector task/input constraints exist |
| Act | Correct action selection and parameter behavior | The manifest declares actions or plugins |

Generation analyzes the manifest first, then allocates scenarios only to applicable categories. It never invents an action or knowledge source that the agent does not declare.

## Judge onboarding

wiqd manages the exact stable Eval CLI pin required by this extension. The first
`wiqd agent eval` or `wiqd exec runevals` command provisions it under
`~/.wiqd/extensions/microsoft.eval/`; do not install a separate global copy. To
inspect the resolved CLI directly, use `wiqd exec runevals`. Complete the
automatic latest-V2 setup above before initialization, preserve the resolved override
for every command, then change to the agent project directory and initialize:

```bash
cd /path/to/your-agent-project
wiqd exec runevals --version
wiqd exec runevals --init-only
```

For a **no-install walkthrough**, do not execute those commands: even `--version`
can lazily install or refresh packages, and `--init-only` downloads dependencies.
Use `wiqd ext show microsoft.eval --json` for a filesystem-only inspection.
`data.upstream.requiredVersion` is the supported range, not the installed version.
If `available` is true, locate the active generation's
`node_modules/@microsoft/m365-copilot-eval/package.json` from `resolvedPath` and
read only its `name` and `version`, without executing the binary. The extension's
`data.packagePath` contains `package.json` with the exact desired
pin (currently 1.15.0 or newer); neither that pin nor the extension's version
proves the CLI is installed. If metadata is unavailable, report the installed
version as unverified. Defer installation, initialization, authentication, and
EULA acceptance until separately authorized; do not print credential values.
After a consented refresh, an older supported retained generation remains usable
if the refresh fails; do not block solely because it is not the latest pin.

Choose a judge based on the suite:

| Judge | Best for | Setup |
| ----- | -------- | ----- |
| GitHub Copilot | Default, zero-Azure setup for built-in evaluators | `gh auth login --hostname github.com` for GitHub.com, or `GITHUB_TOKEN` |
| Azure | Custom `.prompty` evaluators or your own Azure deployment | Azure OpenAI/Foundry endpoint, model, tenant, and authentication |

For GitHub.com-backed Copilot judge authentication, verify an existing session with `gh auth status --hostname github.com`; run `gh auth login --hostname github.com` only in an interactive user session. Specifying the hostname makes the login target explicit and limits the status check to GitHub.com rather than all configured enterprise hosts. A successful status check confirms GitHub authentication, not Copilot entitlement or access to a particular judge model.

The skill validates evaluator/backend compatibility before execution and never prints credential values. It does not block a GitHub Copilot run when Azure variables are absent.

### GPT-4.x and GPT-5.x judge configuration

| Route | Backend | Environment variables | Authentication |
| ----- | ------- | --------------------- | -------------- |
| GitHub Copilot | `github-copilot` | Optional `GITHUB_COPILOT_JUDGE_MODEL`; unset means `auto` | GitHub CLI session or `GITHUB_TOKEN` |
| GPT-4.x local Azure OpenAI | `azure` | `AZURE_AI_OPENAI_ENDPOINT`, `AZURE_AI_API_VERSION`, `AZURE_AI_MODEL_NAME`; leave `AZURE_AI_PROJECT_ENDPOINT` unset | `AZURE_AI_API_KEY`, or `DefaultAzureCredential` when the key is absent |
| GPT-5.x/o-series Microsoft Foundry | `azure` | `AZURE_AI_PROJECT_ENDPOINT`, `AZURE_AI_MODEL_NAME` | Entra `DefaultAzureCredential`; no API key |

`TENANT_ID` is still required for the M365 agent connection on every route. If an Azure credential must select a different tenant, set `AZURE_TENANT_ID`.

With GitHub Copilot, GPT-4.x and GPT-5.x use the same setup. Pin an exact model ID available to your account, or leave the variable unset for automatic selection:

```powershell
# GPT-4.x through GitHub Copilot
$env:GITHUB_COPILOT_JUDGE_MODEL = "gpt-4.1"
wiqd agent eval --env dev --judge-backend github-copilot

# GPT-5.x through GitHub Copilot, when available to the account
$env:GITHUB_COPILOT_JUDGE_MODEL = "gpt-5-mini"
wiqd agent eval --env dev --judge-backend github-copilot
```

If the account cannot access a pinned model, the Eval CLI fails fast and lists the available models.

GPT-5.x/o-series models cannot use the local evaluator path because their Responses API rejects the `response_format` parameter used by the local SDK evaluators. Foundry routing is used only with `--judge-backend azure`, including when the user explicitly requests Azure LLMs as judge. With `--judge-backend github-copilot`, the Copilot SDK judge takes precedence and Foundry routing is not activated even when Foundry variables are present.

### Environment selection

The skill detects `.env.local` and `.env.dev` in either the project root or `env/`, then uses the matching `.env.local.user` or `.env.dev.user` file for credentials. If both base environments exist and `--env` was not supplied, it asks which environment to use before running. Credential values are never displayed.

```dotenv
# GPT-4.x with local Azure OpenAI
TENANT_ID=<m365-tenant>
AZURE_AI_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/
AZURE_AI_API_VERSION=2024-12-01-preview
AZURE_AI_MODEL_NAME=gpt-4o
AZURE_AI_API_KEY=<optional-key>

# GPT-5.x/o-series with Microsoft Foundry
TENANT_ID=<m365-tenant>
AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>
AZURE_AI_MODEL_NAME=gpt-5-mini
```

GPT-4.x can also run through Foundry, but Microsoft has deprecated GPT-4.x/GPT-4o judge models there. Prefer the local Azure route for an existing GPT-4.x deployment and plan migration to GPT-5.x through Foundry.

## Result interpretation

The scorecard must be read evaluator-by-evaluator. Missing evaluator keys mean the evaluator was not configured for that item; they are not failures. Empty or null values from a configured evaluator are reported separately as evaluator or runner failures rather than silently converted into agent-quality failures.

Root causes are classified as instruction, grounding, citation, tool/action, capability, or eval issues. Findings cite the evaluated prompt, score, threshold, explanation, and relevant project artifact.

## Remediation targeting

Recommendations target the layer evidenced by the failure:

| Evidence | Recommended target |
| -------- | ------------------ |
| The agent misunderstood an in-scope request | Instructions |
| A required knowledge source or capability is absent | `appPackage/declarativeAgent.json` |
| Action selection or parameters are wrong | Referenced API/MCP action definition |
| The expected response is stale or contradicts valid agent behavior | Eval item, pending explicit approval |
| A configured evaluator returns no score for otherwise valid output | Eval CLI/evaluator integration |

Eval edits always use the proposal-and-approval gate. Agent changes do not justify weakening the unchanged regression suite.

Resolve the actual manifest's instruction reference before recommending changes.
For example, `$[file('instructions.txt')]` in `appPackage/declarativeAgent.json`
targets `appPackage/instructions.txt`, not an inline field or a guessed filename.
Use exact artifact paths and rank recommendations by impact and effort.
A refusal consistent with the declared domain is an eval-expectation issue, not
an instruction gap. Mark the affected dataset/item pending explicit human
approval; do not remove boundary checks, evaluators, or thresholds to make it
pass. A recommendation-only request authorizes no file edits.
