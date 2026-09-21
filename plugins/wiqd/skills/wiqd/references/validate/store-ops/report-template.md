# Report Template

The output contract produced by the store-ops audit. Every run emits:

1. A **console summary** (always to stdout).
2. A **Markdown report** rendered from the structure below — written to `<zip-basename>.store-ops.md` next to the input zip.
3. A **styled HTML report** (standalone, single file, embedded CSS, light/dark aware) — written to `<zip-basename>.store-ops.html` next to the input zip. See [HTML Output](#html-output).
4. A **JSON envelope** for machine consumption — written to `<zip-basename>.store-ops.json` next to the input zip. See [JSON Output](#json-output).

All three files are produced by default. A `--format md|html|json|all` flag (default `all`) lets the caller restrict the set, e.g. for CI that only needs the JSON envelope.

> **About the rule codes.** Rule IDs like `B1`, `M6`, `D2` are this skill's **internal taxonomy** from [`store-ops/rules.md`](rules.md) — they are **not** Microsoft-published error codes. Every human-readable report (Markdown, HTML, console) MUST surface the human-readable rule **Title** alongside the code and MUST end with a **Rule Code Index** explaining the category-letter system.

> **Template syntax used below:** placeholders are written as `<placeholder>` (angle-bracketed names the agent substitutes). Conditional sections are described in prose — e.g., "if there are no Must-fix findings, replace the table with the single line `_No Must-fix findings._`". Do NOT introduce Handlebars-style `#if` / `else` / `/if` markers (the doubled-curly form) in this file — the wiqd plugin-build merger reserves that syntax for build-time target conditionals (`1p` / `3p`) and will fail the build if it sees any other directive.

---

## Markdown Structure

A filled-out report follows this exact section order. The agent substitutes every `<placeholder>` and applies the conditional rules described in the captions.

````markdown
# Store Ops Audit — <package-name>

**Audit date:** <iso-8601-datetime>
**Package:** `<absolute-zip-path>` (<human-size>)
**Target stores:** <comma-separated list of: marketplace, teams, appsource>
**Rules version:** <date from store-ops/rules.md changelog>
**Network checks:** <enabled | disabled (U1–U3 skipped)>

> <❌ FAIL | ✅ PASS> — <N> Must-fix failure(s), <B> blocking skipped check(s) — <fix/complete/approve and re-run | ready for submission>.

## Summary

| Severity        |        🔴 Failed |        ✅ Passed |       ⏭️ Skipped |
| --------------- | ---------------: | ---------------: | ---------------: |
| **Must-fix**    |      <must_fail> |      <must_pass> |      <must_skip> |
| **Good-to-fix** |      <good_fail> |      <good_pass> |      <good_skip> |
| **Total**       | **<total_fail>** | **<total_pass>** | **<total_skip>** |

> **About the rule codes.** Codes like `B1`, `M6`, `D2` are this audit's internal taxonomy from the rule registry [`store-ops/rules.md`](rules.md) — they are **not** Microsoft-published error codes. Every code appearing in this report is explained in the [Rule Code Index](#rule-code-index) at the bottom.

## 🔴 Must-fix Findings

These are policy violations that will block store submission. Fix all of them before re-running.

If `must_fail > 0`, render this table — one row per finding. The `Title` column is the human-readable rule summary from [`store-ops/rules.md`](rules.md) and MUST always be present:

| Rule     | Title        | Location     | Evidence   | Citation                     |
| -------- | ------------ | ------------ | ---------- | ---------------------------- |
| **<id>** | <rule_title> | `<location>` | <evidence> | [<source_short>](source_url) |

Otherwise (no must-fix findings), replace the table with the single line:

```
_No Must-fix findings._
```

## 🟡 Good-to-fix Findings

Recommended improvements that won't block submission but reviewers may comment on.

Same rule: if `good_fail > 0`, render the table; otherwise emit `_No Good-to-fix findings._`.

| Rule     | Title        | Location     | Evidence   | Citation                     |
| -------- | ------------ | ------------ | ---------- | ---------------------------- |
| **<id>** | <rule_title> | `<location>` | <evidence> | [<source_short>](source_url) |

## ⏭️ Skipped Checks

If any rules were skipped, render (Title, Severity, Applicability, and Approval columns required):

| Rule     | Title        | Severity   | Applicability                           | Reason   | Approval                                        |
| -------- | ------------ | ---------- | --------------------------------------- | -------- | ----------------------------------------------- |
| **<id>** | <rule_title> | <severity> | applicable \| not-applicable \| unknown | <reason> | not-required \| blocking \| <approval_evidence> |

Otherwise emit `_All applicable rules were evaluated._`.

## ✅ Passed Checks (<passed_count>)

Collapsed by default — large lists hurt scannability. Wrap in a `<details>` element:

<details><summary>Expand the <passed_count> checks that passed</summary>

- **<id>** — <rule_title>
- **<id>** — <rule_title>
- ...

</details>

## Methodology

- **Schema validation:** assumed passing — run `wiqd agent validate --skill wiqd` first if you have not.
- **Network checks:** <enabled | disabled> (rules U1–U3 are skipped when `--no-network` is set).
- **Citations:** every finding links to its policy source. Refer to [`store-ops/references.md`](references.md) for the policy texts and last-validated dates.
- **Rule registry:** [`store-ops/rules.md`](rules.md) (changelog at bottom).

## Next Steps

Emit one of three blocks based on counts:

**Case A — `must_fail > 0`:**

```
1. Address every Must-fix finding above. Re-run this audit.
2. Once all Must-fix items pass, review Good-to-fix findings — fix the ones that apply.
3. Open the relevant review-gate work items via `wiqd agent review start`.
```

**Case B — `must_fail == 0` and `good_fail > 0`:**

```
1. Review Good-to-fix findings and decide which to act on (some are advisory).
2. Open the relevant review-gate work items via `wiqd agent review start`.
3. Proceed to publish via `wiqd agent publish` or your Partner Center workflow.
```

**Case C — `must_fail == 0` and `good_fail == 0`:**

```
1. Open the relevant review-gate work items via `wiqd agent review start`.
2. Proceed to publish via `wiqd agent publish` or your Partner Center workflow.
```

---

## Rule Code Index

Required section. Always rendered at the bottom of every human-readable report so the developer can decode any rule code they see above without leaving the page.

Rule IDs follow the pattern `<Category-letter><number>`. The letter identifies the category:

| Letter | Category                             |
| :----: | ------------------------------------ |
| **P**  | Package Structure                    |
| **M**  | manifest.json Schema                 |
| **B**  | Branding & Naming                    |
| **I**  | Icons                                |
| **D**  | Valid Domains                        |
| **A**  | Declarative Agent JSON               |
| **X**  | Anti-Prompt-Injection Content        |
| **K**  | Actions & API Plugins                |
| **S**  | SSO / webApplicationInfo             |
| **L**  | Localization                         |
| **R**  | AI / Responsible AI Disclosure       |
| **W**  | Worker Agents                        |
| **U**  | URL Reachability                     |
| **C**  | Identity & Publisher Consistency     |
| **N**  | Agent/Plugin Name Consistency        |
| **F**  | App Listing & Media (Partner Center) |

### Every rule evaluated in this audit

For each category that contributed at least one evaluated rule, render a per-category table:

#### Category <Letter> — <Category Name>

| Rule     | Title        | Severity                      |            Result             |
| -------- | ------------ | ----------------------------- | :---------------------------: |
| **<id>** | <rule_title> | 🔴 Must-fix \| 🟡 Good-to-fix | ✅ pass \| ❌ fail \| ⏭️ skip |

---

_Generated by the wiqd store-ops audit. The audit encodes publicly documented Microsoft policies and is not authoritative — store ops makes the final decision._
````

---

## JSON Output

The JSON envelope follows the `wiqd` JSON output-format contract: `status`, `command`, `data` for success; `status`, `command`, `exitCode`, `error` for failure. The `data` payload for a successful audit run is shown below. Its arrays are abbreviated for readability; a real report contains all 138 rule records.

```json
{
  "status": "ok",
  "command": "store-ops-audit",
  "data": {
    "auditedAt": "2026-05-27T14:35:00-07:00",
    "rulesVersion": "2026-06-29",
    "rulesCount": 138,
    "rulesIdentity": "sha256:3f412e98f9fa1e12967898a105384391555401a524c44fa90389e06802eb969a",
    "package": {
      "path": "/abs/path/to/myagent.zip",
      "sizeBytes": 184320,
      "sha256": "<hex>"
    },
    "targetStores": ["marketplace", "teams", "appsource"],
    "networkChecksEnabled": true,
    "result": {
      "label": "fail",
      "mustFailCount": 2,
      "blockingSkippedCount": 0,
      "goodFailCount": 4,
      "passedCount": 131,
      "skippedCount": 1
    },
    "findings": [
      {
        "id": "B1",
        "title": "Name does not contain banned Microsoft product terms",
        "category": "Branding & Naming",
        "severity": "must-fix",
        "outcome": "fail",
        "location": "manifest.json#/name/short",
        "value": "Microsoft Helper",
        "evidence": "Contains banned brand term 'Microsoft'.",
        "expected": "name.short must not contain banned Microsoft product names",
        "rule": "Category 3 — Branding & Naming",
        "citation": {
          "source": "Teams Store Validation Guidelines",
          "heading": "Name your app",
          "url": "https://learn.microsoft.com/microsoftteams/platform/concepts/deploy-and-publish/appsource/prepare/teams-store-validation-guidelines#name-your-app",
          "lastValidated": "2026-05-27"
        }
      },
      {
        "id": "A7",
        "title": "DA conversation_starters: 3 ≤ count ≤ 12",
        "category": "Declarative Agent JSON",
        "severity": "must-fix",
        "outcome": "fail",
        "location": "declarativeAgent.json#/conversation_starters",
        "value": 2,
        "evidence": "conversation_starters has 2 entries; minimum is 3.",
        "expected": "3 <= conversation_starters.length <= 12",
        "rule": "Category 6 — Declarative Agent JSON",
        "citation": {
          "source": "Commercial Marketplace certification policies",
          "heading": "§1140.9 Agents for M365 Copilot",
          "url": "https://learn.microsoft.com/legal/marketplace/certification-policies#11409-agents-for-microsoft-365-copilot-copilot-chat-and-agent-365",
          "lastValidated": "2026-05-27"
        }
      }
    ],
    "passed": [
      { "id": "P1", "title": "Input is a readable .zip archive", "category": "Package Structure" },
      {
        "id": "P2",
        "title": "manifest.json present at archive root",
        "category": "Package Structure"
      }
    ],
    "skipped": [
      {
        "id": "G1",
        "title": "Bundled configurable-tab URLs satisfy store requirements",
        "category": "Bundled Surface Co-Presence",
        "severity": "must-fix",
        "applicability": "not-applicable",
        "reason": "The package declares no configurableTabs capability."
      }
    ],
    "ruleCodeIndex": {
      "P": "Package Structure",
      "M": "manifest.json Schema",
      "B": "Branding & Naming",
      "I": "Icons",
      "D": "Valid Domains",
      "A": "Declarative Agent JSON",
      "X": "Anti-Prompt-Injection Content",
      "K": "Actions & API Plugins",
      "S": "SSO / webApplicationInfo",
      "L": "Localization",
      "R": "AI / Responsible AI Disclosure",
      "W": "Worker Agents",
      "U": "URL Reachability",
      "C": "Identity & Publisher Consistency",
      "N": "Agent/Plugin Name Consistency",
      "F": "App Listing & Media (Partner Center)",
      "G": "Bundled Surface Co-Presence"
    }
  }
}
```

### Field semantics

- `result.label` — one of `pass`, `fail`. `pass` <=> `mustFailCount === 0 && blockingSkippedCount === 0`.
- `rulesVersion`, `rulesCount`, and `rulesIdentity` — REQUIRED. They MUST match the registry metadata in `store-ops/rules.md`. `rulesIdentity` is SHA-256 over the sorted rule IDs joined with `\n`.
- `result.blockingSkippedCount` — number of skipped Must-fix rules whose applicability is `applicable` or `unknown` and that lack complete explicit approval evidence. This count MUST be zero for a passing report.
- `findings[].title` — REQUIRED. Human-readable rule title from `store-ops/rules.md` (the "Summary" column). Consumers SHOULD render this alongside the code so the developer doesn't have to look up what `B1` means.
- `findings[].category` — REQUIRED. Full category name (matches `ruleCodeIndex[<letter>]`).
- `findings[].outcome` — one of `fail` (rule violated) or `warn` (Good-to-fix advisory). Consumers should gate on `severity`, not `outcome`.
- `findings[].location` — JSON pointer or file path. Always include the file name when the field is outside `manifest.json`.
- `findings[].value` — actual value found in the package (truncate to 200 chars if longer).
- `findings[].citation.lastValidated` — the date someone last verified the URL + heading. Refresh when you re-read `store-ops/references.md`.
- `passed[]` — `{ id, title, category }` per rule (consistent shape with `findings[]`).
- `skipped[]` — `{ id, title, category, severity, applicability, reason, approval? }` per rule. `severity` is `must-fix` or `good-to-fix`; `applicability` is `applicable`, `not-applicable`, or `unknown`.
- `skipped[].approval` — optional `{ status: "approved", approvedBy, approvedAt, evidence }`. All four fields are REQUIRED when approval is used to unblock an applicable or unknown Must-fix skip. A statement that manual review is needed is not approval evidence.
- Rule accounting — derive the authoritative ID set from the bold IDs in `store-ops/rules.md`. Every rule ID MUST appear exactly once across `passed[]`, `findings[]`, and `skipped[]`; unknown, missing, or duplicate IDs make the report incomplete and therefore blocking. The combined array length MUST equal `rulesCount`.
- `ruleCodeIndex` — REQUIRED. Map of category letter → category name. Lets downstream tools render their own legend without re-reading `rules.md`.

---

## HTML Output

Standalone, single-file HTML report written to `<zip-basename>.store-ops.html`. The goal is "open in a browser, read top-to-bottom, share by attaching the file" — no external dependencies, no live network calls, no JavaScript required to read the report.

### Required properties

- **Self-contained.** Embed all CSS in a single `<style>` block in `<head>`. No `<link>` to remote stylesheets, no external JS, no external image references.
- **Light / dark aware.** Use CSS variables on `:root` and override them inside `@media (prefers-color-scheme: dark) { :root { … } }` so the report respects the reader's OS setting.
- **Anchored TOC.** Every section heading gets an `id`. The summary header links to the Must-fix, Good-to-fix, Skipped, Passed, and Rule Code Index sections via anchor jumps so a long report stays navigable.
- **Verdict banner at the top.** Big visible 🔴 FAIL / ✅ PASS banner with the Must-fix failure count, blocking skipped-check count, and one-line guidance.
- **Severity badges.** Color-coded inline badges (`must-fix` = red, `good-to-fix` = amber, `passed` = green, `skipped` = grey) on every finding row.
- **Title column mandatory.** Same contract as Markdown — never render a rule code without its title.
- **Citations are real anchors.** `<a href="…">` with the source name as the link text.
- **Passed checks collapsed.** Wrap the Passed list in `<details><summary>` so the report stays scannable.
- **Rule Code Index at bottom.** Same structure as the Markdown report — category legend table followed by per-category tables of every rule evaluated in this run.
- **Print-friendly.** A `@media print` rule that hides nav chrome and forces the passed-checks `<details>` open so a printed copy contains everything.

### Section order

```text
<header>
  <h1>Store Ops Audit — <package-name></h1>
  <p class="meta">date • package • target stores • rules version • network checks</p>
  <div class="verdict <pass|fail>">🔴 FAIL | ✅ PASS — <N> Must-fix … </div>
  <nav>Jump to: Must-fix · Good-to-fix · Skipped · Passed · Rule Code Index</nav>
</header>
<section id="summary">Severity × Result counts table</section>
<aside class="callout">About the rule codes — codes like B1 are internal taxonomy; see the Index at the bottom.</aside>
<section id="must-fix">🔴 Must-fix Findings — table (Rule · Title · Location · Evidence · Citation)</section>
<section id="good-to-fix">🟡 Good-to-fix Findings — table</section>
<section id="skipped">⏭️ Skipped Checks — table</section>
<section id="passed"><details>Passed Checks — list</details></section>
<section id="rule-code-index">Rule Code Index — legend + per-category tables</section>
<footer>Generated by the wiqd store-ops audit. Not authoritative.</footer>
```

### Minimum required CSS variables (light theme)

| Variable          | Purpose                           |
| ----------------- | --------------------------------- |
| `--bg`, `--fg`    | Page background and text          |
| `--surface`       | Card / table surface              |
| `--border`        | Table and card borders            |
| `--severity-must` | Must-fix accent (red family)      |
| `--severity-good` | Good-to-fix accent (amber family) |
| `--severity-pass` | Pass accent (green family)        |
| `--severity-skip` | Skip accent (grey family)         |
| `--accent`        | Link / heading underline color    |

All eight MUST be overridden inside the dark-mode media query.

### Format selection

The audit emits all three formats by default. To restrict, pass `--format md|html|json|all` (default `all`). For CI: `--format json`. For a human PR comment: `--format md`. For sharing in chat: `--format html`.

### Error envelope

If the audit cannot run (bad zip, missing manifest, IO error):

```json
{
  "status": "error",
  "command": "store-ops-audit",
  "exitCode": 2,
  "error": {
    "code": "BAD_PACKAGE",
    "message": "Could not extract <path>: end of central directory not found.",
    "details": { "path": "/abs/path/to/myagent.zip" }
  }
}
```

Error codes:

| Code                        | Meaning                                                             |
| --------------------------- | ------------------------------------------------------------------- |
| `BAD_PACKAGE`               | Zip cannot be opened or is corrupt                                  |
| `MISSING_MANIFEST`          | No `manifest.json` at the root                                      |
| `INVALID_MANIFEST_JSON`     | `manifest.json` is not valid JSON                                   |
| `MISSING_DA_JSON`           | `manifest.copilotAgents.declarativeAgents[0].file` does not resolve |
| `RULE_REGISTRY_LOAD_FAILED` | `store-ops/rules.md` could not be parsed/read                       |
| `CANCELLED`                 | User cancelled (Ctrl+C); exit 130                                   |
