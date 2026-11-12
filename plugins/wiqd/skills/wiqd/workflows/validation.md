---
name: validation
description: Validate saved source, packages and Marketplace listings; prepare a missing development target for explicitly requested live checks, and repair findings when authorized.
trigger-summary: 'validate my agent, check source, validate package, Marketplace validation, fix validation findings'
triggers: 'validate my agent, validate source, check my manifest, fix my agent manifest, validate package, validate this package, validate this ZIP, check this ZIP, validate package for marketplace, run live functional validation, live functional validation, functional validation, interpret my validation report, partner center validation, partner center validate, marketplace validation, marketplace validate, validate for partner center, validate for marketplace, fix validation findings, fix this validation report, validate and fix this package, validate and fix my agent'
routing-label: 'Agent source / package / Marketplace validation and repair'
routing-intent: 'Explicitly validate source, a final ZIP or Marketplace readiness, run live functional checks, or repair validation findings; not general authoring, account setup or publication'
routing-order: 10
contract-version: 1
routing-requires: [plugin validate]
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
CLI installation/registration does not refresh host skills.
Missing commands or rejected current modes are upgrade blockers: report them, do not
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
call default validation as a pre-build gate. Package with an explicit output path and use the
returned `data.outputPath`, not the newest ZIP.
Old `static`, `deep`, `manifest` and comma-combined modes are rejected with migration guidance;
do not retry them or invent aliases.

For source or package mode, explicitly show the orchestrator's caller/default marker
before any plan or input question, including plan-only requests. Do not reuse a
Marketplace marker from an earlier request or mode.

### Marketplace journey navigation

When the resolved mode is `marketplace`, replace the orchestrator's default journey
marker with this high-level Marketplace publication journey:

`📍 Build → Provision → **Validate** → Publish`

Render it as normal Markdown with Validate highlighted, not as a code block. Show
this single marker before the startup overview and any intake questions; do not
also show the default marker or replace this roadmap with the detailed validation steps.
Keep it during this Marketplace invocation, including no-live checks, supplied-evidence
replay and same-mode repair. Source/package-only validation and org publishing do
not select this override; retain their caller/default navigation. Restore that
navigation when this invocation returns or the mode/request changes.

The marker describes the customer's high-level Marketplace publication goal, not
executed steps or new authorization. Do not infer that Build or Provision completed,
provision a target or publish because those stages appear here. All existing source
prechecks, scope/target approvals, live-testing and publishing boundaries still apply.

### Marketplace startup overview

For a new Marketplace request, show a short overview once, in the user's language,
before any scope, ZIP or listing questions or any listing, evidence or validation commands.
Use the steps below, adapting the optional live-testing step to any already explicit
live/no-live or supplied-evidence scope. Source/package-only requests and repair
continuations skip this overview.

Show this overview immediately after the Marketplace journey marker, not instead of it.
Render the overview as a numbered list with one item per step, not a single paragraph.
For an English response, keep these five labels verbatim and in this order; do not
rename or merge them. Translate the labels when responding in another language.

1. **Collect listing information**: Reuse a valid saved listing or collect the needed details,
   then show an HTML preview for your confirmation.
2. **Authorize functional testing**: Confirm eligibility, the target and required approvals
   for selected live checks. Skip this step when live testing is not selected.
3. **Wait for validation to complete**: Run the agreed checks in the background and wait on
   the same job, including only eligible live checks you selected and approved.
4. **Auto-fix issues and re-validate**: Explain fixable findings, apply supported fixes and
   re-validate only with your authorization; otherwise skip this step.
5. **Review the validation report**: Review the final HTML report with passed, failed and
   incomplete checks, remaining findings and next steps.

Initial scope/ZIP selection and the live/no-live choice below remain prerequisites
before listing commands. Stage 2 covers separate approvals for selected functional
checks, not a second scope choice. Initial findings may be shown before repair
permission; stage 5 reviews the final report after authorized repair/revalidation
or its skip. Do not repair by default or delay explaining findings until after repair.

Say that this workflow does not publish the app. The overview explains the plan; it is not
consent for uploads, installation, target calls, repairs or publishing. Do not add a separate
confirmation; continue to the existing scope choice or the already selected path.

### Marketplace live-testing choice

