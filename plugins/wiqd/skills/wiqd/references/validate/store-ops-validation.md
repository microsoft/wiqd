# Store Ops Pre-Submission Audit

**Telemetry:** `--skill wiqd` on every `wiqd` command.

> 📐 **Design note — this is a skill, by design, not a CLI flag.** A `wiqd agent validate --certify` flag was explored and explicitly rejected: the deterministic half of the rule registry is federating to Teams Developer Platform (TDP) server-side validation APIs, so investing in a C# rule engine inside `wiqd-validate` today would become a sunk cost within ~6-12 months. This skill is the v1 surface and the durable artifact is the rule registry itself.

Audit a built declarative-agent app package (`.zip`) against the publicly-documented Microsoft Store / Commercial Marketplace / Teams Store / Copilot agent review policies **before** Partner Center submission.

This is the bridge between `wiqd agent validate` (schema-level, runs today) and `wiqd agent review` (six human compliance gates). It catches the policy-level rejections that store-ops actually issues: missing privacy URL, banned branding, prohibited domain wildcards, prompt-injection patterns in instructions, missing AI disclosure, invalid icons, unsafe URLs.

## When to use

Run after `wiqd agent package` produces a `.zip`, before submitting to Partner Center / AppSource. Typical triggers:

- "Run a store-ops check on my package"
- "Will my agent pass review?"
- "Pre-submission audit"
- "Marketplace / Teams Store / AppSource validation"
- "Is my agent ready to publish?"
- "Generate an evidence report for Quality / Security / RAI / Tenant-Trust review"

Do **not** use for:

- Schema-only validation → run `wiqd agent validate` through the active backend's validation reference
- Compliance gate workflow → the agent-review reference (six human gates)
- Eval-time runtime checks → the eval extension

## Inputs

| Input                              | Required          | Notes                                                                                                          |
| ---------------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------- |
| Path to a built `.zip` app package | Yes               | If only a project path is given, run `wiqd agent package --skill wiqd` first to produce the zip, then proceed. |
| Target store                       | No (default: all) | `marketplace`, `teams`, `appsource`, `all`. Some rules are store-specific (see `store-ops/rules.md`).          |
| Network reachability checks        | No (default: yes) | Disable for offline / air-gapped runs.                                                                         |

## Preconditions

1. The package validates clean via `wiqd agent validate --skill wiqd` (this skill assumes a build that already passes schema validation — do not duplicate that work here).
2. The TeamsFx-style `${{...}}` placeholders inside `manifest.json` have already been substituted by `wiqd agent package` / `wiqd agent provision`. Packages with unsubstituted placeholders surface as one Must-fix submission-readiness finding rather than dozens of cascading failures.

## Workflow

A **single linear pass** through 17 rule categories. Run them in order so earlier failures don't pollute later results.

### Step 1 — Confirm scope

Ask the user (or accept from invocation):

1. Path to the `.zip` (or project root — offer to run `wiqd agent package`).
2. Target store(s). Default: all three.
3. Whether to perform network reachability checks. Default: yes.

Skip the prompt if the user already specified scope.

### Step 2 — Extract the package

