# Known Gaps

Honest, current-state limitations in the Evals CLI (`@microsoft/m365-copilot-eval`) and in this skill's integration with it. Surface these to the user proactively when relevant — do not silently work around them or imply they're solved. Re-check this file's claims against the upstream README (`M365-Copilot-Agent-Evals/README.md`, main branch) periodically, since the CLI is actively evolving.

## 1. Tool-call evaluation requires V2 preview and runtime evidence

V2 preview supports deterministic `ToolCallSelection` and `ToolCallExecution`
for Agents and Plugins with schema V2. Stable V1 does not support them.
`ToolCallAccuracy` remains an unsupported name, not an Azure-only alternative.

Use verified `calls[].tool` identities and actual Developer Info telemetry; see
[eval-templates.md](eval-templates.md). Missing telemetry is unknown/error,
not a passing score. Selection checks identities, not execution; execution checks
HTTP 2xx multiplicity, not argument correctness, ordering or business outcomes.

On V1, response-quality scores remain indirect evidence only. The skill
automatically upgrades to latest published V2 without offering a V1 choice.
Never remove tool-call coverage or claim that response text proves invocation.

## 2. No upfront evaluator/judge-backend compatibility validation

`runevals` does not check, before executing, whether every evaluator declared in a prompts file is compatible with the selected `--judge-backend`. Running custom `.prompty` evaluators under `--judge-backend github-copilot` fails (or behaves unexpectedly) only once the run reaches that evaluator, wasting the run's other results.

**Workaround:** this skill performs its own pre-flight check (see [judge-backends.md](judge-backends.md#pre-flight-check-the-skill-must-perform)) — it reads the prompts file's evaluators before invoking `runevals` and warns the user up front if an incompatible combination is detected, rather than relying on the CLI to catch it.

## 3. The skill previously had no judge-backend control at all

Before this update, the `wiqd agent eval` manifest exposed no `--judge-backend` or eval-specific log-level option — every run implicitly used whatever the CLI's own default was (Azure OpenAI), forcing an Azure OpenAI setup even for a first, exploratory run. This is now fixed: `wiqd agent eval` defaults `--judge-backend` to `github-copilot` (zero-Azure-setup) and exposes `--eval-log-level` for diagnosing runevals failures without colliding with wiqd's global `--log-level`.

## 4. The design specification can drift from the shipped manifest

This package follows a spec-first convention: the design specification describes intended behavior, while `wiqd-extension.json` implements it. Because the specification is hand-maintained, it can lag behind manifest changes. Treat `wiqd-extension.json` and this `references/` directory as the source of truth for current behavior; treat the design specification as intent that may need reconciling.

## 5. GPT-5.x / Foundry cloud evaluation path is not exercised by this skill's automated tests

The `AZURE_AI_PROJECT_ENDPOINT` + `AZURE_AI_MODEL_NAME` routing to Microsoft Foundry cloud evaluation is documented (see [judge-backends.md](judge-backends.md#gpt-5x--o-series-judge-models-microsoft-foundry-cloud-evaluation)) but not something this skill validates or configures on the user's behalf beyond forwarding guidance — the user is responsible for provisioning the Foundry project, model deployment, and Entra role assignment themselves.
