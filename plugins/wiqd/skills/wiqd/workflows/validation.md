---
name: validation
description: Validate saved source, packages and Marketplace listings; prepare a missing development target for explicitly requested live checks, and repair findings when authorized.
trigger-summary: 'validate my agent, check source, validate package, Marketplace validation, fix validation findings'
triggers: 'validate my agent, validate source, check my manifest, fix my agent manifest, validate package, validate this package, validate this ZIP, check this ZIP, validate package for marketplace, run live functional validation, live functional validation, functional validation, interpret my validation report, partner center validation, partner center validate, marketplace validation, marketplace validate, validate for partner center, validate for marketplace, fix validation findings, fix this validation report, validate and fix this package, validate and fix my agent'
routing-label: 'Agent source / package / Marketplace validation and repair'
routing-intent: 'Explicitly validate source, a final ZIP or Marketplace readiness, run live functional checks, or repair validation findings; not general authoring, account setup or publication'
routing-order: 10
contract-version: 1
routing-requires: [agent validate]
wiqd-lifecycle-theme: Improve
wiqd-lifecycle-order: 1
journey: |
  [Improve]
  order: 2
  box-item: validate
  workflow-desc: for source, package and Marketplace validation and authorized repair
---

# Agent validation and repair

This workflow is contributed by `microsoft.validate` to the existing **wiqd** skill in stable
1P and 3P plugins. It uniquely owns explicit agent validation and report-bound repair. Core owns
general authoring, packaging and provisioning; the audience's account and publishing workflows
retain onboarding, enrollment, release approval and publication ownership. Their source prechecks
do not transfer those journeys here unless repair is requested.
Only the explicitly requested live-functional branch below may prepare a development target.
Use plain language with the customer; keep internal schema/evidence mechanics out of normal replies.

## 1. Check compatibility

Use compatible CLI and host-plugin releases and a fresh host session after plugin updates.
CLI installation/registration does not refresh host skills. No validation feature flag is required
or queried. Missing commands or rejected current modes are upgrade blockers: report them, do not
install, publish, change config or fall back to old modes automatically.

## 2. Select scope and inputs

**Repair continuation:** If the user asks to fix identified validation findings, including
“fix it”, “fix the issues” or equivalent requests in the user's language after this workflow's report, read
[autofix](../references/validate/autofix.md) now. Retain this workflow as owner until revalidation or a
concrete blocker; do not restart generic validation or hand the entire task to general editing.
If several reports could be meant, ask which. For “validate and fix”, first complete steps 2–4,
then continue to autofix without asking for the same authorization again.

| Request                                            | Mode                                    |
| -------------------------------------------------- | --------------------------------------- |
| Validate my agent, saved source or source manifest | `source`                                |
| Validate a package/ZIP                             | `package` (CLI default)                 |
| Partner Center / Marketplace validation            | `marketplace`                           |
| Both package and Marketplace validation            | `marketplace` (includes package checks) |
| Explicit live functional validation                | `marketplace`                           |

Say which scope will run. Source runs offline one-shot diagnostics on saved
`appPackage/declarativeAgent.json`; it does not start an LSP server, build, upload, require a ZIP,
or write reports. Use the confirmed project and environment (`local` by default).
Do not add Marketplace merely because a ZIP exists. Package uploads captured ZIP bytes to TDP and
may request sign-in; Marketplace includes TDP and StoreOps on the same captured ZIP.
Missing auth/EULA or headless interactive failures are blockers,
not warnings that imply validation passed. Follow the orchestrator's human-consent EULA guidance.
Use the supplied final ZIP or CLI discovery under `appPackage/build`; ask if selection is unclear.
For package/Marketplace without a ZIP, read `references/wiqd-core/package.md` and build only when
authorized. That workflow first checks `--mode source` with the same project/environment; never
call default validation as a pre-build gate. Use the exact returned package path, not the newest ZIP.
Old `static`, `deep`, `manifest` and comma-combined modes are rejected with migration guidance;
do not retry them or invent aliases.

**Live functional intent:** Only explicitly requested live functional checks need a runtime
target. Marketplace validation alone, an unpublished app, static/offline checks and supplied
functional-evidence replay do not authorize deployment. Explicit AI-off or mock requests do not
prepare a target; report incompatible live options instead of overriding them. If intent is ambiguous, ask whether the
user wants live functional checks or validation without new target calls. Preserve the selected
modes, original ZIP/hash, listing and requested call/time budgets. A missing store listing is
not proof that a personal development target is absent.
For explicit live checks, an existing agent ID is optional: reuse one already supplied or
verified; otherwise default to local development-target preparation. Do not ask for an
agent ID or whether the user has one as an initial required field.

