# Agent and Plugin evaluation workflow reference

## 1. Select the workflow

Start with `workflows/eval.md` for target discovery:

| Target | Workflow                   | Execution                     |
| ------ | -------------------------- | ----------------------------- |
| Agent  | `workflows/eval.md`        | Requires a deployed Agent ID  |
| Plugin | `workflows/plugin-eval.md` | Copilot mainline; no Agent ID |

Use explicit intent or root manifest registrations; ask when ambiguous.
`m365agents.yml` alone does not establish target type.

The selected workflow owns phase ordering, dataset selection and approvals.
Local definitions are required for generation, not for running an existing
dataset. `wiqd agent eval init` is an Agent bootstrap, not Plugin generation.

To find an Agent or Plugin title ID in the UI, open
`https://copilot.microsoft.com`, select **Plugins** or **Agents** in the left rail,
find the target and select **Share**. Copy the `T_...` ID at the end of the share
URL (for example, `T_1234`), not the full URL. Use it as `--agent-id` or
`M365_TITLE_ID` for Agents; for Plugins, use it only as the tool-call
`plugin_id`, never as an Agent execution target.

## 2. Select and prepare the dataset

- Always ask existing versus new dataset before detailed definition analysis.
- Discover `evals/**/*.json` documents with `items`; exclude `.evals/` results.
- Preserve the exact selected path in `$selectedDataset` for every command.
- Follow `references/eval/pra-framework.md` for applicability and agreed counts.
- Follow `references/eval/eval-templates.md` for expectations and configuration.
- For callable MCP, connector or API plugin tools, generated successful-tool-use
  items/turns MUST include both ToolCallSelection and ToolCallExecution (schema V2,
  threshold `1.0`, nonempty verified `calls`). Check before preview/write; block
  unresolved identities, never substitute response-only coverage. Follow the
  template's count/coverage tradeoff and no-tool exceptions.
- Never fabricate grounding evidence or treat unknown tools as an empty inventory.
- Generate `schemaVersion`, `default_evaluators`, and `items`, using the schema
  required by the selected release.
- Preview prompts, expectations, evaluators and coverage; obtain write approval.
- Write atomically and validate schema and exact count. Never silently save a
  partial suite. Additions require renewed count and write approval.

### Plugin evaluators

| Supported                                                  | Requirements                                        |
| ---------------------------------------------------------- | --------------------------------------------------- |
| Relevance, Coherence, Similarity, PartialMatch, ExactMatch | Target-specific configuration                       |
| Groundedness                                               | Actual `context`                                    |
| ToolCallSelection, ToolCallExecution                       | V2/schema V2 and verified `calls[].tool` identities |

Citations, Retrieval and ToolCallAccuracy are unsupported for Plugins.
Use Groundedness with real context or Similarity with a specific reference;
neither substitutes for citation or retrieval validation.

Check defaults and all supported item/turn overrides. Never silently remove
evaluators or weaken an existing suite. Tool-consent allowlists require separate
approval; expected calls do not grant consent.

## 3. Resolve the CLI and authentication

### Walkthroughs

For explanation-only or no-install requests, follow Phase 0A in
`workflows/eval.md`. Do not execute `runevals`, including `--version` or
`--init-only`: managed execution can install dependencies.

Inspect `wiqd ext show microsoft.eval --json` and the resolved active generation's
package metadata. Do not confuse the extension version, supported range or
dependency pin with the installed CLI version. Report missing evidence as
unverified; defer installation, initialization and authentication.

### Generation and execution

After dataset selection, follow the automatic latest-V2 setup in
`workflows/eval.md`:

- Select the latest published V2 (`>=2.0.0-preview1`, `<3.0.0`) without an upgrade
  prompt; do not downgrade a newer compatible V2.
- Preserve the stable managed pin and avoid global installation.
- Verify/report the resolved version and apply its validated
  `M365_COPILOT_EVAL_PATH` override to every call.
- Disclose setup failures; continue only with verified compatible V2, stating
  when latest-version status is unknown. Never fall back to V1.
- Run `--init-only` from the target project only when initialization is authorized.

Use `references/eval/judge-backends.md` and `references/eval/azure-setup.md`.
GitHub Copilot is the default and needs no Azure credentials. Custom `.prompty`
evaluators require Azure for Agent suites and are unsupported for Plugins.

Tenant/WORKIQ authentication is separate from wiqd/ATK and judge authentication.
Preserve explicit human EULA consent. Never print tokens or environment values.
Follow the canonical workflow's authentication diagnosis and handoff rules;
do not retry through alternate routes.

## 4. Execute and preserve evidence

Use the selected dataset and resolved V2 override. For Plugins:

```powershell
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ss-fff")
$scorecard = ".evals\scorecard-$timestamp.html"
$log = ".evals\runevals-$timestamp.debug.log"
New-Item -ItemType Directory -Force -Path ".evals" | Out-Null
wiqd plugin eval --skill wiqd --workflow plugin-eval `
  --config "$selectedDataset" --judge-backend github-copilot `
  --eval-log-level debug --output $scorecard 2>&1 | Tee-Object -FilePath $log
$exitCode = $LASTEXITCODE
Write-Output "wiqd plugin eval exit code: $exitCode"
```

For Agents, use `wiqd agent eval --workflow eval` with the selected deployed
Agent/environment. Respect selected account, judge and paths; forward concurrency
only when requested. Preserve prior reports and failed-run logs.

Plugin execution uses `--target m365-copilot --prompts-file <absolute-path>`,
without an Agent ID or component. Probe `--help` for `--target` support.
Reject inherited or loaded-file declarations of `M365_AGENT_ID` or `AGENT_ID`
without exposing values or modifying environment files. `M365_TITLE_ID` alone
does not select an Agent.

Run from the target project directory; the Plugin wrapper rejects a different
`--path` because runevals loads environment files from the working directory.

## 5. Analyze and propose improvements

Load `references/eval/result-analysis.md` and
`references/eval/remediation-patterns.md`, including for recommendation-only work.

- Interpret actual evaluator statuses and thresholds; missing evidence is unknown.
- Response quality alone does not prove Plugin invocation. Mainline can select
  other installed tools; WIQD does not isolate a Plugin.
- Report tool-call verdicts only from actual runtime evidence.
- Resolve exact remediation targets; distinguish evidence from hypotheses and
  state impact and effort.
- Preserve scope boundaries, evaluators and thresholds. Flag incorrect
  expectations for human review rather than broadening capabilities.
- Do not edit manifests through this workflow. Preview precise dataset diffs and
  obtain separate approval for every suite mutation.
- Return full scorecard/log paths, exit code and limitations. Link only existing
  reports and include the tracked interpretation/remediation guides.
