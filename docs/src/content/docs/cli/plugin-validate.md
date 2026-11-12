---
title: wiqd plugin validate
description: Check saved source offline, validate a final package, or assess Marketplace readiness.
---

Use `wiqd plugin validate` to check saved source, a final ZIP, or Marketplace readiness:

| Mode | What is checked | Inputs and effects |
| --- | --- | --- |
| `source` | Saved DA file registered in `appPackage/manifest.json` | Offline, no sign-in, ZIP, build, upload or report directory; checked files and diagnostics are returned. |
| `package` (default) | A captured final ZIP through Teams Developer Portal (TDP) | Existing ZIP required; uploads a read-only temporary copy and may require sign-in. |
| `marketplace` | Package validation **and** StoreOps policy checks on the same captured ZIP | Optional listing/current-host evidence; unverified policies are reported separately from the overall verdict. |

```bash
wiqd plugin validate --mode source --path ./my-agent --env local
wiqd plugin validate --mode package --package-file ./final.zip
wiqd plugin validate --mode marketplace --package-file ./final.zip --listing-file ./listing.json
```

Validation never builds, edits, provisions or publishes. A passing source check is not final-ZIP
acceptance, and a passing package/Marketplace result is not official certification.

## Source checks before a build or deployment

Select source explicitly for the offline authoring loop and CI. Use the same project/environment
as the lifecycle operation:

```bash
wiqd plugin validate --mode source --path ./my-agent --env dev --json
wiqd plugin package --path ./my-agent --env dev --output ./final.zip
wiqd plugin validate --mode package --package-file ./final.zip --json
```

Run each command only after the preceding command succeeds. Source checks the saved
DA file registered by `copilotAgents.declarativeAgents[].file` in the root app manifest,
not unsaved editor buffers or the whole project. `declarativeAgent.json` is the
default filename, not a requirement: a reference such as `agents/custom.json`
selects `appPackage/agents/custom.json`, which is also the path returned in diagnostics.
The project must contain valid `m365agents.yml` and `appPackage/manifest.json`.
If the app manifest declares an agent, its referenced saved file must exist within
`appPackage/`. A plugin without a declared agent has no declarative-agent source
coverage; this is not whole-plugin acceptance.
`--env` defaults to `local` and limits context to that environment. Missing deployment-generated
IDs are advisory; do not invent values before provisioning.

Source inputs and references must stay within the selected project's canonical root;
links or traversal into external files are rejected without reading their contents.
Source checks are limited to 4 MiB per file, 16 MiB total and 128 files.

Use source checks before packaging or provisioning. Provision builds its own upload;
a source pass does not prove that a later upload uses a previously validated ZIP.

## ZIP selection and options

Use `--package-file` to select the exact ZIP; a relative path is relative to the current working
directory. Explicit ZIP-only validation requires no source project. Without it,
`--path` (CWD by default) must pass structural project recognition and contain exactly one nonrecursive
`appPackage/build/*.zip`. Missing/ambiguous selection fails. The command never selects the newest
ZIP, builds automatically or falls back from a bad explicit path. `--env` does not select a ZIP.

`--listing-file`, `--ai-mode auto|copilot|off`, `--ai-timeout <seconds>` and
`--ai-evidence-file` apply only to Marketplace. The AI timeout is 1–1200 whole seconds
(default 240). Replay evidence requires
`--ai-mode off --ai-evidence-file "<evidence.json>"`. `off` does not disable deterministic network
checks. Source rejects ZIP/listing/AI inputs; package rejects listing/AI options.

For explicitly authorized read-only functional testing, add `--agent-id <deployed-id>`
in Marketplace mode. Validation plans from the captured package/listing, saves the plan,
collects up to 12 scenarios, then independently assesses the full answers.
The ID asserts the target-to-package mapping; it is not proof of deployment or a tool sandbox.
There is no target discovery, automatic sign-in or retry. Omit the ID to avoid target calls.