### Marketplace listing

Source and package skip collection. For Marketplace, ask the CLI to read the listing
from `<collection-workspace>/.validate/listing.json` using the command below. The collection workspace is
the known agent project, or the supplied ZIP's directory/ZIP-only folder.

```bash
wiqd agent validate get-market-listing --agent-folder "<collection-workspace>" --json --skill wiqd
```

Include `--listing-file "<supplied-listing.json>"` when explicitly provided.

- **Command succeeded:** skip collection and go directly to
  [whole-listing HTML review](../references/validate/listing-collection.md#review-the-complete-listing)
  using the returned `data.listingPath`. Keep the listing unchanged; do not reconfirm individual
  fields or force a legacy-format upgrade.
- **Error code `"404"` or `MARKET_LISTING_INVALID`:** follow
  [listing collection](../references/validate/listing-collection.md) to collect and save a replacement
  with `add-market-listing`, then generate its HTML review and wait for whole-listing confirmation.
  Only then use its returned listing path; do not prepare evidence or validate before confirmation.

Both paths require just one overall HTML confirmation before Step 3.
The command checks the schema; do not judge validity yourself or inspect the schema.
Other CLI errors are blockers, not permission to replace a file.
The writer saves to the default workspace path; an invalid external listing remains untouched.
The CLI owns schema checks and JSON construction. Do not copy schemas into the skill.
Pass the selected absolute path as `--listing-file`. Partner Center account/offer setup
is not required for validation.

## 3. Run validation

For source:

```bash
wiqd agent validate --mode source --path "<project>" --env "<environment>" --json --skill wiqd --workflow validation
```

For package:

```bash
wiqd agent validate --mode package --package-file "<final.zip>" --json --skill wiqd --workflow validation
```

For Marketplace, follow [current-agent evidence](../references/validate/current-agent-evidence.md)
to prepare evidence in this session and run validation as a host-managed background job.
Use the same ZIP and listing for preparation and validation.
For explicitly requested live functional checks without supplied replay evidence, first follow
[development target preparation](../references/validate/development-target.md). Reuse a suitable exact
target already supplied or verified; otherwise default to local preparation without an
agent-ID question or a provisioning-choice gate. Only with scoped authorization may Core sideload the selected DA ZIP,
or convert a supported MCP connector ZIP into a separate DA host and sideload it. Store
publication and a source project are not prerequisites for that ZIP lifecycle.
After provisioning a connector DA host, show its returned clickable Copilot link
and a safe sample prompt, then follow development target preparation's
**connector Allow handoff**: the user opens Microsoft 365 Copilot, sends the
sample prompt and completes any Allow/input steps themselves. Wait for explicit
readiness confirmation through the native question tool before request preparation
or live collection. Installation approval alone is not readiness confirmation.
When the user supplies a deployed agent ID for read-only functional testing,
or authorized ZIP provisioning returns its exact verified target and any required
connector Allow handoff is confirmed, pass it to request preparation
only. The CLI generates the plan and captures
observations internally; final validation reuses its returned evidence file.
Do not ask for a manually prepared observations file or call the target twice.
Without a supplied or verified provision-result ID, do not guess a target or contact one implicitly.
For a single root MCP connector ZIP, obtain approval for one bounded read-only
public-example lookup using existing access, then follow current-agent evidence
with `--connector-scenario public-example` on request preparation only.
This explicit profile supports omitted auth and packages with skills, tabs or
compose extensions without rewriting their descriptions. It tests the connector
only; other packaged surfaces are not covered. Preserve all development-target
upload, authentication and Allow confirmations; missing auth is not permission
to assume anonymous access. A ZIP-only request without live approval remains no-call.
Auth failures, denial, cancellation and inconclusive target state stop this live branch; never
provision again as a collection-error recovery. Source repair/revalidation is not new deployment consent.
Keep the host job handle, report running honestly, and retrieve that same job's output on completion;
do not start a duplicate run to check status. Let the CLI report execution errors.

## 4. Show the result

Read `data` or completed non-pass `error.data`. Use `validation.result` for the overall result,
not the exit code or policy-only `report.result`. For source, show checked files and actual
diagnostic codes, severities and locations; there is no ZIP, output directory or HTML link to invent.
For package/Marketplace show required fixes, incomplete checks,
`validation.outputDir` and a clickable Markdown link to the returned `validation.reportPaths.html`.
Summarize confirmed findings in a table: **Policy | Finding | Severity | AI repair | Next action**.
Use each policy's `autofix.supported`, `autofix.mode` and `autofix.reason`, not a new
model classification. Say **AI-fixable**, **AI-fixable - needs your input**, or
**External action required**, localized to the user's language. Missing legacy metadata
means **Repairability not recorded**, not unsupported. Show missing inputs/current blockers
separately from capability. Put incomplete/error checks in a separate table: they are
unverified, not confirmed defects, even when the policy supports repair. Never edit an
app to hide an evaluator error. Combine questions for policies sharing one field.
Use `[Open HTML report](file:///...)` with a standard URL-encoded file URI as the target.
Do not show only a bare path/URI or wrap the link in code formatting.
Completed FAILED/ERROR runs can still have saved reports; do not guess paths after execution failure.
The output directory also retains the evaluated ZIP and supplied listing.

Keep the explanation short; the HTML report contains the details. Do not rewrite results or
present partial validation as official Marketplace approval.
This workflow validates only; it does not change publishing workflows.

Recommend the next step: fix validation findings or incomplete checks after FAILED/ERROR.
After source PASSED, return to the previously authorized caller or continue authoring; do not
present source as final-ZIP readiness. After package/Marketplace PASSED, recommend the relevant
next lifecycle/publishing workflow with prerequisites unchanged, not an automatic submission.
A recommendation alone does not authorize edits or publishing.

## 5. Collect the repair decision

For actionable findings, this decision is part of completing the validation workflow. Show the
result and report link when produced in a progress message, then invoke the native choice tool before ending the
turn. A final findings-only answer skips this step. Use the user's language.
If the user explicitly requested a report-only response or no questions, respect that scope and
finish with the findings instead of opening a choice prompt.

- **Actionable repair:** For a grounded source/package error or an AI-fixable failed Marketplace MF finding (or an
  explicitly selected warning/SF), call the host's native choice tool — **`ask_user` in Copilot** —
  with two choices: **“Fix and revalidate”** and **“Not now”**, localized to the user's language.
  Name the repairable finding and explain the applicable source, ZIP-copy or listing-only
  path followed by same-mode revalidation, or source edit → same-mode source recheck.
  For example: “Fix `<finding>` in a new package copy and revalidate with the same mode?”
  Adapt the finding and mode to the actual report; do not promise that all checks
  will pass.

  Invoke `ask_user` with this shape, adapting the question and localizing its text:

  ```json
  {
    "question": "Fix the reported issue in a working copy and revalidate with the same mode?",
    "choices": ["Fix and revalidate", "Not now"]
  }
  ```

  - An affirmative selection is repair authorization: continue to step 6 immediately, retaining
    this report/project/environment. Do not ask the user to type the choice or confirm again.
  - “Not now”, dismissal or cancellation: finish with the report available and files unchanged.
    Do not start repairs, choose on the user's behalf or repeatedly ask.
  - Collect source project/build environment only when using the source-build path.
    For ZIP-only or listing-only repair, ask only for required business information/assets.
  - Only if the tool is unavailable or interaction is disabled, and the user's requested response scope permits it,
    end with a localized text fallback: “Reply ‘Fix and revalidate’ to continue.”
    This fallback does not authorize repair. Do not imitate an interactive selector
    with Markdown checkboxes, invoke `Read-Host` or start another CLI to collect the choice.

- **No selected repair work or only blockers:** Give the applicable next action or missing input
  (such as service access, listing or screenshots), without promising automatic source repair.
- **Repair already authorized:** Continue to step 6 rather than asking for the same permission again.

Source/package/listing edits and revalidation require an explicit repair request or affirmative choice.
ZIP-only authors may use the bounded repair-package helper; do not ask them to invent a
source project or build environment. Listing-only repairs do not require a new ZIP.
Explain which path applies before collecting the decision.

## 6. Fix only when authorized

Retain the result, selected mode, project/environment and, when applicable, returned report paths,
absolute ZIP path/hash, supplied listing
and any confirmed source-project/build-environment context for a follow-up. Validation alone does
not authorize source edits; use step 5's native choice when repair is actionable.

When repair is authorized, read [autofix](../references/validate/autofix.md) and execute its entire loop:
scoped source edits → source recheck, or explicit new ZIP → fresh Marketplace evidence → same-mode
`agent validate` → verified progress and remaining findings. `validation` owns that loop.
