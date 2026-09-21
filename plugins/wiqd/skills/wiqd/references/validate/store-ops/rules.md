# Rule Registry

The numbered store-ops rules evaluated by the `da-store-ops-validator` skill. Each rule has a stable ID, a severity, a one-line summary, a citation (URL + heading), and a "How to check" hint the executing agent uses to evaluate it.

**Registry version:** `2026-06-29` · **Rule count:** `138` · **Rule identity:** `sha256:3f412e98f9fa1e12967898a105384391555401a524c44fa90389e06802eb969a`

**Severity legend:**

- **Must-fix** — listed by Microsoft as a rejection cause or required by manifest schema. Audit fails on any Must-fix failure.
- **Good-to-fix** — strongly recommended; audit can pass with warnings.

**Citation format:** All citations are URL + heading + verified date from [`references.md`](references.md). Section numbers (e.g., §1140.9) are included for convenience but are not authoritative.

**Store key:** `M` = M365 Copilot Marketplace, `T` = Teams Store, `A` = AppSource. Rules with no `Stores` field apply to all three.

---

## Category 1 — Package Structure (`P`)

| ID     | Severity    | Summary                                                                            |
| ------ | ----------- | ---------------------------------------------------------------------------------- |
| **P1** | Must-fix    | Input is a readable `.zip` archive                                                 |
| **P2** | Must-fix    | Archive contains exactly one `manifest.json` at the root                           |
| **P3** | Must-fix    | Archive contains the color icon PNG referenced by `manifest.icons.color`           |
| **P4** | Must-fix    | Archive contains the outline icon PNG referenced by `manifest.icons.outline`       |
| **P5** | Must-fix    | Archive contains every file referenced by `copilotAgents.declarativeAgents[].file` |
| **P6** | Good-to-fix | No unreferenced files in the archive (every entry traced from `manifest.json`)     |
| **P7** | Good-to-fix | No macOS metadata (`__MACOSX/`, `.DS_Store`) and no empty directories              |
| **P8** | Must-fix    | Total package size ≤ 50 MB (Teams Store hard cap)                                  |
| **P9** | Must-fix    | No nested archives (`.zip` inside the `.zip`)                                      |

### How to check

- **P1:** Open the archive with `unzip -l` (POSIX) or `Expand-Archive -Force -DestinationPath <tmp>` (PowerShell). Failure → fail with the underlying error.
- **P2:** Confirm exactly one `manifest.json` and that it is at the root, not nested.
- **P3, P4, P5:** Parse `manifest.json` → walk `icons.color`, `icons.outline`, and `copilotAgents.declarativeAgents[].file`. Each path must resolve to an entry in the archive.
- **P6:** Build a set of all referenced files (recursive walk from `manifest.json`) and a set of all archive entries. Diff. Any unreferenced entry → warn.
- **P7:** Grep entry list for `__MACOSX`, `.DS_Store`, or zero-byte directories.
- **P8:** `Get-Item <zip>` size in bytes. >50 × 1024 × 1024 → fail.
- **P9:** Filter entries by `.zip` suffix.

### Citations

