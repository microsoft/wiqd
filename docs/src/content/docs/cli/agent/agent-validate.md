---
title: wiqd agent validate
description: Check saved source offline, validate a final package, or assess Marketplace readiness.
---

`wiqd agent validate` checks saved source, a final ZIP, or Marketplace readiness:

| Mode | What is checked | Inputs and effects |
| --- | --- | --- |
| `source` | Saved `appPackage/declarativeAgent.json` | Offline, no sign-in, ZIP, build, upload or report directory; checked files and diagnostics are returned. |
| `package` (default) | A captured final ZIP through Teams Developer Portal (TDP) | Existing ZIP required; uploads a read-only temporary copy and may require sign-in. |
| `marketplace` | Package validation **and** StoreOps policy checks on the same captured ZIP | Optional listing/current-host evidence; unavailable selected checks remain incomplete. |

```bash
wiqd agent validate --mode source --path ./my-agent --env local
wiqd agent validate --mode package --package-file ./final.zip
wiqd agent validate --mode marketplace --package-file ./final.zip --listing-file ./listing.json
```

Validation never builds, edits, provisions or publishes. A passing source check is not final-ZIP
acceptance, and a passing package/Marketplace result is not official certification.

## Source checks before a build or deployment

Select source explicitly for the offline authoring loop and CI. Use the same project/environment
as the lifecycle operation:

```bash
wiqd agent validate --mode source --path ./my-agent --env dev --json
wiqd agent package --path ./my-agent --env dev --output ./final.zip
wiqd agent validate --mode package --package-file ./final.zip --json
```

Run each command only after the preceding command succeeds. Source checks saved
`appPackage/declarativeAgent.json`, not unsaved editor buffers or the whole project.
`--env` defaults to `local` and limits context to that environment. Missing deployment-generated
IDs are advisory; do not invent values before provisioning.

Source inputs and references must stay within the selected project's canonical root;
links or traversal into external files are rejected without reading their contents.
Snapshots are limited to 4 MiB per file, 16 MiB total and 128 files. A selected project
alias is supported and its canonical root is returned in the result.

Use source checks before packaging or provisioning. Provision builds its own upload;
a source pass does not prove that a later upload uses a previously validated ZIP.

## ZIP selection and options

Use `--package-file` to select the exact ZIP; a relative path is relative to the current working
directory. Without it, `--path` (CWD by default) must contain exactly one nonrecursive
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

For reviewed independent conversational scenarios, `--functional-batch` collects
all questions in one shared structured request. Omission keeps individual collection.
The plan is saved first; raw transport and complete ID-bound answers remain local.
The evaluator is told the answers share a batch context, not isolated interactions.
Dependent scenarios and MCP packages are unsupported. No retry, split, truncation
or individual-request fallback is performed.

The aggregate prompt must fit 12,000 characters and the platform argument limit.
The entire JSON reply must fit 64,000 characters, each answer 16,000 characters;
existing deadlines, 256 KiB evidence and 1 MiB subprocess-stream limits remain.
Missing/duplicate/foreign IDs, extra prose/fields and malformed or oversized replies
make the whole batch unavailable, not a policy violation.

`--functional-batch-allow-duplicate-json` is off by default and requires batch mode.
It accepts only exactly two character-identical complete valid JSON documents,
within the same raw-response limit. The original doubled text/digest are retained;
`responseNormalization: exact-double-json` and the validated copy's digest bind
the normalization. Replay verifies the raw reply and its projections. Different
documents, extra copies/text or invalid IDs remain failures. Ordinary `agent ask`,
individual and MCP responses are not changed, nor are old failed captures.
The internal request helper accepts both options only for initial collection;
final replay omits them, the ID and timeouts and reuses the exact evidence.

## Marketplace listings

In a coding-agent session, ask to validate your package for Marketplace. The workflow
reuses a valid `.validate/listing.json`, or collects missing information and asks you
to review the complete listing HTML before validation. Saving a listing does not
publish it or establish a passing result.

For direct CLI use, inspect the writer's required fields, then read or preview a saved listing:

```bash
wiqd agent validate add-market-listing --help
wiqd agent validate get-market-listing --agent-folder ./my-agent --json
wiqd agent validate preview-market-listing --agent-folder ./my-agent --json
```

All three helpers require `--agent-folder`. They preserve the original ZIP and source
assets; the writer creates managed listing copies. Reading and previewing do not run validation.

## Results and JSON

With `--json`, stdout contains only the shared JSON envelope; diagnostics/progress use stderr.
Progress reports activity, not passing checks. Use `--log-level none` to suppress it, or
`--log-format text` for readable progress alongside JSON output.
Read success `data` or completed non-pass `error.data`. Data contains `validation`, `source`,
`manifest` and `report`; inapplicable provider objects are null.

**`validation.result` is the overall verdict**, not policy-only `report.result`:

- `FAILED`: confirmed blocking findings, even if other selected work is incomplete.
- `ERROR`: no confirmed blocker, but selected validation could not complete.
- `PASSED`: all selected checks completed without blocking findings. Warnings do not block.