Before any Marketplace listing command, evidence preparation or validation, resolve
live/no-live scope. For a Marketplace or Partner Center readiness request that does
not explicitly select live or no-live checks, use the native choice tool
(`ask_user` in Copilot) with these two choices and **wait for the answer**:

```json
{
  "message": "Which Marketplace validation scope should run? Live testing remains subject to eligibility and separate required approvals; neither option publishes.",
  "requestedSchema": {
    "properties": {
      "scope": {
        "type": "string",
        "title": "Validation scope",
        "enum": [
          "Package and Marketplace checks without live target calls.",
          "Include live functional/connector testing, subject to eligibility."
        ]
      }
    }
  }
}
```

Do not silently default to no-live checks. Readiness-only wording, "do not publish",
an unpublished app, a missing agent ID or a missing listing do not resolve this choice.
If the native tool or confirmation is unavailable, or the user dismisses or cancels
the choice, stop before listing commands, evidence preparation or validation and
report that scope remains unconfirmed.

Reuse explicit live/no-live instructions or a choice already recorded for this
request; do not ask again. Source/package-only, offline, explicit AI-off, mock and
supplied functional-evidence replay requests retain their explicit scope without
this prompt. Repair continuation keeps the original selection unless the user
explicitly changes it.

The first choice keeps Marketplace mode, including package uploads, without new
target calls or development-target preparation. The second choice establishes
live intent only, not eligibility or permission to upload/install, change auth or
complete connector Allow. Preserve the separate bounded-call and target approvals
below. If live checks are ineligible or blocked, report the blocker; do not silently
substitute no-live validation.

**Live functional intent:** Only explicitly requested live functional checks, including
the confirmed live choice above, need a runtime
target. Marketplace validation alone, an unpublished app, static/offline checks and supplied
functional-evidence replay do not authorize deployment. Explicit AI-off or mock requests do not
prepare a target; report incompatible live options instead of overriding them. Preserve the selected
modes, original ZIP/hash, listing and requested call/time budgets. A missing store listing is
not proof that a personal development target is absent.
For explicit live checks, an existing agent ID is optional: reuse one already supplied or
verified; otherwise default to local development-target preparation. Do not ask for an
agent ID or whether the user has one as an initial required field.
Choosing live means preparing a missing execution target, not requiring the user
to create a DA first: reuse a DA package or create a separate DA host for an
eligible MCP connector through development-target preparation. This is not a
generic conversion of every non-DA plugin.
For an explicitly approved public-example connector test, a single root MCP
connector with skills, tabs or compose extensions can use a separate minimal DA
host. Include its equivalent MCP action and required metadata/icons/tool file,
not unrelated app surfaces or assets; keep the original ZIP unchanged.
Do not ask the user to author a DA or strip package features. The connector test
does not cover omitted functionality. Unsupported or ambiguous input, missing
auth prerequisites and refused approvals remain target blockers, not a
requirement to publish first.
A target blocker does not prevent collecting and confirming the Marketplace
listing. Continue that independent work with the user, retaining the selected live
scope; do not run validation without its required target or imply readiness.

### Marketplace listing

Source and package skip collection. For Marketplace, ask the CLI to read the listing
from `<collection-workspace>/.validate/listing.json` using the command below. The collection workspace is
the known agent project, or the supplied ZIP's directory/ZIP-only folder.