Extract to a temp directory and walk the contents. Per the [Teams app package contract](store-ops/references.md#teams-store-validation-guidelines), required entries are:

- `manifest.json` (root)
- Color icon PNG (referenced by `icons.color` — typically `color.png`)
- Outline icon PNG (referenced by `icons.outline` — typically `outline.png`)
- One declarative agent JSON file referenced by `copilotAgents.declarativeAgents[].file`
- Optional: additional language JSON files referenced by `localizationInfo.additionalLanguages[].file`
- Optional: API plugin JSON + OpenAPI YAML/JSON referenced by `copilotAgents.declarativeAgents[].actions[].file`

Record every entry. Flag any file that is not referenced from the manifest tree (rule **P6**).

### Step 3 — Run the rule registry

Open [`store-ops/rules.md`](store-ops/rules.md) and evaluate every rule, in category order. For each rule:

1. Read the rule's **How to check** hint.
2. Use file inspection, regex search, or a small `node` / `pwsh` snippet to evaluate.
3. Record one of: `pass`, `fail`, `warn`, `skip`. Every skip MUST include the
   rule severity, applicability, and reason defined by
   `store-ops/report-template.md`; a Must-fix skip that is applicable or whose
   applicability is unknown is blocking unless it carries explicit human
   approval evidence.
4. On `fail` or `warn`, capture: the offending value, the file + JSON pointer (e.g., `declarativeAgent.json#/instructions`), the rule ID, and the policy citation.

**Severity model:**

- **Must-fix** — Microsoft-listed rejection reason or required by the manifest schema. A single Must-fix → audit fails.
- **Good-to-fix** — strongly recommended but not always rejection-causing. Audit can pass with Good-to-fix warnings present.

### Step 4 — Network reachability (optional)

If enabled, `HEAD` each developer URL (`websiteUrl`, `privacyUrl`, `termsOfUseUrl`) and treat non-2xx/3xx as a **Good-to-fix** warning (rules U1–U4). No other outbound calls.

### Step 5 — Render the report

Render [`store-ops/report-template.md`](store-ops/report-template.md) in three output formats — every audit run emits all three side by side unless the user opts out:

| Format       | Default file written        | Audience                                                                                          |
| ------------ | --------------------------- | ------------------------------------------------------------------------------------------------- |
| **Markdown** | `<zip-name>.store-ops.md`   | humans reviewing in a terminal, PR, or docs site                                                  |
| **HTML**     | `<zip-name>.store-ops.html` | humans who prefer a styled, single-file report (no external deps, light/dark aware, anchored TOC) |
| **JSON**     | `<zip-name>.store-ops.json` | automation, CI, dashboards                                                                        |

Every human-readable format (Markdown + HTML) MUST include:

- Executive summary (pass/fail, counts by severity with 🔴 / 🟡 / ✅ / ⏭️ markers)
- An "About the rule codes" callout near the top explaining that codes like `B1`, `M6` are this audit's **internal taxonomy** from `store-ops/rules.md` — they are NOT Microsoft-published error codes
- Must-fix findings table with a **Title** column (the human-readable rule summary) next to every rule ID
- Good-to-fix findings table (same shape as Must-fix)
- Skipped checks table with a reason for every skip
- Passed checks list (collapsed by default to keep the report scannable)
- A **Rule Code Index** section at the bottom listing every rule evaluated in this run, grouped by category, with category-letter legend (P, M, B, I, D, A, X, K, S, L, R, W, U, C, N, F, G)

The Markdown is rendered to stdout by default. All three files are also written next to the input zip so the developer can attach the HTML or JSON to a review thread.

### Step 6 — Decision

- **Pass** — no Must-fix failures and no blocking Must-fix skips. Output: `READY FOR SUBMISSION (with N good-to-fix notes)`.
- **Fail** — ≥1 Must-fix failure or blocking Must-fix skip. Output: `NOT READY — fix the Must-fix items or complete/approve the blocked checks, then re-run`.

### Partner Center workflow gate

When this audit is invoked from a Copilot workflow immediately before a **Partner Center / public Marketplace submission**, it is a fail-closed workflow gate:

1. Audit the final packaged `.zip` that would be submitted, not project source or an earlier package.
2. Produce the JSON report defined in `store-ops/report-template.md`. Derive the authoritative rule-ID set from the bold IDs in `store-ops/rules.md`; require `data.rulesVersion`, `data.rulesCount`, and `data.rulesIdentity` to match that registry, and require every registry ID to appear exactly once across `data.passed`, `data.findings`, and `data.skipped`. Unknown, missing, or duplicate IDs make the report incomplete. Require every skipped record to include `severity`, `applicability`, and `reason`, and verify all result counts are internally consistent.
3. Treat a skipped Must-fix rule as blocking when `applicability` is `applicable` or `unknown`, unless its `approval.status` is `approved` and its approver, timestamp, and evidence are all recorded. A Must-fix skip is non-blocking without approval only when `applicability` is `not-applicable` and the reason explains why the rule's activation condition is absent.
4. Stop the Partner Center workflow when the report is missing, malformed, or incomplete; when `data.result.mustFailCount > 0`; when `data.result.blockingSkippedCount > 0`; or when `data.result.label == "fail"`. Present the Must-fix findings and blocked checks, then offer to re-run the audit after correction or approval.
5. Continue only when `data.result.label == "pass"`, `data.result.mustFailCount == 0`, and `data.result.blockingSkippedCount == 0`. Surface every Good-to-fix finding, non-blocking skip, and manual approval before the user confirms the submission.

This gate applies only to Partner Center / public Marketplace submission. Do not run it as a prerequisite for tenant LOB or org-catalog publish, sideloading, or ordinary audience/ring sharing. The gate protects agent-mediated workflows; direct CLI and portal actions remain outside this Phase 1 guardrail.

When invoked from a script wrapper, exit codes follow the wiqd conventions:

| Code  | Meaning                                                      |
| ----- | ------------------------------------------------------------ |
| `0`   | Pass — no Must-fix failures or blocking Must-fix skips       |
| `1`   | Fail — one or more Must-fix failures or blocking skips       |
| `2`   | Audit could not run (bad zip, missing `manifest.json`, etc.) |
| `130` | Cancelled                                                    |

## Output sample

```
DA Store Ops Audit — myagent.zip
  Target: marketplace, teams, appsource
  Rules accounted for: 138

  ✗ FAIL — 2 Must-fix, 4 Good-to-fix, 132 pass

  Must-fix:
    M3  manifest.json#/name/short          "Microsoft Helper" contains a banned brand term ("Microsoft")
    A7  declarativeAgent.json#/conversation_starters  count=2 (minimum 3 required)

  Good-to-fix:
    U2  privacyUrl not reachable (HTTP 404)
    B5  description.full mentions "#1 agent" (avoid superlative marketing claims)
    ...

NOT READY — fix Must-fix items, then re-run.
```

## What this audit is NOT

- **Not a replacement for `wiqd agent validate`.** Run that first.
- **Not a replacement for human review gates.** RAI / Privacy / Tenant Trust still require human reviewers via the agent-review workflow.
- **Not a runtime / latency check.** Use the eval extension for response-quality and latency budgets.
- **Not authoritative for §1140.x rule numbering.** Microsoft renumbers sections periodically. Always cite URL + heading and check `last_validated` in [`store-ops/references.md`](store-ops/references.md).

## Maintenance

- Update [`store-ops/references.md`](store-ops/references.md) `last_validated` when you re-verify the source URLs.
- Add or remove rules in [`store-ops/rules.md`](store-ops/rules.md) when the public policies change. Rule IDs are **stable and append-only** — never renumber. Tombstone deprecated rules in place.
- Each rule has an explicit citation field so reviewers can confirm the source.

## See also

- `wiqd agent validate` — schema-level validation through the active backend.
- `wiqd agent package` — how `.zip` packages are produced through the active backend.
- [`store-ops/rules.md`](store-ops/rules.md) — the rule registry (the meat of this audit). Scope: declarative agents only; custom-engine agents (CEAs) are out of scope.
- [`store-ops/report-template.md`](store-ops/report-template.md) — Markdown + HTML + JSON output contract.
- [`store-ops/references.md`](store-ops/references.md) — policy sources, URLs, and validation dates.
