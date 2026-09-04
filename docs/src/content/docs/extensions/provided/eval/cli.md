---
title: Eval · CLI commands
description: Every command contributed by Work IQ Dev Tools' Eval extension
---

# Eval · CLI commands

The Eval extension contributes two commands under `wiqd agent eval`:

| Command                                                                          | What it does                                                  |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [`wiqd agent eval`](/cli/reference/#wiqd-agent-eval)                  | Run quality evaluations against a deployed declarative agent  |
| [`wiqd agent eval init`](/cli/reference/#wiqd-agent-eval-init)        | Scaffold a starter `evals/prompts.json` for the agent         |

`wiqd agent eval init` requires an ATK project and emits a fixed seven-item bootstrap for the default ATK declarative-agent template. It is not the manifest-aware generator and has no prompt-count option. When the wiqd eval skill recommends or the user selects a count, the skill writes and verifies exactly that many generated items without substituting `eval init`.

`wiqd agent eval` does **not** require `m365agents.yml` or a provisioned ATK project. It needs only (1) a prompts file and (2) a resolvable agent title ID — sourced from `env/.env.<env>` (`M365_TITLE_ID`) or from `--agent-id`.

## Running against an evals-only folder

You can run `wiqd agent eval` from a folder that holds only `evals/prompts.json` plus `env/.env.<env>` carrying `M365_TITLE_ID` — no `m365agents.yml` required. The title ID is read from the env file automatically, so no `--agent-id` is needed:

```bash
wiqd agent eval --path <folder> --env <env>
```

## Evaluating a deployed agent directly

Pass `--agent-id <id>` to run evals against an already-deployed agent from any folder that holds only a prompts file — no `m365agents.yml` or `env/.env.<env>` required:

```bash
wiqd agent eval --path <folder> --agent-id <id> -c prompts.json
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
| `--judge-backend` | `string` | `github-copilot`    | LLM judge backend for `Relevance`/`Coherence`/`Groundedness`/`Similarity`: `github-copilot` (zero-setup, `gh auth login`/`GITHUB_TOKEN`) or `azure` (Azure OpenAI). Custom `.prompty` evaluators always need `azure`. |
| `--log-level`    | `string` | `debug`              | Verbosity forwarded to `runevals`: `debug`, `info`, `warning`, `error`.                                             |
| `--concurrency`  | `int`    | Eval CLI default     | Optional concurrent scenario override (1-5)                                                                        |
| `--threshold`    | `float`  | _(none)_             | Minimum pass-rate (0-1) to succeed. Exit 1 if score falls below this.                                              |

## Scorecard workflow

The wiqd eval skill runs with the GitHub Copilot judge and requests a new timestamped HTML scorecard:

```powershell
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ss")
wiqd agent eval --judge-backend github-copilot --log-level debug `
  --output ".evals\scorecard-$timestamp.html"
```

The skill does not override concurrency. When the user supplies `--concurrency`, wiqd forwards it; otherwise wiqd omits the flag and lets the Eval CLI choose its default (currently **5**).

## Authentication boundaries

`wiqd agent eval` does not reuse the ATK session created by `wiqd auth login`. The Eval CLI authenticates the deployed-agent connection itself using the selected tenant ID, its encrypted MSAL cache under `~/.m365-copilot-agent-evals/`, and the platform broker when interactive authentication is required. Tenant admin approval for the WORKIQ client app is required. Use `--account` to select the intended cached identity when multiple accounts are available.

Judge authentication is separate: GitHub Copilot uses GitHub authentication, while Azure/Foundry uses the configured Azure credential. EULA acceptance is a third, independent prerequisite. wiqd detects a missing or stale Eval CLI EULA marker and blocks for explicit human consent before authentication begins.

After the run, the skill opens the scorecard data, correlates failures with the agent's instructions, tools, knowledge sources, and manifest, and returns targeted recommendations plus a `file:///` link to the scorecard.

## Evaluation workflow

The wiqd eval skill owns the complete improvement loop:

1. Validate the project or minimal eval workspace.
2. Onboard the Eval CLI and selected judge.
3. Generate a PRA-balanced eval document when needed.
4. Run the current suite to a timestamped HTML scorecard.
5. Interpret every configured evaluator and classify root causes.
6. Recommend the smallest justified change to the eval suite, instructions, capabilities, knowledge sources, or action definitions.
7. Re-run the unchanged suite after agent improvements for an apples-to-apples comparison.

The suite is the behavioral specification. The skill will not remove evaluators, lower thresholds, or delete difficult scenarios merely to improve the pass rate.

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

## Perceive-Reason-Act (PRA) framework

Generated suites use PRA to cover the agent's declared behavior:

| Category | What it validates | Included when |
| -------- | ----------------- | ------------- |
| Perceive | Retrieval, grounding, and citations | The manifest declares knowledge sources |
| Reason | Instruction following, synthesis, boundaries, and response quality | System instructions exist |
| Act | Correct action selection and parameter behavior | The manifest declares actions or plugins |

Generation analyzes the manifest first, then allocates scenarios only to applicable categories. It never invents an action or knowledge source that the agent does not declare.

## Judge onboarding

wiqd manages the exact Eval CLI version required by this extension. The first
`wiqd agent eval` or `wiqd exec runevals` command provisions it under
`~/.wiqd/extensions/microsoft.eval/`; do not install a separate global copy. To
inspect the managed CLI directly, use `wiqd exec runevals`, then change to the agent
project directory and initialize the environment:

```bash
cd /path/to/your-agent-project
wiqd exec runevals --version
wiqd exec runevals --init-only
```

Choose a judge based on the suite:

| Judge | Best for | Setup |
| ----- | -------- | ----- |
| GitHub Copilot | Default, zero-Azure setup for built-in evaluators | `gh auth login` or `GITHUB_TOKEN` |
| Azure | Custom `.prompty` evaluators or your own Azure deployment | Azure OpenAI/Foundry endpoint, model, tenant, and authentication |

For GitHub Copilot, verify an existing session with `gh auth status`; run `gh auth login` only in an interactive user session.

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
wiqd agent eval --judge-backend github-copilot

# GPT-5.x through GitHub Copilot, when available to the account
$env:GITHUB_COPILOT_JUDGE_MODEL = "gpt-5-mini"
wiqd agent eval --judge-backend github-copilot
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