- Teams Store Validation Guidelines → "App package structure" ([references.md#teams-store-validation-guidelines](references.md#teams-store-validation-guidelines)).
- Commercial Marketplace certification policies §1140 ([references.md#commercial-marketplace-1140](references.md#commercial-marketplace-1140)).

---

## Category 2 — `manifest.json` Schema (`M`)

| ID      | Severity    | Summary                                                                                                                                                                                                      |
| ------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **M1**  | Must-fix    | `$schema` URL points to a publicly-released schema (not preview/dev). Recommended: `https://developer.microsoft.com/en-us/json-schemas/teams/v1.x/MicrosoftTeams.schema.json` for the latest stable version. |
| **M2**  | Must-fix    | `manifestVersion ≥ "1.13"` (required to declare `copilotAgents`)                                                                                                                                             |
| **M3**  | Must-fix    | `id` is a lowercase GUID (`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)                                                                                                                  |
| **M4**  | Must-fix    | `version` is SemVer `MAJOR.MINOR.PATCH` (no pre-release suffix)                                                                                                                                              |
| **M5**  | Must-fix    | `packageName` is reverse-DNS (e.g., `com.contoso.helper`) and ≤ 64 chars                                                                                                                                     |
| **M6**  | Must-fix    | `developer.name`, `developer.websiteUrl`, `developer.privacyUrl`, `developer.termsOfUseUrl` all present                                                                                                      |
| **M7**  | Must-fix    | `developer.*` URLs are HTTPS, not `localhost`, and not AppSource/marketplace links                                                                                                                           |
| **M8**  | Good-to-fix | `developer.mpnId` present (helps tie publisher identity across packages)                                                                                                                                     |
| **M9**  | Must-fix    | `name.short` ≤ 30 chars                                                                                                                                                                                      |
| **M10** | Must-fix    | `name.full` ≤ 100 chars                                                                                                                                                                                      |
| **M11** | Must-fix    | `description.short` ≤ 80 chars                                                                                                                                                                               |
| **M12** | Must-fix    | `description.full` ≤ 4000 chars                                                                                                                                                                              |
| **M13** | Good-to-fix | `description.full` ≤ 500 words (recommended for readability)                                                                                                                                                 |
| **M14** | Must-fix    | `accentColor` is `#RRGGBB` hex                                                                                                                                                                               |
| **M15** | Must-fix    | `localizationInfo.defaultLanguageTag` is a valid BCP 47 tag if present (also checked by L1 in the Localization category — M15 catches it during the manifest pass so failures surface early)                 |
| **M16** | Good-to-fix | Manifest does NOT use deprecated fields (`bots[].supportsCalling`, etc.)                                                                                                                                     |
| **M17** | Must-fix    | `developer.publisherDocsUrl` is present in the manifest `developer` section (required for apps with documentation)                                                                                           |
| **M18** | Good-to-fix | `version` field is incremented compared to the previously-submitted version (required on resubmission — cannot fully verify from a single package; flag as advisory)                                         |

### How to check

- **M1:** `manifest['$schema']` — load the URL list from [`references.md`](references.md) and confirm membership. Reject if it matches `*-preview*` / `*-dev*`.
- **M2:** Parse `manifestVersion` with SemVer comparator. `<"1.13"` → fail.
- **M3:** Regex.
- **M4:** Regex `^\d+\.\d+\.\d+$`.
- **M5:** Regex `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`.
- **M6, M7:** JSON pointer + URL parser. `URI.scheme === 'https'` and `URI.host !== 'localhost'` and host not in `{appsource.microsoft.com, store.microsoft.com, *.azurewebsites.net}`.
- **M9–M14:** Length checks. For **M13**, split on `/\s+/` and count.
- **M14:** Regex `^#[0-9A-Fa-f]{6}$`.
- **M15:** BCP 47 — use Node `Intl.getCanonicalLocales(tag)` and treat throw as fail.
- **M17:** Check `manifest.developer.publisherDocsUrl` exists and is a non-empty HTTPS URL.
- **M18:** Compare `manifest.version` against a previously-known version if available. If no prior version is provided, skip with advisory note to verify in Partner Center.

### Citations

- DA Manifest schema (1.13+) — `references.md#da-manifest-schema`.
- Commercial Marketplace §1140.2 (Listing requirements) → `references.md#commercial-marketplace-1140`.

---

## Category 3 — Branding & Naming (`B`)

| ID      | Severity    | Summary                                                                                                                                                                                                                                                                                                    |
| ------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **B1**  | Must-fix    | `name.short` and `name.full` do NOT contain banned Microsoft product terms: `Microsoft`, `Teams`, `Excel`, `PowerPoint`, `Word`, `OneDrive`, `SharePoint`, `OneNote`, `Azure`, `Surface`, `Xbox`, `Copilot`, `Outlook`, `Edge`, `Windows`, `Office`, `Bing`, `Cortana` (case-insensitive whole-word match) |
| **B2**  | Must-fix    | Name does NOT start with a Teams core feature word: `Chat`, `Contacts`, `Calendar`, `Calls`, `Files`, `Activity`, `Help`, `Apps`, `Meetings`                                                                                                                                                               |
| **B3**  | Must-fix    | Name does NOT contain pre-release markers: `Beta`, `Dev`, `Preview`, `Alpha`, `UAT`, `Test`, `Demo`, `Sample`, `RC` (case-insensitive)                                                                                                                                                                     |
| **B4**  | Must-fix    | Name does NOT contain `MS` or `MSFT` abbreviations                                                                                                                                                                                                                                                         |
| **B5**  | Good-to-fix | Description does NOT contain superlative / comparative marketing terms: `#1`, `the best`, `the most`, `world-class`, `award-winning`, `industry-leading`, `revolutionary`                                                                                                                                  |
| **B6**  | Must-fix    | Description does NOT make unsubstantiated Microsoft endorsement claims: `Powered by Microsoft`, `Certified by Microsoft`, `Microsoft Partner` (unless the publisher is verifiably MSPP-certified)                                                                                                          |
| **B7**  | Must-fix    | Description does NOT contain AppSource / Microsoft Store / Marketplace URLs (publisher links to the very store they are submitting to are disallowed)                                                                                                                                                      |
| **B8**  | Good-to-fix | Name does NOT contain parentheses with product names (e.g., `Helper (for Teams)`)                                                                                                                                                                                                                          |
| **B9**  | Good-to-fix | Publisher display name in `developer.name` matches the Partner Center account name for the publishing tenant (cannot be verified from package alone)                                                                                                                                                       |
| **B10** | Must-fix    | First reference to "Microsoft 365 Copilot" must use the full product name — abbreviations like "M365 Copilot" or phrases like "agents for Microsoft Copilot" are prohibited on first mention                                                                                                               |
| **B11** | Must-fix    | First reference to "Microsoft Teams" must use the full product name — "Teams" alone or "MS Teams" is not acceptable on first mention in any user-facing text                                                                                                                                               |
| **B12** | Must-fix    | No HTML tags (`<br>`, `<p>`, `<b>`, `<i>`, `<ul>`, etc.) in `description.full` — markup is not rendered in store listings and displays as raw text                                                                                                                                                         |
| **B13** | Good-to-fix | Limitations, prerequisites, or account dependencies (paid tier, admin consent, regional availability) must be disclosed in `description.full`                                                                                                                                                              |
| **B14** | Must-fix    | `description.full` must include help, support, or contact information — at minimum a URL or instruction for users to get assistance (§1140.4.1.3.13 — 288x FY26 field failures)                                                                                                                            |
| **B15** | Good-to-fix | `description.full` should differ from `description.short`, contain substantive (non-placeholder) content, and have ≥ 3 sentences describing functionality (§1140.4.1.3.1 — 231x FY26 field failures)                                                                                                       |

### How to check

- **B1, B2, B3, B4:** Compile a single case-insensitive regex per list. `\b(Microsoft|Teams|Excel|...)\b` against `name.short` and `name.full`.
- **B5:** Same approach against `description.short` and `description.full`.
- **B6:** Regex against descriptions. Mark as Must-fix if matched without external proof.
- **B7:** Regex for `appsource.microsoft.com|store.microsoft.com|marketplace\.microsoft\.com|microsoft\.com/store` in descriptions.
- **B8:** Regex `\([^)]*?(Microsoft|Teams|Excel|...)[^)]*\)`.
- **B9:** Cannot verify automatically; flag as a Good-to-fix reminder unless the user supplies the Partner Center display name.
- **B10:** Scan `description.short`, `description.full`, and `name.full` for first occurrence of a Copilot product mention. Check that the first mention is exactly `Microsoft 365 Copilot` (or `Microsoft Copilot`) — not `M365 Copilot`, `agents for Microsoft Copilot`, or bare `Copilot` as the first reference. Algorithm: find the first match of `/\bCopilot\b/i` in the text, then verify it is immediately preceded by `Microsoft 365 ` or `Microsoft `. If not, fail. Regex (negative-match approach): first match of `/\b(M365 Copilot|agents for (Microsoft )?Copilot|(?<!Microsoft\s365\s)(?<!Microsoft\s)Copilot)\b/i` → fail.
- **B11:** Scan `description.short` and `description.full` for first occurrence of a Teams reference. Check first mention is `Microsoft Teams` — not bare `Teams` or `MS Teams`. Regex: first match of `/\b(MS Teams|(?<!Microsoft\s)Teams)\b/` (negative lookbehind) for the first Teams mention.
- **B12:** Regex `/<[a-zA-Z][^>]*>/` against `description.full`. Any match → fail.
- **B13:** Heuristic — if the app description mentions functionality requiring sign-in, paid tier, or specific regions but lacks disclosure keywords (`limitation`, `requires`, `prerequisite`, `subscription`, `paid`, `account required`), flag as advisory.
- **B14:** Scan `description.full` for help/support indicators. Regex: `/\b(help|support|contact|assistance|mailto:|https?:\/\/\S*(help|support|contact|faq))/i`. If no match AND `description.full` is > 50 chars (not a stub), emit Must-fix: "Description must include help, support, or contact information per §1140.4.1.3.13."
- **B15:** Three sub-checks: (a) `description.full !== description.short` — if identical, warn "Long description should expand on the short description." (b) Length: `description.full.split(/[.!?]+/).filter(s => s.trim()).length >= 3` — at least 3 sentences. (c) Placeholder detection: regex `/\b(lorem ipsum|placeholder|TODO|TBD|coming soon|insert .* here)\b/i` — flag if matched. Any sub-check failure → Good-to-fix.

### Citations

- Teams Store Validation Guidelines → "Name your app" and "Write the description" — `references.md#teams-store-validation-guidelines`.
- Commercial Marketplace §1140.2 → `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.4.1.3.13 — help/contact links in description — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.4.1.3.1 — long description guidelines — `references.md#commercial-marketplace-1140`.

---

## Category 4 — Icons (`I`)

| ID     | Severity    | Summary                                                                                                                   |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------- |
| **I1** | Must-fix    | Color icon is a valid PNG (verify the 8-byte PNG signature `89 50 4E 47 0D 0A 1A 0A`)                                     |
| **I2** | Must-fix    | Color icon dimensions are exactly **192×192**                                                                             |
| **I3** | Must-fix    | Color icon has an alpha channel (PNG color type 6 or 4)                                                                   |
| **I4** | Must-fix    | Outline icon is a valid PNG                                                                                               |
| **I5** | Must-fix    | Outline icon dimensions are exactly **32×32**                                                                             |
| **I6** | Must-fix    | Outline icon pixels are only **white** + **transparent** (heuristic: every non-transparent pixel has `r == g == b ≥ 240`) |
| **I7** | Good-to-fix | Color icon file size ≤ 30 KB                                                                                              |
| **I8** | Good-to-fix | Outline icon file size ≤ 5 KB                                                                                             |

### How to check

- **I1, I4:** Read first 8 bytes — compare to PNG signature.
- **I2, I5:** PNG IHDR chunk at bytes 16–24: width (BE u32) then height (BE u32). PowerShell example:
  ```powershell
  $b = [System.IO.File]::ReadAllBytes($path)
  $w = [BitConverter]::ToInt32($b[19..16], 0)
  $h = [BitConverter]::ToInt32($b[23..20], 0)
  ```
  Or use Node's `sharp` / `pngjs` if available. Otherwise parse the IHDR directly — no native deps required.
- **I3:** IHDR byte 25 (color type). 4 or 6 → has alpha. 0 or 2 → no alpha → fail.
- **I6:** Decode pixels (`pngjs` in Node) and assert each pixel: `if (a > 0) { r >= 240 && g >= 240 && b >= 240 }`. If `pngjs` unavailable, document as a manual visual check and skip with warning.
- **I7, I8:** `Get-Item <path>`.

### Citations

- Teams Store Validation Guidelines → "App icons" — `references.md#teams-store-validation-guidelines`.

---

## Category 5 — Valid Domains (`D`)

| ID     | Severity    | Summary                                                                                                                                                                                                                          |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **D1** | Must-fix    | No top-level wildcards in `validDomains`: `*.com`, `*.net`, `*.org`, `*.io`, `*.co`, `*.dev`, etc.                                                                                                                               |
| **D2** | Must-fix    | No banned Microsoft-owned wildcard domains in `validDomains`: `*.microsoft.com`, `*.microsoftonline.com`, `*.onmicrosoft.com`, `*.azurewebsites.net`, `*.azureedge.net`, `*.cloudapp.net`, `*.windows.net`, `*.botframework.com` |
| **D3** | Must-fix    | No exact banned hosts in `validDomains`: `go.microsoft.com`, `teams.microsoft.com`, `login.microsoftonline.com`, `token.botframework.com` (unless the agent legitimately requires Microsoft SSO — see S1)                        |
| **D4** | Must-fix    | Each entry is a hostname only — no scheme (`http://`, `https://`), no `www.` prefix, no path, no port                                                                                                                            |
| **D5** | Must-fix    | A wildcard segment must be exactly `*` (not `*foo` or `foo*`)                                                                                                                                                                    |
| **D6** | Must-fix    | A wildcard segment must occupy the leftmost position; all preceding labels must also be wildcards (`*.api.contoso.com` allowed; `api.*.contoso.com` not allowed)                                                                 |
| **D7** | Good-to-fix | `validDomains` has ≤ 100 entries                                                                                                                                                                                                 |
| **D8** | Good-to-fix | No duplicate entries in `validDomains` (case-insensitive)                                                                                                                                                                        |
| **D9** | Must-fix    | Every host referenced by `copilotAgents.declarativeAgents[].actions[]` runtime URLs is covered by an entry in `validDomains` (or is a major cloud-provider host the platform allowlists)                                         |

### How to check

- **D1, D2:** Maintain explicit lists in this rule. Iterate `validDomains` and match.
- **D3:** Set membership.
- **D4:** Parse with `URL` constructor — if it succeeds with a scheme, fail. Then split on `/` and reject if more than the host segment exists.
- **D5:** Split on `.` and check each label.
- **D6:** Find the first wildcard label index; every label at a lower index must also be `*`.
- **D9:** Walk all action runtime URLs, pull hostnames, and verify each is covered by exact match or wildcard match against `validDomains`.

### Citations

- Teams Store Validation Guidelines → "Valid Domains" — `references.md#teams-store-validation-guidelines`.

---

## Category 6 — Declarative Agent JSON (`A`)

| ID      | Severity    | Summary                                                                                                                                                                                                |
| ------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **A1**  | Must-fix    | DA json `$schema` URL points to a publicly-released DA manifest schema (1.5+ stable; not `*-preview*`)                                                                                                 |
| **A2**  | Must-fix    | DA json `name` ≤ 100 chars                                                                                                                                                                             |
| **A3**  | Must-fix    | DA json `name` matches `manifest.json` `name.short` OR `name.full` (case-sensitive) — and matches any associated plugin's `name_for_human`                                                             |
| **A4**  | Must-fix    | DA json `description` ≤ 1000 chars                                                                                                                                                                     |
| **A5**  | Must-fix    | DA json `instructions` is present and has ≥ 1 non-whitespace char                                                                                                                                      |
| **A6**  | Must-fix    | DA json `instructions` ≤ 8000 chars                                                                                                                                                                    |
| **A7**  | Must-fix    | DA json `conversation_starters`: `3 ≤ count ≤ 12`                                                                                                                                                      |
| **A8**  | Must-fix    | Each `conversation_starters[].title` ≤ 50 chars                                                                                                                                                        |
| **A9**  | Must-fix    | Each `conversation_starters[].text` ≤ 500 chars (if present)                                                                                                                                           |
| **A10** | Must-fix    | `capabilities[]` contains at most one of each capability type (`OneDriveAndSharePoint`, `WebSearch`, `GraphConnectors`, `CodeInterpreter`, `Email`, `Calendar`, `PeopleSearch`, `TeamsMessages`, etc.) |
| **A11** | Must-fix    | `actions[].file` entries resolve to files in the package                                                                                                                                               |
| **A12** | Good-to-fix | `instructions` references at least one capability when capabilities are declared (heuristic: capability noun appears in instructions)                                                                  |
| **A13** | Must-fix    | Each `functions[].capabilities.confirmation.body` in `ai-plugin.json` must be non-empty when a confirmation capability is declared — empty confirmation bodies cause silent runtime failures           |

### How to check

- **A1:** Same approach as M1. Schema allowlist in [`references.md`](references.md).
- **A2, A4, A6:** Length checks.
- **A3:** String equality.
- **A5:** `instructions.trim().length > 0`.
- **A7:** `Array.isArray(cs) && cs.length >= 3 && cs.length <= 12`.
- **A8, A9:** Iterate.
- **A10:** Group by capability type, assert each group's count ≤ 1.
- **A11:** Resolve relative to DA json's directory inside the zip.
- **A13:** Walk DA JSON `actions[].file` → parse each `ai-plugin.json` → for every `functions[]` entry that declares `capabilities.confirmation`, check that `capabilities.confirmation.body` is a non-empty string after trimming whitespace.

### Citations

- DA Manifest schema 1.5/1.6/1.7/1.8 — `references.md#da-manifest-schema`.
- Copilot review validation guidelines → "Declarative agent requirements" — `references.md#copilot-review-validation`.
- Marketplace §1140.9 (Agents for M365 Copilot) — `references.md#commercial-marketplace-1140`.

---

## Category 7 — Anti-Prompt-Injection Content (`X`)

Applies to **every string field** in the DA json that influences the model: `description`, `instructions`, every `conversation_starters[].title` and `conversation_starters[].text`.

| ID     | Severity    | Summary                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **X1** | Must-fix    | No instructional-injection phrases. Banned phrase set (case-insensitive, word-boundary): `"if the user says"`, `"if user says"`, `"ignore previous"`, `"ignore the above"`, `"ignore your instructions"`, `"forget previous"`, `"forget your instructions"`, `"delete all"`, `"reset"` (as standalone instruction), `"new instructions"`, `"system prompt"`, `"answer in bold"`, `"do not print anything"`, `"do not respond"`, `"always respond"`, `"you are now"`, `"act as"`, `"your real instructions"`, `"developer mode"`, `"jailbreak"`, `"DAN mode"` |
| **X2** | Must-fix    | No URLs in `instructions`, `description`, or any `conversation_starters[]` field (regex `\bhttps?://`)                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **X3** | Must-fix    | No emoji characters (Unicode ranges U+1F300–U+1FAFF, U+2600–U+27BF, U+1F000–U+1F1FF) in `instructions`, `description`, or any `conversation_starters[]`                                                                                                                                                                                                                                                                                                                                                                                                      |
| **X4** | Must-fix    | No hidden / zero-width / control characters: U+200B–U+200F (zero-width + LTR/RTL marks), U+202A–U+202E (embedding overrides), U+FEFF (BOM), C0 control chars (0x00–0x1F except `\t \n \r`), C1 control chars (0x80–0x9F)                                                                                                                                                                                                                                                                                                                                     |
| **X5** | Must-fix    | No long hex / binary literals (≥ 8 contiguous hex chars after `0x`, or `\b[01]{16,}\b`) in `instructions`                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **X6** | Good-to-fix | `instructions` does NOT instruct the model to claim it is human, sentient, or non-AI                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **X7** | Good-to-fix | `instructions` and `description` do NOT promise compliance certifications (HIPAA, SOC2, FedRAMP, GDPR) without external evidence                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **X8** | Good-to-fix | No more than 5 ALL-CAPS words in any single conversation starter (heuristic for shouty injection)                                                                                                                                                                                                                                                                                                                                                                                                                                                            |

### How to check

- **X1:** Build a compiled regex from the phrase list. Match against each field. Phrases must be matched with word boundaries on both sides.
- **X2:** `/\bhttps?:\/\//gi`.
- **X3:** Match each character against the emoji ranges using `String.codePointAt(0)`.
- **X4:** Iterate code points and compare against the set.
- **X5:** Two regexes: `/0x[0-9A-Fa-f]{8,}/` and `/\b[01]{16,}\b/`.
- **X6:** Heuristic regex: `/\b(i am (a )?(human|person)|i am not (an )?ai|not (an )?artificial intelligence)\b/i`. Treat hits as warnings.
- **X7:** Regex for `\b(HIPAA|SOC ?2|FedRAMP|GDPR|PCI ?DSS)\b`. Warn.
- **X8:** Count words matching `/\b[A-Z]{4,}\b/g` per starter.

### Citations

- Copilot review validation guidelines → "Prompt injection patterns" — `references.md#copilot-review-validation`.
- Marketplace §1140.9 → `references.md#commercial-marketplace-1140`.

---

## Category 8 — Actions & API Plugins (`K`)

Applies when `copilotAgents.declarativeAgents[].actions[]` is present.

| ID     | Severity    | Summary                                                                                                                                  |
| ------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **K1** | Must-fix    | Each action `file` resolves to a JSON file in the package                                                                                |
| **K2** | Must-fix    | API plugin's referenced OpenAPI spec resolves to a file in the package                                                                   |
| **K3** | Must-fix    | API plugin `runtimes[].spec.url` and `runtimes[].run_for_functions[]` URLs are HTTPS only — no `http://`, no `localhost`, no IP literals |
| **K4** | Must-fix    | Every host targeted by an API plugin runtime URL appears in `manifest.validDomains` (covered by rule D9, restated here)                  |
| **K5** | Must-fix    | API plugin `auth.type` is a known supported type (`None`, `OAuthPluginVault`, `ApiKeyPluginVault`)                                       |
| **K6** | Good-to-fix | API plugin `name_for_human` matches the DA `name`                                                                                        |
| **K7** | Good-to-fix | API plugin `description_for_model` ≤ 8000 chars                                                                                          |
| **K8** | Must-fix    | Adaptive Card responses include a metadata URL and at least 2 data fields (per Marketplace requirement)                                  |
| **K9** | Must-fix    | Each API plugin function declaring `capabilities.confirmation` must have a non-empty `body` field in its `ai-plugin.json`                |

### How to check

- **K1, K2:** Path resolution from the package root.
- **K3:** Parse each URL; reject `protocol !== 'https:'`, reject `hostname === 'localhost'` or IPv4/IPv6 literal.
- **K5:** Set membership.
- **K8:** Walk OpenAPI responses for any `application/vnd.microsoft.card.adaptive` content; for each adaptive card body, assert it contains an `Action.OpenUrl` (metadata URL) and ≥ 2 `TextBlock`/`FactSet` fields.
- **K9:** Walk DA JSON `actions[].file` → parse each `ai-plugin.json` → for each entry in `functions[]`, if `capabilities.confirmation` exists, assert `capabilities.confirmation.body` is a non-empty string (not blank, not whitespace-only). Missing or empty → Must-fix failure.

### Citations

- Copilot review validation guidelines → "Actions and plugins" — `references.md#copilot-review-validation`.
- Commercial Marketplace certification policies §1140.9.2.8/10 — confirmation dialog requirements for plugin functions — `references.md#commercial-marketplace-1140`.

---

## Category 9 — SSO / `webApplicationInfo` (`S`)

| ID     | Severity    | Summary                                                                                                                                                                                                                                                                                                                                                                                                       |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **S1** | Must-fix    | If any auth-related host appears in `validDomains` (e.g., `login.microsoftonline.com`, `login.microsoft.com`, `*.b2clogin.com`), `manifest.webApplicationInfo` MUST be present                                                                                                                                                                                                                                |
| **S2** | Must-fix    | `webApplicationInfo.id` is a GUID                                                                                                                                                                                                                                                                                                                                                                             |
| **S3** | Must-fix    | `webApplicationInfo.resource` is a valid URI (HTTPS or `api://` scheme)                                                                                                                                                                                                                                                                                                                                       |
| **S4** | Good-to-fix | The `id` corresponds to an Entra ID app registration the publisher controls (cannot be automatically verified; flag for human reviewer)                                                                                                                                                                                                                                                                       |
| **S5** | Must-fix    | _(Gate: `copilotAgents` + (`webApplicationInfo` present OR an API plugin with `auth.type !== 'None'`))_ Auth config is **complete and testable**: `webApplicationInfo` has a GUID `id`, a valid-URI `resource`, AND the resource host has a matching `validDomains` entry; OR the plugin's declared auth reference resolves. Incomplete auth is the most common "unable to test app" rejection (§100.14.1.1). |

### How to check

- **S1:** Set intersection between `validDomains` (with wildcards expanded heuristically) and the auth host list.
- **S2:** Regex.
- **S3:** `URL` parse; `protocol in {'https:', 'api:'}`.
- **S5:** Gate first: only run when `copilotAgents.declarativeAgents[]` is present AND (`webApplicationInfo` is present OR some plugin declares `auth.type !== 'None'`). When `webApplicationInfo` is present: assert `id` matches the GUID regex (S2), `resource` parses as a URI (S3), and the registrable host of `resource` is covered by `validDomains` (exact or wildcard match, same matcher as `D9`). Honor the same identity-host allowlist exception as `S1`/`D3` — a `resource` on `login.microsoftonline.com` (and siblings) need not appear in `validDomains`. For an API plugin with `auth.type !== 'None'`, confirm the referenced auth vault/registration id is non-empty and resolvable. Any missing piece → fail. Full runtime confirmation (the OAuth round-trip) is Phase 2 `U6` / Phase 3 `TC4`.

### Citations

- Teams app manifest schema → `webApplicationInfo` — `references.md#da-manifest-schema`.
- Commercial Marketplace §100.14.1 (app must be testable by the reviewer) — `references.md#commercial-marketplace-1140`.

---

## Category 10 — Localization (`L`)

| ID     | Severity    | Summary                                                                                                                                                                                                                  |
| ------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **L1** | Must-fix    | If `localizationInfo` is present, `defaultLanguageTag` is a valid BCP 47 tag (same check as M15 — restated here for completeness within the Localization category; suppress duplicate finding if M15 already flagged it) |
| **L2** | Must-fix    | Each `additionalLanguages[].languageTag` is a valid BCP 47 tag (and not equal to `defaultLanguageTag`)                                                                                                                   |
| **L3** | Must-fix    | Each `additionalLanguages[].file` resolves to a JSON file in the package and parses as valid JSON                                                                                                                        |
| **L4** | Good-to-fix | Each additional language file contains every key present in the canonical English strings (no missing translations)                                                                                                      |
| **L5** | Good-to-fix | Translated `name.short` / `name.full` still pass branding rules **B1–B4**                                                                                                                                                |

### How to check

- **L1, L2:** `Intl.getCanonicalLocales(tag)` throw → fail.
- **L3:** Resolve path + `JSON.parse`.
- **L4:** Diff key set vs. base.
- **L5:** Re-run B1–B4 against translated strings.

### Citations

- Teams app manifest schema → `localizationInfo` — `references.md#da-manifest-schema`.

---

## Category 11 — AI / Responsible AI Disclosure (`R`)

| ID     | Severity    | Summary                                                                                                                                                                                                                                                                                                               |
| ------ | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **R1** | Must-fix    | When the agent declares `copilotAgents` or any AI-driven capability, the public `developer.privacyUrl` page must exist (covered by U2) and the description should mention AI behaviour. Overlaps with U2 (privacy URL reachability) and R7 (AI-disclosure keywords) — R1 is the compound rule that ties both together |
| **R2** | Good-to-fix | `description.full` mentions one of: `AI`, `artificial intelligence`, `generative`, `LLM`, `language model`, `Copilot` — to disclose AI nature to end users                                                                                                                                                            |
| **R3** | Must-fix    | No claims of facial recognition for US law-enforcement use (banned by Microsoft RAI Standard) — regex `\bfacial recognition\b` AND `\b(police\|law enforcement\|FBI\|ICE)\b`                                                                                                                                          |
| **R4** | Must-fix    | No claims of emotion inference / sentiment detection without explicit RAI disclosure linked from `privacyUrl` (cannot auto-verify the link; flag if emotion claims are present)                                                                                                                                       |
| **R5** | Good-to-fix | No claims of medical, legal, or financial advice without disclaimer                                                                                                                                                                                                                                                   |
| **R6** | Good-to-fix | No claims that the agent is bias-free, fair, or 100% accurate                                                                                                                                                                                                                                                         |
| **R7** | Must-fix    | When the agent declares AI capabilities (`copilotAgents` or `declarativeAgents`), `description.full` must disclose AI-generated content — users must be informed that responses may be generated by AI                                                                                                                |

### How to check

- **R1:** Compound check — (a) verify `developer.privacyUrl` is reachable (delegates to U2; if U2 already fails, R1 inherits that failure), AND (b) if `manifest.copilotAgents` is declared, scan `description.full` for AI-disclosure keywords (same check as R7). R1 ties privacy URL presence and AI disclosure together — if BOTH are missing, the agent has no RAI transparency at all. Overlaps: U2 covers clause (a) independently, R7/R2 cover clause (b). An agent should evaluate R1 last in this category and suppress duplicate findings if U2 and R7 already flagged the same underlying issues.
- **R2:** Regex over `description.short` + `description.full`.
- **R3:** Two regexes; failure requires BOTH to match.
- **R4:** Regex `\b(emotion|sentiment) (inference|detection|recognition|analysis)\b`. If matched, warn for human review.
- **R5:** Regex `\b(medical|legal|financial|investment|tax) advice\b` without `\b(not|no) (medical|legal|financial|investment|tax) advice\b` nearby (≤ 20 words).
- **R6:** Regex `\b(unbiased|bias[ -]free|100% accurate|always (right|correct))\b`.
- **R7:** If `manifest.copilotAgents` or any `declarativeAgents[]` is declared, scan `description.full` for AI-disclosure keywords: `AI`, `artificial intelligence`, `AI-generated`, `generated by AI`, `language model`, `LLM`. If NONE are present, flag as Must-fix. Differs from R2 (Good-to-fix) in that R7 specifically checks for the mandatory §1140.4.1.24.4/24.5 disclosure when AI capabilities are active.

### Citations

- Marketplace §1140.9 → `references.md#commercial-marketplace-1140`.
- Microsoft Responsible AI Standard (referenced from §100) — `references.md#commercial-marketplace-1140`.

---

## Category 12 — Worker Agents (`W`)

Applies when `copilotAgents.declarativeAgents[].worker_agents` is present.

| ID     | Severity    | Summary                                                                                                         |
| ------ | ----------- | --------------------------------------------------------------------------------------------------------------- |
| **W1** | Must-fix    | Every referenced worker agent is itself a declarative agent                                                     |
| **W2** | Must-fix    | Each worker agent's referenced file resolves in the package (or the worker is referenced by published agent ID) |
| **W3** | Good-to-fix | Total worker agent depth ≤ 2 (recommended — deeper trees inflate latency)                                       |

### How to check

- **W1:** Inspect each worker target's declared type and reject any non-DA reference.
- **W2:** Path resolution or remote ID lookup.

### Citations

- DA Manifest schema → `worker_agents` — `references.md#da-manifest-schema`.

---

## Category 13 — URL Reachability (`U`) — _network-dependent, skipped under `--no-network`_

| ID     | Severity    | Summary                                                                                                              |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------------------- |
| **U1** | Good-to-fix | `developer.websiteUrl` returns 2xx/3xx on `HEAD`                                                                     |
| **U2** | Good-to-fix | `developer.privacyUrl` returns 2xx/3xx                                                                               |
| **U3** | Good-to-fix | `developer.termsOfUseUrl` returns 2xx/3xx                                                                            |
| **U4** | Must-fix    | No URL is a placeholder: `example.com`, `contoso.com`, `localhost`, `127.0.0.1`, `your-domain.com`, `replace-me.com` |

### How to check

- **U1–U3:** `HEAD` request with 10s timeout. Treat connection errors as failures. Follow up to 3 redirects.
- **U4:** Substring match against the placeholder list.

### Citations

- Teams Store Validation Guidelines → "Privacy policy and terms of use" — `references.md#teams-store-validation-guidelines`.

---

## Category 14 — Identity & Publisher Consistency (`C`) — advisory

| ID     | Severity    | Summary                                                                                               |
| ------ | ----------- | ----------------------------------------------------------------------------------------------------- |
| **C1** | Good-to-fix | `developer.name` is consistent across `manifest.json` and any sibling plugin manifests in the package |
| **C2** | Good-to-fix | `developer.mpnId` is set when publishing as an organization                                           |
| **C3** | Good-to-fix | Publisher domain in `developer.websiteUrl` is also in `validDomains` (suggests legitimate ownership)  |
| **C4** | Good-to-fix | No personal email addresses appear in `description` (heuristic — corporate domains preferred)         |

### How to check

- **C1:** Compare strings across all plugin manifests if present.
- **C2:** Field presence.
- **C3:** Parse `websiteUrl`, take registrable domain, check membership in `validDomains` (exact or wildcard match).
- **C4:** Regex over descriptions: `\b[A-Za-z0-9._%+-]+@(gmail\.com|yahoo\.com|hotmail\.com|outlook\.com)\b` → warn.

### Citations

- Commercial Marketplace §100 (publisher requirements) — `references.md#commercial-marketplace-1140`.

---

## Category 15 — Agent/Plugin Name Consistency (`N`)

Cross-file name consistency checks based on FY26 field data — §1140.9.\* name-mismatch failures account for 235+ rejections per quarter. These rules verify that the app name is consistent across `manifest.json`, declarative agent JSON, and plugin manifests.

| ID     | Severity    | Summary                                                                                                                                                                                                                                                                    |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **N1** | Must-fix    | `manifest.json` `name.short` matches the DA JSON `name` field (case-insensitive comparison; trailing/leading whitespace trimmed). Complements A3 which checks strict case-sensitive equality — N1 catches the broader set of casing mismatches that store reviewers reject |
| **N2** | Must-fix    | Each plugin's `name_for_human` in `ai-plugin.json` matches `manifest.json` `name.short` (case-insensitive)                                                                                                                                                                 |
| **N3** | Must-fix    | Each plugin's top-level `name` field in `ai-plugin.json` matches `manifest.json` `name.short` (case-insensitive, ignoring underscores/hyphens vs spaces)                                                                                                                   |
| **N4** | Must-fix    | App name consistent between `manifest.json` `name.short` and the DA JSON display name metadata — no extra suffixes, version numbers, or qualifiers allowed                                                                                                                 |
| **N5** | Good-to-fix | App name consistent across ALL surfaces: manifest `name.short`, DA JSON `name`, plugin `name_for_human`, and Partner Center listing title (advisory at validate time)                                                                                                      |
| **N6** | Good-to-fix | Agent icon shown in Copilot UI is derived from `manifest.icons.color` — verify the icon filename and branding are consistent with the app name and Partner Center listing icon (§1140.9.2.23 — 47x FY26 field failures)                                                    |

### How to check

- **N1:** Parse `manifest.json` → `name.short`. Walk `copilotAgents.declarativeAgents[].file` → parse each DA JSON → compare `name` field. Both values trimmed and compared case-insensitively. Mismatch → fail.
- **N2:** Walk DA JSON `actions[].file` → parse each `ai-plugin.json` → compare `name_for_human` against `manifest.name.short`. Case-insensitive trim comparison.
- **N3:** Walk DA JSON `actions[].file` → parse each `ai-plugin.json` → normalize `name` by replacing `_` and `-` with spaces → compare against `manifest.name.short` (also space-normalized). Case-insensitive.
- **N4:** Compare `manifest.name.short` against each DA JSON `name`. Reject if the DA name contains extra qualifiers not present in the manifest (e.g., `"Contoso Helper v2"` vs. `"Contoso Helper"` — the version suffix `v2` is a mismatch).
- **N5:** Collect all name surfaces: `manifest.name.short`, each DA `name`, each plugin `name_for_human`. If all in-package names match but the Partner Center title is unknown, emit Good-to-fix advisory — "Verify Partner Center listing title matches `manifest.name.short`."
- **N6:** Cross-reference `manifest.icons.color` filename against `manifest.name.short` — if the icon filename contains no recognizable fragment of the app name (heuristic: lowercase both, check if any word from `name.short` appears in the icon filename minus extension), emit Good-to-fix advisory: "Verify the color icon visually represents the agent and matches the Partner Center listing icon." This is a heuristic — false positives are acceptable for an advisory.

### Citations

- Commercial Marketplace certification policies §1140.9.2.13/15/17/18/21 — name consistency across manifest, DA, and plugins — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace §1140.9.2.11 — plugin name must match manifest app name — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace §1140.9.1.1 — app name consistency in Copilot UI metadata — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.9.2.23 — agent icon and name consistency in Copilot UI — `references.md#commercial-marketplace-1140`.

---

## Category 16 — App Listing & Media (`F`)

These rules reflect the top Partner Center filing rejections in FY26 field data (600+ occurrences in some cases). At validate time, the audit cannot access Partner Center metadata, so these rules emit Good-to-fix advisories.

| ID      | Severity    | Summary                                                                                                                                                                                                    |
| ------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **F1**  | Good-to-fix | App submission should include a video demonstrating core functionality (§1140.4.1.5.1 — 600x field failures in FY26)                                                                                       |
| **F2**  | Good-to-fix | Publisher attestation must be initiated in Partner Center before submission (§1140.6.2.1 — 592x field failures).                                                                                           |
| **F3**  | Good-to-fix | Screenshots must depict mobile functionality if the app supports mobile (§1140.4.1.27.1 — 445x field failures)                                                                                             |
| **F4**  | Must-fix    | Screenshots must include descriptive captions **rendered into the image** explaining the depicted feature — Partner Center has no caption field (§1140.4.1.4.6 — 281x field failures)                      |
| **F5**  | Good-to-fix | At least one screenshot should show M365 extensibility — demonstrate the agent working within Microsoft 365 surfaces (§1140.4.1.27.2 — 229x field failures)                                                |
| **F6**  | Must-fix    | Minimum 3 and maximum 5 screenshots required in Partner Center listing (§1140.4.1.4.4 — 134x field failures)                                                                                               |
| **F7**  | Good-to-fix | Description links in Partner Center listing must be hyperlinked (plain URLs without `<a>` tags are rejected) (§1140.4.1.19.1 — 293x failures)                                                              |
| **F8**  | Good-to-fix | Description must reference supported client platforms — e.g., "Works in Microsoft Teams, Outlook, and Microsoft 365 app" (§1140.8.1.4.2)                                                                   |
| **F9**  | Must-fix    | Categories selected from predefined Partner Center list (≥ 1, max 3) — _not available from the package; skipped at validate time_                                                                          |
| **F10** | Must-fix    | Availability date is a valid future date in `YYYY-MM-DD` format — _not available from the package; skipped at validate time_                                                                               |
| **F11** | Must-fix    | Screenshots in the Partner Center listing must accurately depict the app's actual UI or scenarios relevant to the app, not mockups, wireframes, or design comps (§1140.4.1.4.3 — 222x FY26 field failures) |
| **F12** | Must-fix    | Screenshots must be exactly 1366×768 px, high-resolution, sharp, and contain legible, clearly readable text (§1140.4.1.4)                                                                                  |

### How to check

All rules in this category emit advisories at validate time.

- **F1 (video included):** Emit Good-to-fix advisory — "Partner Center requires a video demonstrating core functionality. Verify before submission."
- **F2 (publisher attestation):** Emit Good-to-fix advisory — "Publisher attestation must be initiated in Partner Center before submission."
- **F3 (screenshots show mobile):** Emit Good-to-fix advisory — "Screenshots must depict mobile functionality. Verify before submission."
- **F4 (screenshots include captions):** Emit Good-to-fix advisory — "Screenshots must include descriptive captions rendered into the image itself. Verify before submission."
- **F5 (screenshots show M365 extensibility):** Emit Good-to-fix advisory — "Screenshots must show the agent working in M365 surfaces. Verify before submission."
- **F6 (screenshots ≥ 3, ≤ 5):** Emit Good-to-fix advisory — "Partner Center requires 3–5 screenshots. Verify before submission."
- **F7 (description links hyperlinked):** Cannot be verified from the package. Emit skipped advisory: "Verify Partner Center description links use hyperlinks, not plain URLs."
- **F8 (supported clients in description):** Scan `description.full` for client-platform mentions (`Microsoft Teams`, `Outlook`, `Microsoft 365`). If absent AND the agent declares capabilities, emit Good-to-fix.
- **F9 (categories from predefined list):** N/A at validate time — category data is not available from the package. Skip silently.
- **F10 (availability date valid):** N/A at validate time — availability date is not available from the package. Skip silently.
- **F11 (actual UI, no mockups):** Emit Good-to-fix advisory — "Screenshots must accurately depict the app's actual UI, not mockups or wireframes. Verify before submission."
- **F12 (high-resolution screenshots):** Emit Good-to-fix advisory — "Screenshots must be high-resolution with sharp, legible text. Verify before submission."
- **Conditional skip logic:** At validate time, if the audit is run with `--include-partner-center-advisories` (or equivalent flag), emit advisories as Good-to-fix findings in the report. Otherwise, skip silently.

### Citations

- Commercial Marketplace certification policies §1140.4.1.5.1 (video requirement) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.6.2.1 (publisher attestation) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.4.1.27.1/27.2 (screenshots — mobile and M365 extensibility) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.4.1.4.4/4.6 (screenshot count and captions) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.4.1.19.1 (hyperlinked description) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.8.1.4.2 (supported clients in description) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140 (category classification requirements) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140 (listing availability and scheduling) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.4.1.4.3 (screenshot authenticity) — `references.md#commercial-marketplace-1140`.
- Commercial Marketplace certification policies §1140.4.1.4 (screenshot resolution and quality) — `references.md#commercial-marketplace-1140`.
- Teams Store Validation Guidelines — Screenshots section: https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/deploy-and-publish/appsource/prepare/teams-store-validation-guidelines#screenshots

---

## Category 17 — Bundled Surface Co-Presence (`G`)

Applies **only when a non-DA capability coexists with `copilotAgents.declarativeAgents[]`** in the same manifest. These rules extract the static, shift-left signal for the FY26 **runtime-only** policies — full coverage requires executing the agent or rendering its surfaces (the `wiqd agent publish --dry-run` framework). Standalone Teams apps (no `copilotAgents`) are out of scope: every `G` rule is **skipped** for them, not failed. The `copilotAgents` gate matches the activation pattern already used by categories `A`, `X`, `K`, and `W`.

| ID     | Severity    | Summary                                                                                                                                                                                                                                                                       |
| ------ | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **G1** | Must-fix    | _(Gate: `configurableTabs[]` + `copilotAgents`)_ Every `configurableTabs[].configurationUrl` is HTTPS, is not `localhost`/an IP literal, and its host is covered by an entry in `validDomains`                                                                                |
| **G2** | Must-fix    | _(Gate: `bots[]` + `copilotAgents`)_ Each bundled bot declares a non-empty `commandLists`, and its scopes include at least one of `personal` or `team`                                                                                                                        |
| **G3** | Good-to-fix | _(Gate: (`devicePermissions` OR a mobile-scoped tab/bot) + `copilotAgents` — the `hasMobile` gate)_ If the app signals mobile support (`devicePermissions`, or a mobile-scoped tab/bot) but lacks the capability declarations needed for a mobile-compatible experience, warn |

### How to check

- **G1:** For each `configurableTabs[]` entry, parse `configurationUrl` with the `URL` constructor. Reject `protocol !== 'https:'`, `hostname === 'localhost'`, and IPv4/IPv6 literals. Then resolve the host against `validDomains` (exact or wildcard match — reuse the `D9` matcher). Any miss → fail. Complements `D9` (which covers action runtime URLs) for the bundled-tab surface. Network reachability of the URL is **not** checked here — that is Phase 2 `U5`.
- **G2:** Resolve `bots[]`. For each bot, assert `Array.isArray(commandLists) && commandLists.length > 0`, and that the union of the bot's command scopes (`commandLists[].scopes` or the bot's `scopes`) intersects `{ 'personal', 'team' }`. A bot with no commands cannot be exercised by a reviewer and reliably triggers §1140.4.3.1.3.
- **G3:** Heuristic. If `devicePermissions` is present (or any `configurableTabs[]`/`bots[]` entry is scoped for mobile) but no mobile-compatible capability is declared, emit a Good-to-fix warning. Cannot be fully verified statically — full coverage is the mobile-viewport render in `wiqd agent publish --dry-run --browser` (`TT2`).

### Citations

- Commercial Marketplace §1140.4 (Technical requirements — tabs, bots, mobile experience) — `references.md#commercial-marketplace-1140`.
- Copilot / Declarative Agent review validation guidelines → "Declarative agent requirements" — `references.md#copilot-review-validation`.

---

## Adding or Updating Rules

When updating this registry:

1. Re-read each entry in [`references.md`](references.md) and confirm the URL still resolves and the heading still exists.
2. Update the `last_validated` date in [`references.md`](references.md) and the SKILL.md front-matter.
3. Bump rule IDs by appending — never renumber existing IDs (other tools/reports may reference them).
4. If a rule moves between Must-fix and Good-to-fix, note the change in a `CHANGELOG` section at the bottom of this file.

## Changelog

| Date       | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-08-12 | Removed the two-tier (package-advisory + publish-context-enforcement) model: this file ships to 3P, and describing the 1P-only Partner Center publish command's behavior here is out of place regardless of gating. N5's auto-mapped-title note and F3's mobile-screenshot advisory were relocated to the 1P-only extension that owns the publish command; F1/F2/F4–F6/F9–F12's publish-context notes were dropped as either no-ops or duplicates of guidance already documented there. This registry now documents package-only (validate-time) advisories exclusively — rule IDs, severities, and citations unchanged. |
| 2026-08-06 | Publish-time reality check: F4 and F11 are pixel-content judgments that no local check can make, so their publish-context handling is corrected from "enforce" to **advisory** (severity still describes what the reviewer enforces). F12 is corrected to **partially enforced** — the exact 1366×768 dimension gate is hard, sharpness/legibility are reviewer-judged. F4's guidance now states that the caption must be rendered INTO the image; Partner Center exposes no caption field. Severities and counts unchanged.                                                                                             |
| 2026-06-29 | Publish-time enforcement: Upgraded F4, F6, F11 to Must-fix at publish time; updated F6 to enforce max 5 screenshots; added F12 (high-resolution screenshots). 138 rules total.                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 2026-06-26 | Phase 1 runtime-validation shift-left: new Category 17 — Bundled Surface Co-Presence (`G1`–`G3`) + `S5` (auth completeness). 4 rules added (137 total). All gate on `copilotAgents` co-presence with a bundled bot/tab/auth surface; standalone Teams apps are skipped. Static partial coverage for FY26 runtime-only policies §1140.4.2.7.6, §1140.4.3.1.3, §1140.4.8.2.1, §100.14.1.1 — full coverage is the `wiqd agent publish --dry-run` framework.                                                                                                                                                                 |
| 2026-06-24 | Gap-closing rules: Added K9 (confirmation body), B14 (help/contact in description), B15 (description quality), N6 (icon consistency), F11 (no mockup screenshots). 133 rules total.                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| 2026-06-18 | Two-tier federation model: Updated Category 16 (F1–F10) with package-only vs. publish-context "How to check" hints for the Partner Center publish context. Added F9 (categories) and F10 (availability date) as publish-context-only rules. Marked F2 and N5 as auto-enforced at publish time. 128 rules total.                                                                                                                                                                                                                                                                                                          |
| 2026-06-18 | FY26 field-data update: Added M17–M18, B10–B13, A13, R7, new Category 15 (N1–N5 Agent/Plugin Name Consistency), new Category 16 (F1–F8 App Listing & Media). 21 new rules (126 total).                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| 2026-05-27 | Initial registry (P1–P9, M1–M16, B1–B9, I1–I8, D1–D9, A1–A12, X1–X8, K1–K8, S1–S4, L1–L5, R1–R6, W1–W3, U1–U4, C1–C4). 105 rules total. Custom-engine agents (`E` category) are out of scope for this skill.                                                                                                                                                                                                                                                                                                                                                                                                             |