`--functional-timeout` selects a total collection budget of 1–900 seconds (default 180).
`--functional-request-timeout` selects a per-call limit of 1–900 seconds (default 60),
also capped by the remaining total. Both require the ID. AI-off, mock mode and supplied
AI/functional evidence are incompatible with automatic collection. Advanced
`--functional-evidence-file` replays existing package-bound evidence without target calls.
Authentication, transport, timeout and missing evidence never become an implicit pass.

### Explicit single-request collection

For independent conversational scenarios, `--functional-batch` collects all
questions in one request. Omit it to collect questions individually. Shared
context can affect the answers; dependent scenarios and MCP packages are unsupported.
An invalid or oversized response leaves the batch incomplete, without automatically
retrying or switching to individual requests.

If your target returns the same JSON reply twice, the optional
`--functional-batch-allow-duplicate-json` accepts exactly two identical valid
replies. It requires batch mode; differing replies or extra text still fail.

## Marketplace listings

In a coding-agent session, ask to validate your package for Marketplace. The workflow
reuses a valid `.validate/listing.json`, or collects missing information and asks you
to review the complete listing HTML before validation. Saving a listing does not
publish it or establish a passing result.

For direct CLI use, inspect the writer's required fields, then read or preview a saved listing:

```bash
wiqd plugin add market-listing --help
wiqd plugin get market-listing --agent-folder ./my-agent --json
wiqd plugin preview market-listing --agent-folder ./my-agent --json
```

All three helpers require `--agent-folder` as a workspace, not a source project.
Neither `m365agents.yml` nor `appPackage/manifest.json` is required. The writer can
discover a single ZIP in a ZIP-only folder; reading and previewing an existing listing
do not require a ZIP. They preserve the original ZIP and source assets; the writer
creates managed listing copies. Reading and previewing do not run validation.

## Results and JSON

With `--json`, stdout contains only the shared JSON envelope; diagnostics/progress use stderr.
Progress reports activity, not passing checks. Use `--log-level none` to suppress it, or
`--log-format text` for readable progress alongside JSON output.
Read success `data` or completed non-pass `error.data`. Data contains `validation`, `source`,
`manifest` and `report`; inapplicable provider objects are null.

**`validation.result` is the overall verdict**, not policy-only `report.result`:

- `FAILED`: confirmed blocking findings, even if other selected work is incomplete.
- `ERROR`: no confirmed blocker, but selected provider execution could not complete
  (for example, package validation was unavailable or timed out).
- `PASSED`: no confirmed must-fix findings remain in a completed validation.
  Unverified Marketplace policy checks, suggestions and warnings do not block this result.

A pass does not mean every policy check passed or all evidence was available.
For example, zero must-fixes with 28 unverified policy checks and three suggestions
is **PASSED** when package validation completed successfully. The report still shows
the evidence gaps, counts and next actions; it does not establish publication readiness
or official approval. After repair, the result comes from fresh revalidation, not edit success.

Source returns checked files and diagnostics with codes, severity and locations.
JSON locations are zero-based, like LSP; table locations are one-based. It has no ZIP
identity or HTML link. Package/Marketplace save results and captured
inputs under `~/.wiqd/validation/reports/<run-id>/`. Use returned `validation.reportPaths` and
`validation.inputPaths` to locate them.

### Concise human-readable results

The terminal and coding-agent summary show the first **five failed policies** and,
independently, the first **five incomplete policies**, in the report's existing order.
Passing policies remain in the full counts rather than filling the table. When a
category exceeds five, the summary gives its full count and exact omitted count.
For example, six failed policies show five rows and **1 omitted**.

The table starts with **Issue → Severity → AI repair → Next action**, followed by
**Validation status → Policy/check → Description/location**. Completed failures and
incomplete checks share the table but have distinct statuses; an incomplete check
is not a confirmed defect. Package diagnostics keep their actual codes, severities
and locations and are not hidden by the policy limit.

**Open the HTML report** for every finding, its AI repairability explanation and
next steps. JSON output and both report formats keep all policies/checks. The
preview does not reduce validation or the scope of authorized repairs.

