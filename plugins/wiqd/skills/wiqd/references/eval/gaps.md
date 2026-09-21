# Known Gaps

Honest, current-state limitations in the Evals CLI (`@microsoft/m365-copilot-eval`) and in this skill's integration with it. Surface these to the user proactively when relevant — do not silently work around them or imply they're solved. Re-check this file's claims against the upstream README (`M365-Copilot-Agent-Evals/README.md`, main branch) periodically, since the CLI is actively evolving.

## 1. `ToolCallAccuracy` is not a supported evaluator

There is no `ToolCallAccuracy` (or equivalent tool-call-correctness) evaluator in the current built-in evaluator registry — it does not appear in the upstream README's evaluator table under either judge backend. Any prior guidance (in this skill or elsewhere) suggesting it exists or requires Azure OpenAI is stale.

**Workaround:** for Act-category prompts (agent expected to invoke a specific tool/action), verify tool-call correctness indirectly:

- Write a precise `expected_response` describing the expected action and its outcome, and score it with `Relevance`/`Coherence`/`Similarity`.
- Manually review the agent's transcript/tool-call trace for the correct tool name, parameters, and sequencing — this is currently the only reliable way to catch a wrong-tool or wrong-parameter failure.

This is a functionality gap in the upstream CLI, not something this skill can fully compensate for.

## 2. No upfront evaluator/judge-backend compatibility validation

`runevals` does not check, before executing, whether every evaluator declared in a prompts file is compatible with the selected `--judge-backend`. Running custom `.prompty` evaluators under `--judge-backend github-copilot` fails (or behaves unexpectedly) only once the run reaches that evaluator, wasting the run's other results.

**Workaround:** this skill performs its own pre-flight check (see [judge-backends.md](judge-backends.md#pre-flight-check-the-skill-must-perform)) — it reads the prompts file's evaluators before invoking `runevals` and warns the user up front if an incompatible combination is detected, rather than relying on the CLI to catch it.

## 3. The skill previously had no judge-backend control at all

Before this update, the `wiqd agent eval` manifest exposed no `--judge-backend` or eval-specific log-level option — every run implicitly used whatever the CLI's own default was (Azure OpenAI), forcing an Azure OpenAI setup even for a first, exploratory run. This is now fixed: `wiqd agent eval` defaults `--judge-backend` to `github-copilot` (zero-Azure-setup) and exposes `--eval-log-level` for diagnosing runevals failures without colliding with wiqd's global `--log-level`.

## 4. The design specification can drift from the shipped manifest

This package follows a spec-first convention: the design specification describes intended behavior, while `wiqd-extension.json` implements it. Because the specification is hand-maintained, it can lag behind manifest changes. Treat `wiqd-extension.json` and this `references/` directory as the source of truth for current behavior; treat the design specification as intent that may need reconciling.

## 5. GPT-5.x / Foundry cloud evaluation path is not exercised by this skill's automated tests

The `AZURE_AI_PROJECT_ENDPOINT` + `AZURE_AI_MODEL_NAME` routing to Microsoft Foundry cloud evaluation is documented (see [judge-backends.md](judge-backends.md#gpt-5x--o-series-judge-models-microsoft-foundry-cloud-evaluation)) but not something this skill validates or configures on the user's behalf beyond forwarding guidance — the user is responsible for provisioning the Foundry project, model deployment, and Entra role assignment themselves.
