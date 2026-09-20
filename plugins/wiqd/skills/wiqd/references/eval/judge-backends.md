# Judge Backends and Evaluator Compatibility

Authoritative reference for `--judge-backend` and which evaluators each backend can score. Grounded in the [runevals README](https://github.com/microsoft/M365-Copilot-Agent-Evals#-llm-judge-backend) (main branch) — reload this file if that upstream doc changes. Load this file whenever the skill is choosing a judge backend, validating a prompts file's `evaluators`/`default_evaluators`, or explaining a judge-related failure.

---

## The two backends

Only the four built-in LLM evaluators (Relevance, Coherence, Groundedness, Similarity) are scored by an LLM "judge" model. `--judge-backend` picks which service does that judging:

| Backend                                | Flag                             | Setup                                                                   | Judge model configured by                     |
| -------------------------------------- | -------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------- |
| GitHub Copilot (wiqd's default)        | `--judge-backend github-copilot` | `gh auth login` (or `GITHUB_TOKEN`) — no Azure OpenAI resource required | `GITHUB_COPILOT_JUDGE_MODEL` (default `auto`) |
| Azure OpenAI (`runevals`' own default) | `--judge-backend azure`          | Azure OpenAI deployment (see [azure-setup.md](azure-setup.md))          | `AZURE_AI_MODEL_NAME`                         |

`wiqd agent eval` defaults `--judge-backend` to `github-copilot` for a zero-Azure-setup first run; pass `--judge-backend azure` explicitly to use your own deployment.

## Evaluator compatibility matrix

| Evaluator                                            | Type         | Judge model?                | Works with `github-copilot`? |
| ---------------------------------------------------- | ------------ | --------------------------- | :--------------------------: |
| `Relevance`                                          | LLM          | Yes — either backend        |              ✅              |
| `Coherence`                                          | LLM          | Yes — either backend        |              ✅              |
| `Groundedness`                                       | LLM          | Yes — either backend        |              ✅              |
| `Similarity`                                         | LLM          | Yes — either backend        |              ✅              |
| `Citations`                                          | Count-based  | No                          |              ✅              |
| `RetrievalQuery`                                     | Non-LLM      | No                          |              ✅              |
| `RetrievalResult`                                    | Non-LLM      | No                          |              ✅              |
| `ExactMatch`                                         | String match | No                          |              ✅              |
| `PartialMatch`                                       | String match | No                          |              ✅              |
| Custom `.prompty` evaluators (e.g. `AssertionJudge`) | LLM          | Yes — **Azure OpenAI only** |              ❌              |

**Only custom `.prompty` evaluators are incompatible with `--judge-backend github-copilot`** — their Python wrapper always receives an `AzureOpenAIModelConfiguration` (see [custom-evaluators/README.md](https://github.com/microsoft/M365-Copilot-Agent-Evals/blob/main/docs/custom-evaluators/README.md)), regardless of `--judge-backend`. Every other built-in evaluator is deterministic/count-based (no judge model at all) or works under either LLM backend.

> ⚠️ **`ToolCallAccuracy` is not currently a supported evaluator.** It does not appear in the upstream evaluator table and is not usable today — do not generate eval documents that declare it, and do not tell users it is an Azure-only evaluator. See [gaps.md](gaps.md).

## Pre-flight check the skill must perform

Before invoking `runevals` (directly or via `wiqd agent eval`), read the target prompts file's `default_evaluators` and every item's `evaluators` override, and compare the union of evaluator names against the table above:

1. If `--judge-backend azure` is selected, no check is needed — every evaluator (including custom `.prompty` ones) is supported.
2. If `--judge-backend github-copilot` is selected (wiqd's default, including when the flag is omitted) and the union contains a custom `.prompty` evaluator, **stop before running** and tell the user:

   > "This dataset uses the custom evaluator `<name>`, which always requires Azure OpenAI. Rerun with `--judge-backend azure` (see references/azure-setup.md for setup), or remove `<name>` from this dataset."

3. If the union contains `ToolCallAccuracy`, tell the user it is currently unsupported by the CLI and should be removed from the dataset — do not attempt to run it under either backend.
4. Never silently drop or skip an unsupported evaluator and continue — surface it explicitly so the user isn't left with confusing, incomplete results.

## GPT-4.x vs GPT-5.x/o-series model configuration

The Eval CLI has three distinct judge routes. Select the backend first, then configure only the variables for that route:

| Route                              | Backend                          | Supported model family                                                                          | Judge variables                                                                                                   | Authentication                                                         |
| ---------------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| GitHub Copilot SDK                 | `--judge-backend github-copilot` | Any model exposed to the signed-in Copilot account, including GPT-4.x or GPT-5.x when available | Optional `GITHUB_COPILOT_JUDGE_MODEL`; unset defaults to `auto`                                                   | `gh auth login` or `GITHUB_TOKEN`                                      |
| Local Azure evaluators             | `--judge-backend azure`          | GPT-4.x                                                                                         | `AZURE_AI_OPENAI_ENDPOINT`, `AZURE_AI_API_VERSION`, `AZURE_AI_MODEL_NAME`; keep `AZURE_AI_PROJECT_ENDPOINT` unset | `AZURE_AI_API_KEY`, or `DefaultAzureCredential` when the key is absent |
| Microsoft Foundry cloud evaluation | `--judge-backend azure`          | GPT-5.x/o-series; GPT-4.x also works but is deprecated in Foundry                               | `AZURE_AI_PROJECT_ENDPOINT`, `AZURE_AI_MODEL_NAME`                                                                | Entra `DefaultAzureCredential`; `AZURE_AI_API_KEY` is not used         |

`TENANT_ID` is required on all routes for the M365 agent connection. It is not a Foundry judge credential. When an Azure credential must select a tenant other than its default, set `AZURE_TENANT_ID`.

For GitHub Copilot, the setup is identical for both model families: set `GITHUB_COPILOT_JUDGE_MODEL` to an exact model ID exposed by the signed-in account, or leave it unset for `auto`.

```powershell
# GPT-4.x through GitHub Copilot
$env:GITHUB_COPILOT_JUDGE_MODEL = "gpt-4.1"
wiqd agent eval --judge-backend github-copilot

# GPT-5.x through GitHub Copilot, when the account exposes this model
$env:GITHUB_COPILOT_JUDGE_MODEL = "gpt-5-mini"
wiqd agent eval --judge-backend github-copilot
```

If a pinned model is unavailable, `runevals` fails fast and reports the models available to that account. Do not infer availability from the model family alone.

GPT-5.x/o-series models cannot use the local evaluator path: their Responses API rejects the `response_format` parameter sent by the local SDK evaluators. They require the Microsoft Foundry route below.

Foundry routing is presence-based **within the Azure backend**:

| Env var                     | Purpose                                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------------------- |
| `AZURE_AI_PROJECT_ENDPOINT` | Microsoft Foundry project endpoint, e.g. `https://<account>.services.ai.azure.com/api/projects/<project>` |
| `AZURE_AI_MODEL_NAME`       | The GPT-5.x/o-series (or gpt-4x) model deployed in that Foundry project                                   |

- With `--judge-backend azure`, when **both** are set, `Relevance`/`Coherence`/`Groundedness`/`Similarity` run through Foundry cloud evaluation, supporting gpt-5x/o-series **and** gpt-4x models.
- When `AZURE_AI_PROJECT_ENDPOINT` is **unset**, those evaluators run locally and only support gpt-4x models (Microsoft Foundry has deprecated gpt-4x/gpt-4o judge models, with retirement dates through 2026 — plan to migrate).
- This path authenticates with Entra (`az login` / `DefaultAzureCredential`) and requires the **Azure AI Developer** role on the Foundry project — `AZURE_AI_API_KEY` is not used here. If the Foundry project is in a different tenant than your default credential, set `AZURE_TENANT_ID`.
- With `--judge-backend github-copilot`, the Copilot SDK judge takes precedence; `AZURE_AI_PROJECT_ENDPOINT` does not activate Foundry evaluation.
- The Foundry route covers the four built-in LLM evaluators. Custom `.prompty` evaluators still require a local `AzureOpenAIModelConfiguration`.

See [GPT-5.x and o-series judge models (Microsoft Foundry cloud evaluation)](https://github.com/microsoft/M365-Copilot-Agent-Evals#gpt5x-and-oseries-judge-models-microsoft-foundry-cloud-evaluation) for the full upstream writeup, and [references/azure-setup.md](azure-setup.md) for credential setup.

## Known gaps

See [references/gaps.md](gaps.md) for the full list. Highlights relevant to judge-backend selection:

- `runevals` does not validate evaluator/judge-backend compatibility up front — an incompatible custom evaluator under `--judge-backend github-copilot` is only discovered from run output, not rejected at startup. This skill's pre-flight check above is the only guard against a wasted run until that lands upstream.
- `ToolCallAccuracy` is currently non-functional and should not be generated or recommended.