| Exit | Meaning |
| --- | --- |
| 0 | Passed. |
| 1 | Blocking findings, incomplete provider execution, invalid input or report-publication failure. |
| 2 | Missing runtime/native/configuration dependency or invalid source project. |
| 130 | Cancelled; no completed report is published. |

## Coding-agent validation and repair

“Validate my agent” selects source; a supplied ZIP selects package; Marketplace readiness
selects Marketplace, including package checks. Account setup and publication are separate workflows.

For Marketplace readiness, the coding agent first explains the journey, with
scope/ZIP selection as a prerequisite:

1. Collect listing information.
2. Authorize functional testing separately, if live testing is selected and eligible.
3. Wait for validation to complete.
4. Auto-fix issues and re-validate, only when repair is authorized.
5. Review the validation report.

If you have not selected live-testing scope, choose whether to run package and
Marketplace checks only or include eligible live functional/connector testing.
Live testing requires your authorization and any necessary installation,
sign-in, and connector access. Direct CLI commands do not show this interactive prompt.

Review the complete listing HTML before Marketplace validation. The coding agent
uses evidence from the current session without repeating completed target calls.
Validation alone does not authorize repair. “Fix and revalidate” permits
targeted changes and same-mode verification. Source repair reruns source without building
or demanding HTML. Package-content repair creates an explicit new ZIP from source
or bounded ZIP-only replacements; listing/evidence-only repair keeps the ZIP
unchanged without a source project or build. Marketplace refreshes evidence.
Missing input/service access stays blocked, not a fabricated pass.
The coding agent reports the verification outcome and any next action.

Findings show **AI-fixable**, **AI-fixable · Needs your input**, or **External action
required**, with policy-specific reasons. Capability is not consent, readiness or a
guaranteed pass. Incomplete checks remain unverified; old reports without metadata
say **Repairability not recorded**.

After showing actionable findings, the coding agent offers **Fix and revalidate** /
**Not now**. Declining leaves files unchanged.
Report-only requests skip the choice. Explicit repair needs no repeated authorization.

Before editing, the coding agent collects missing information for the selected
repairs together and reuses answers you already supplied. Missing or cancelled
answers leave files unchanged. Once the required inputs are available, it applies
the repairs and revalidates in the original mode.

Source-build repair requires the actual project/environment and source precheck.
ZIP-only authors can instead prepare explicit replacements and create a new ZIP
without a fabricated project/environment; original source is not synchronized:

```bash
wiqd plugin repair package --package-file ./original.zip --changes-file ./changes.json --output ./repaired.zip --json
```

The changes file contains `packageSha256` and
`replacements: [{ "path": "manifest.json", "contentPath": "./edited-manifest.json" }]`.
The helper preserves original/untouched bytes and rejects unsafe archive paths,
stale hashes, changed app identity, no-op changes and existing output files.
It does not validate, publish or prove repair success. Listing/evidence-only repair
keeps unchanged ZIP bytes and requires neither source nor a build. A rebuilt ZIP
needs an applicable user-confirmed working listing binding, preserving approved
fields/assets; retained listing/evidence are never rewritten or silently dropped.

**Passed after repair** appears below passed policies as a subset, not another count.
It identifies previous failures that passed fresh, comparable checks. Partial
repairs, removed checks and inconclusive results are not counted as fixed.
The coding-agent workflow runs at most two authorized repair rounds. An applied
but unverified repair is not a pass or official approval.

## Upgrade from older validation commands

Use `wiqd plugin validate` instead of retired `wiqd agent validate` commands.
Use the listing/repair commands shown above instead of their former validation
subcommands. Old commands and modes return migration guidance rather than running checks:

- Old offline `static` use → explicitly choose `--mode source`.
- Old package `deep` or `manifest` use → explicitly choose `--mode package` and the final ZIP.
- Old comma-combined selections have no direct equivalent. Choose one current mode per
  invocation; Marketplace already includes package checks.

Upgrade the CLI and host plugin to compatible releases, update the plugin through its native
marketplace, and start a **fresh host session**. A CLI update/extension registration alone does
not refresh host guidance. Use the canonical plugin validation command and
the listing/repair helpers.