```bash
wiqd plugin get market-listing --agent-folder "<collection-workspace>" --json --skill wiqd
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

Live connector tests use inspect/plan, one authorized execution, then independent
receipt and answer verification. Public-example selection remains the default
explicit connector profile. If it cannot establish a safe operation, preserve
the limitation rather than retrying. A separately approved reviewed-operation
plan can name concrete public or pre-existing synthetic-fixture inputs; follow
[the evidence guide](../references/validate/current-agent-evidence.md) before adding
`--connector-plan-file`. No sandbox creation, private customer data or write
permission follows from validation approval.

For source:

```bash
wiqd plugin validate --mode source --path "<project>" --env "<environment>" --json --skill wiqd --workflow validation
```

For package:

```bash
wiqd plugin validate --mode package --package-file "<final.zip>" --json --skill wiqd --workflow validation
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
Before either connector host-generation command, follow
[Choose connector authentication](../references/validate/development-target.md#choose-connector-authentication).
Preserve valid ZIP-provided auth. If auth is omitted and unresolved, ask one
neutral question offering confirmed no-auth, confirmed OAuth DCR, a replacement
ZIP with valid auth information, or unknown/pause, and wait for the answer.
Do not offer only DCR because an example uses it, including Success.co.
Keep this choice separate from request-derived public-example authorization and
installation approvals. An explicit live-validation request authorizes one bounded
public read-only example by default; do not ask separately to allow the lookup.
Static/package-only requests do not authorize live calls, and native tool
permission prompts remain human-owned.
Standalone connectors with a concrete existing `OAuthPluginVault` or
`ApiKeyPluginVault` reference may use the authenticated preparation branch.
Preserve the reference and use that request-authorized bounded public-example scope;
do not collect credentials, infer DCR, create registrations or replace declared
auth with `None`. Registration compatibility and service access remain external
prerequisites, not results established by conversion.
For an explicitly selected omitted-auth OAuth-DCR connector, reuse a suitable
existing source host first. Otherwise follow development target preparation to
compose a minimal source host with `plugin create`, bare `plugin add agent`,
then `agent add action` using the inspected MCP URL and explicit `oauth-dynamic`.
Use only supported existing parameters, without removed connector-package or
template-selection options. Retain and verify the original-ZIP binding and
generated-source hashes in the local preparation record.
Separate approval names app creation, DCR
registration, validation uploads and personal installation before source provision.
Never infer DCR from missing auth, replace declared auth or downgrade to `None`.
Source-provision failure retains state without automatic retries or ZIP reconciliation.
For successful source provision, retain public `data.titleId`, `data.deepLink`
and `data.chatLink`;
verify the app/OAuth identity from the retained environment and actual built
manifest as described in development target preparation. Do not require the
internal adapter's fields or reprovision to obtain them. A prior successful
result blocked only by that field mismatch resumes from saved evidence after
the same read-only verification, never from another installation.
Treat source provision's `data.titleId` and the remote card's opaque `data.agentId`
as separate identities. Work IQ's remote `wiqd agent show --id <id>` lookup
(or `--name <name>`) does not expose installation-title metadata;
missing `titleId` or a different agent-ID prefix is not a mismatch and must not
force another installation or title-derived ID. For this workflow's live
connector readiness check and every initial, continued or retried capture,
**use only a verified full runtime agent ID beginning with `T_`**. Apply
development preparation's
[connector live target ID](../references/validate/development-target.md#connector-live-target-id)
check before a helper invocation or copyable retry command, including
**Run live test with existing auth**. Do not issue or print a live retry command
with a `U_`/`P_` ID. Resolve automatically before asking for a runtime ID:
reuse a verified `T_` receipt/card or follow the development guide's filtered
post-provision lookup. Match the complete saved provision title and resolved app
name, not the first same-name row, then verify the exact full returned ID.
An unresolved initial lookup retains the two-link manual setup; explicit
completion permits one confirmed-install metadata refresh before an ID question,
not automatic polling or another installation. Retain a non-`T_` card/host but
pause to resolve the actual installed `T_` runtime ID; never replace prefixes, build it from a title/app GUID
or guess a component suffix. A changed target requires exact-ID verification,
renewed caller association and a separately bound plan, not rewritten old
plans or reused observations. Preserve completed same-installation
authentication, approved operation/inputs and budgets. Missing/conflicting
identity blocks live calls without reinstallation; explicit non-live or cancel
remains available. Generic Work IQ commands, ordinary conversational validation,
direct native CLI calls and no-call replay retain their existing ID contracts.
Carry only an eligible verified `T_` lookup candidate to the
existing setup question and obtain explicit caller confirmation of its
target/installation/original-ZIP association when not already supplied.
Record that binding as **caller-asserted**, not service attestation, before
request preparation. Actual conflicting evidence or unconfirmed association
still blocks live calls. A different exact runtime agent ID displayed in the
opened installation is conflicting evidence, not just a title-prefix difference.
Stop collection, discard the prior association (not its retained artifacts), and
follow development target preparation's exact-ID verification and renewed
association confirmation. Never silently switch targets or reuse the prior
candidate's observations or bound plan for that different target.
Resume earlier missing-metadata/prefix blockers from
unchanged saved provision/card/setup evidence without repeating available steps.
After provisioning a connector DA host, always show both returned valid links
together: **Open agent in Microsoft 365 Copilot** (`data.deepLink`) and
**Chat install/test** (`data.chatLink`). Do this before the safe sample prompt
and readiness question, including verified recovery or reuse of saved success.
Follow development target preparation's explicit unavailable-secondary-link
branch when `chatLink` is missing/null; never invent or duplicate a URL or
re-provision to obtain one. Then follow development target preparation's
**connector Allow handoff**: the user opens Microsoft 365 Copilot, sends the
sample prompt and completes any Allow/input steps themselves. Wait for explicit
readiness confirmation through the native question tool before request preparation
or live collection. Installation approval alone is not readiness confirmation.
For authenticated connectors, the user also completes provider sign-in/consent
under the same M365 identity used by the collector. Missing keys or application
registration cannot be repaired merely by signing in through Copilot.
If setup names a concrete safe operation with known inputs, follow the evidence
guide to prepare and review the existing operation plan internally before
readiness confirmation. Do not show the complete plan or ask public-plan approval
before or after authentication/continuation. Use
`--connector-plan-file` instead of `--connector-scenario public-example` in request
preparation. Keep the original ZIP/hash, verified target, operation, inputs and
independent expected outcome; do not switch to a different tool after setup.
Capability-only setup retains the request-authorized public-example scenario without
invented operations or arguments.
After that explicit confirmation, proceed directly with the request-authorized
scenario or internally reviewed plan as
the first capture, then follow current-agent evidence's **post-auth connector
readiness gate** before independent assessment or final validation. Require
`data.connectorReadiness.ready === true` and the retained evidence path/digest;
The response-readiness gate requires a usable admitted agent response without an auth/consent/input
blocker, not successful MCP receipts. Missing or failed MCP execution alone does not
require authentication again: keep its diagnostic state unchanged and continue
independent assessment and final replay. Explicit connector-auth/sign-in requests,
no usable response, transport/service errors and incomplete tasks remain non-ready.
Do not add a separate probe, direct MCP call or second successful capture.
Non-ready results require the native four-way choice: **Fallback to non-live
tests**, **Continue live test**, **Run live test with existing auth**, or **Cancel**.
Name the actual sanitized readiness blocker and evidence basis, not an assumed
authentication failure. In the final summary, distinguish earlier blocked attempts
from the selected capture used by the report; a successful sampled operation does
not verify all advertised functionality or other packaged surfaces.
Continue waits for user-owned
setup and new confirmation authorizing one bounded attempt with unchanged
target, inputs, scenario and selected limits; it never reprovisions or retries
automatically. **Run live test with existing auth** instead authorizes one fresh
request-helper capture by the explicit choice itself, without another setup,
sign-in/Allow prompt, readiness question or plan display/approval.
Preserve the same account/tenant, target, ZIP/listing, scenario/operation/inputs
and selected limits; retain earlier attempts separately and check the new
response through the same readiness gate before assessment or replay, retaining
MCP receipt diagnostics separately.
This does not bypass native permissions, safety or integrity. If still non-ready,
offer the four choices again and wait; never retry automatically or reprovision.
Non-live fallback creates a fresh no-target request without
failed live evidence and discloses the incomplete live attempt. Cancel or an
unanswered choice stops final validation. Existing supplied-target and replay
paths do not acquire a new interactive gate.
For the finalized-ZIP branch only, include development target preparation's bounded read-only status recovery in
the scoped installation approval. If the first status check has a retained
transport/read or invalid-JSON/object/missing-body failure, follow that reference's
three-attempt recovery in this
session without another recovery question; never upload again. Continue on
verified success, preserving the connector Allow handoff; exhaustion and
non-retryable errors stop the live branch.
Require the reference's status-phase/error-code match and 10/20/30-second
recovery delays. Environment/upload failures and oversized status responses
remain stops, not reasons to enter or restart recovery.
When the user supplies a deployed agent ID for read-only functional testing,
or authorized ZIP/source provisioning returns its exact verified target and any required
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
Unresolved preparation auth, refused approvals, cancellation and target state
still inconclusive after the bounded status recovery stop this live branch.
Post-confirmation capture blockers use the explicit readiness recovery choice
above, not automatic retry; never
provision again as a collection-error recovery. Source repair/revalidation is not new deployment consent.
Keep the host job handle, report running honestly, and retrieve that same job's output on completion;
do not start a duplicate run to check status. Let the CLI report execution errors.

## 4. Show the result

Read `data` or completed non-pass `error.data`. Use `validation.result` for the overall result,
not the exit code or policy-only `report.result`. For source, show checked files and actual
diagnostic codes, severities and locations; there is no ZIP, output directory or HTML link to invent.
For a completed Marketplace run, no confirmed must-fix findings means PASSED when
package validation completed without blockers, even with unverified policy checks
or suggestions remaining. Keep those checks and counts visible; do not override the
native verdict or claim every check passed. Actual provider execution, input,
protocol and report-publication failures remain non-success. After repair, use
fresh revalidation, never edit success, to establish that must-fix findings cleared.
For package/Marketplace show required fixes, incomplete checks,
`validation.outputDir` and a clickable Markdown link to the returned `validation.reportPaths.html`.
Show full passed, failed and incomplete policy counts, then one concise table:
**Issue | Severity | AI repair | Next action | Validation status | Policy | Policy description**.
Preview at most the first **five distinct failed policies** and, independently,
the first **five incomplete policies**, retaining their canonical order; passing
policies need no detail rows. Count policies, not individual checks or wrapped lines.
For each category above five, state its full count and exact omitted count.
Use **Completed (failed)** or **Incomplete** in the status column, localized to the
user's language. Package diagnostics retain their actual code, severity and location;
do not invent policy identities or apply the policy limit to them.
Use each policy's `autofix.supported`, `autofix.mode` and `autofix.reason`, not a new
model classification. Say **AI-fixable**, **AI-fixable - needs your input**, or
**External action required**, localized to the user's language. Missing legacy metadata
means **Repairability not recorded**, not unsupported. Show missing inputs/current blockers
separately from capability. Incomplete/error rows in this same table are
unverified, not confirmed defects, even when the policy supports repair. Never edit an
app to hide an evaluator error. When repair is authorized, collect all known missing
repair inputs together before any fixes; combine policies sharing one field.
Use `[Open HTML report](file:///...)` with a standard URL-encoded file URI as the target.
Do not show only a bare path/URI or wrap the link in code formatting.
Completed FAILED/ERROR runs can still have saved reports; do not guess paths after execution failure.
The output directory also retains the evaluated ZIP and supplied listing.

Keep the explanation short; the HTML report contains the details. Do not rewrite results or
present partial validation as official Marketplace approval.
Make **Open HTML report** prominent as the place to see **all findings, AI repairability
and next steps**, including omitted policies. Use this same bounded summary after repair.
The preview never limits validation or repair selection: read the complete canonical report
when planning repairs, including policies not displayed.
Describe outcomes, not internal evidence-preparation or revalidation command transcripts.
Do not ask the user to repeat a command already executed. Keep exact invocations internally;
show them only when requested or necessary for a genuinely user-owned next action.
This workflow validates only; it does not change publishing workflows.

Recommend the next step: fix validation findings or incomplete checks after FAILED/ERROR.
After source PASSED, return to the previously authorized caller or continue authoring; do not
present source as final-ZIP readiness. After package/Marketplace PASSED, recommend the relevant
next lifecycle/publishing workflow with prerequisites unchanged, not an automatic submission.
A recommendation alone does not authorize edits or publishing.

## 5. Collect the repair decision

When called by a publishing workflow for advisory Marketplace policy checks,
return the actual result, report links and warnings to that caller after step 4.
Do not make policy repair or this repair-choice prompt a publishing prerequisite.
The caller still owns its independent source/package gates, authorization and
submission requirements; combined Marketplace results never hide package errors.
If the user explicitly requests repair, continue with the normal decision below.
Standalone validation keeps the same result and repair-decision behavior.

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
  - Include required source project/build environment in step 6's grouped input collection
    only when using the source-build path. For ZIP-only or listing-only repair, include
    only required business information/assets; do not collect inputs policy by policy here.
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
inspect all selected findings → collect all required repair inputs together → wait for
completed input collection → apply the planned fixes one by one → source recheck, or
explicit new ZIP → fresh Marketplace evidence → same-mode `plugin validate` → verified
progress and remaining findings. Do not edit or revalidate between user answers,
including for direct fixes that need no input. `validation` owns that loop.