Source returns checked files and diagnostics with codes, severity and locations.
JSON locations are zero-based, like LSP; table locations are one-based. It has no ZIP
identity or HTML link. Package/Marketplace atomically publish immutable results and captured
inputs under `~/.wiqd/validation/reports/<run-id>/`. Use returned `validation.reportPaths` and
`validation.inputPaths`, not guessed paths. Package data remains in `manifest.json`; Marketplace
policy data remains in `report.json`. Filenames and their schemas are unchanged.

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
| 1 | Findings, incomplete work, invalid input or report-publication failure. |
| 2 | Missing runtime/native/configuration dependency or invalid source project. |
| 130 | Cancelled; no completed report is published. |

## Coding-agent validation and repair

“Validate my agent” selects source; a supplied ZIP selects package; Marketplace readiness
selects Marketplace, including package checks. Account setup and publication are separate workflows.

When Marketplace readiness leaves live-testing scope unspecified, the coding agent
first offers **Package and Marketplace checks without live target calls.** or
**Include live functional/connector testing, subject to eligibility.** and waits
before listing commands or evidence preparation. Explicit selections and supplied
evidence replay are not reconfirmed; missing confirmation stops instead of defaulting.
Choosing live does not replace eligibility checks, bounded-call approval or any
required upload, installation, authentication and connector Allow handoffs.
Direct CLI commands do not gain this interactive prompt.

Marketplace listing reuse/collection includes one complete HTML review before validation. The
current coding-agent session prepares request-bound evidence and replays with AI off.
Without an authorized target ID, preparation never starts a model or target collector.
An authorized ID permits the shared planner/collector once; final replay forwards its
exact evidence file, not the ID or collection timeouts, so it never repeats target calls.
Independent current-host assessment does not start a nested evaluator.
Validation alone does not authorize repair. “Fix and revalidate” permits
targeted changes and same-mode verification. Source repair reruns source without building
or demanding HTML; package repair builds an explicit new ZIP, and Marketplace refreshes evidence.
Missing input/service access stays blocked, not a fabricated pass.
The coding agent reports the verification outcome without exposing internal
evidence/revalidation commands or asking you to repeat completed work. Exact
commands are available on request, or when needed for an actual next action.

Findings show **AI-fixable**, **AI-fixable · Needs your input**, or **External action
required**, with policy-specific reasons. Capability is not consent, readiness or a
guaranteed pass. Incomplete checks remain unverified; old reports without metadata
say **Repairability not recorded**. Purple AI-fixable and blue-gray external-action
badges retain their meaning through text, not just color or decorative emoji.

After showing actionable findings, the coding agent offers **Fix and revalidate** /
**Not now** using its native choice tool. Decline/dismissal leaves files unchanged.
Report-only requests skip the choice. Explicit repair needs no repeated authorization.

Before making any repair, the coding agent reviews all selected findings and collects
all missing repair inputs together. Shared values are asked once; applicable answers
already supplied are reused. A single questionnaire lets you fill each field before
submitting the group. If the host cannot show that form, it presents the full question
list and collects your replies without making changes between answers.
Only after every required input is supplied and usable does it apply the fixes one by
one, then run the original mode's verification sequence for the group. Direct fixes
also wait for this input collection to finish. Missing or cancelled answers leave the
round blocked and files unchanged. A genuinely new dependency can require a follow-up,
but known questions are not deferred until after editing.

Source-build repair requires the actual project/environment and source precheck.
ZIP-only authors can instead prepare explicit replacements and create a new ZIP
without a fabricated project/environment; original source is not synchronized:

```bash
wiqd agent validate repair-package --package-file ./original.zip --changes-file ./changes.json --output ./repaired.zip --json
```

The changes file contains `packageSha256` and
`replacements: [{ "path": "manifest.json", "contentPath": "./edited-manifest.json" }]`.
The helper preserves original/untouched bytes and rejects unsafe archive paths,
stale hashes, changed app identity, no-op changes and existing output files.
It does not validate, publish or prove repair success. Listing/evidence-only repair
keeps unchanged ZIP bytes and requires neither source nor a build. A rebuilt ZIP
needs an applicable user-confirmed working listing binding, preserving approved
fields/assets; retained listing/evidence are never rewritten or silently dropped.

Marketplace revalidation supplies `--repair-context` with `previousReportPath`,
`previousReportSha256`, normalized provider `modes: ["manifest", "marketplace"]`, and
actual `changes: [{ "subPolicyNumber": "...", "summary": "..." }]`. The hash covers
the exact preceding report.json. Missing/mismatched inputs or changed modes fail.
**Passed after repair** appears below passed policies as a subset, not another count.
It links prior failures, recorded changes and current comparable passing checks
across the explicit chain. Partial repairs, removed checks, inconclusive results
and regressions are not counted as fixed. Old reports remain unchanged and unrelated
history is not searched. At most two repair rounds run; pending replay is applied
but unverified work, never PASS or official approval.

## Upgrade from older validation commands

Only `source`, `package`, and `marketplace` are accepted. Old agent modes are rejected with
migration guidance, not treated as aliases:

- Old offline `static` use → explicitly choose `--mode source`.
- Old package `deep` or `manifest` use → explicitly choose `--mode package` and the final ZIP.
- Old combined selections → `--mode marketplace`, which already includes package checks.

Upgrade the CLI and host plugin to compatible releases, update the plugin through its native
marketplace, and start a **fresh host session**. A CLI update/extension registration alone does
not refresh host guidance. `wiqd plugin validate` shares these modes, options, runtime and reports;
its source mode adds plugin project guards and explicitly reports when no DA source is present.
`wiqd agent lsp` retains the editor protocol entry.
