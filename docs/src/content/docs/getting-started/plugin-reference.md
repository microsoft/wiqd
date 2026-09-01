---
title: Plugin authoring reference
description: Reference material for authoring M365 Copilot plugins with wiqd — package anatomy, SKILL.md frontmatter rules, companion-file limits, connector requirements, auth types, and the validation codes that gate publishing.
---

# Plugin authoring reference

This page is a **reference**, not a how-to — for the step-by-step walkthrough, see
[Build a Plugin](/getting-started/build-a-plugin/). It documents the constraints of the M365 app-package format
itself, and maps each one to where `wiqd plugin` surfaces it.

:::caution
**Alpha.** The `wiqd plugin` command tree is enabled by default, but the surface is still alpha and
the interface may change without notice.
:::

## Package anatomy

The table below lists the files under the project's `appPackage/` directory — the same layout
`wiqd agent` scaffolds. Alongside it, at the project root, sit the wiqd descriptor
`wiqd.plugin.json`, the ATK lifecycle file `m365agents.yml`, and the per-environment `env/.env.<env>`
files that `provision` writes.

| Path (under `appPackage/`)   | Purpose                                                                 |
| ----------------------------- | ------------------------------------------------------------------------ |
| `manifest.json`               | The top-level Teams app manifest — declares the app and its components |
| `color.png`                   | Full-color app icon, 192×192                                            |
| `outline.png`                 | Transparent outline icon, 32×32                                        |
| `declarativeAgent.json`       | The declarative-agent component (if the plugin composes an agent)      |
| `instruction.txt`             | The declarative agent's instructions, referenced by `declarativeAgent.json` |
| `skills/<slug>/SKILL.md`      | A skill component — one folder per skill                               |
| `ai-plugin.json`              | An API-plugin manifest, at the package root — present only when a composed agent brings API-plugin `actions[]` |
| `apiSpecificationFile/`       | The OpenAPI spec(s) backing those API-plugin actions                   |

**A key divergence from hand-authoring:** `wiqd plugin create` pins the manifest to
`manifestVersion: "1.29"` — a numbered, GA Teams schema — rather than hand-editing `1.28` or
`devPreview`. That version choice has a real behavioral consequence for connectors: at **1.29**,
`agentConnectors[]` entries are **URL-only** and `mcpToolDescription` becomes optional; at **1.28**,
`mcpToolDescription` is required, and if its referenced file isn't included in the upload ZIP the
upload fails with an HTTP 400. Authoring against wiqd's pinned 1.29 schema sidesteps that failure
mode entirely — there's no tool-description file to forget.

## SKILL.md frontmatter rules

Every skill's `SKILL.md` starts with YAML frontmatter. Two fields are load-bearing:

| Field         | Constraint                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------- |
| `name`        | 1–64 characters, kebab-case, **must match its containing folder name exactly**              |
| `description` | 1–1024 characters, should contain the trigger phrases that should surface the skill        |

The single most common authoring mistake is a `name` that doesn't match its folder — the two are
required to agree, and a mismatch is easy to introduce by renaming one without the other.

**Kebab-case, precisely:** lowercase alphanumeric characters and hyphens only. No underscores, no
uppercase letters, no leading/trailing hyphens, and no consecutive hyphens.

| `name`             | Valid? | Why                                    |
| ------------------ | ------ | --------------------------------------- |
| `triage-issues`     | ✅     | lowercase, hyphen-separated             |
| `triage-issues-v2`  | ✅     | digits are fine after a hyphen          |
| `Triage_Issues`     | ❌     | uppercase letters and an underscore     |
| `-triage-issues`    | ❌     | leading hyphen                          |
| `triage--issues`    | ❌     | consecutive hyphens                     |
| `triage-issues-`    | ❌     | trailing hyphen                         |

## Three-layer context-loading model

A skill's content loads progressively, not all at once — this keeps a busy plugin's context
footprint small until a specific skill is actually needed:

1. **Frontmatter** — loaded for every skill at startup, always. This is why `description` must
   carry the trigger phrases: it's the only part of an unused skill an agent has already seen.
2. **`SKILL.md` body** — loaded only once a trigger phrase matches and the skill activates.
3. **`references/`** — loaded on demand, only when the active skill's instructions point at a
   specific reference file.

A fourth category, **`scripts/`**, is never loaded into context at all — scripts are executed, and
only their output (not their source) becomes part of the conversation.

## Companion-file limits

A skill folder may carry companion files (under `references/` and `scripts/`) subject to:

- **At most 20 files** per skill.
- **At most 5 MB** per individual file.
- **At most 10 MB** total across the skill folder.

Every companion-file path must additionally be:

- **Relative** — no absolute paths.
- Free of `..` path segments, backslashes, and null bytes.
- Not a **hidden file** — no leading `.` in the filename.
- Not a **Windows reserved name** — `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9` (with
  or without an extension) are all rejected.
- Composed of safe filename characters only.

## Connector / remote MCP server requirements

An agent connector that fronts a remote MCP server must satisfy:

- **HTTPS** with **TLS 1.2 or later**.
- **Streamable HTTP** transport, speaking **JSON-RPC 2.0**.
- Support for both the `tools/list` and `tools/call` methods.
- Each tool call completing in **under 30 seconds**.

**wiqd's divergence:** `wiqd plugin add connector` writes a **URL-only** entry under
manifest 1.29 — the server is expected to advertise its own tools at runtime, so wiqd does not
scaffold a separate `mcpToolDescription` file the way a 1.28-schema manifest requires.

`add connector` also enforces caps before writing, so an out-of-bounds entry never reaches the
manifest in the first place:

| Field                          | Cap                        |
| -------------------------------- | ---------------------------- |
| Connectors per manifest          | ≤ 10                       |
| `id` (derived from `--name`)     | ≤ 64 characters            |
| `displayName` (from `--name`)    | ≤ 128 characters           |
| `description` (from `--description`) | ≤ 4000 characters       |
| `mcpServerUrl` (from `--url`)    | ≤ 2048 characters          |

## Auth types

A connector or API plugin can declare one of these authentication types:

- **`None`** — no authentication.
- **`OAuthPluginVault`** — OAuth, with tokens managed by the plugin vault.
- **`ApiKeyPluginVault`** — API-key authentication, with the key managed by the plugin vault. Note
  that API-key auth is **not yet available in Cowork** — use OAuth or Dynamic Client Registration
  (DCR) there instead.

Dynamic Client Registration (DCR) is not itself a manifest auth *type* — it's a mechanism where the
connector registers its own OAuth client at runtime instead of using a pre-configured client ID. A
DCR-backed connector still resolves to the `OAuthPluginVault` type in the manifest.

`wiqd plugin add connector` is **URL-only** today and does not scaffold connector authentication —
if your MCP server or API plugin needs auth, configure it directly per the M365 Copilot
extensibility documentation; wiqd doesn't yet automate that step.

## Validation codes

Static `wiqd plugin validate` covers only the declarative-agent (MVL) surface. Everything below
surfaces only at `wiqd plugin validate --mode deep` (package-first AVL) or at upload/submission
time — knowing which layer owns which code tells you where in your workflow a given failure will
actually appear. The `ASKILL-*` codes are the Microsoft 365 Copilot platform's own Agent Skills
validation codes (emitted by AVL and at upload), not wiqd-defined — wiqd surfaces them by running
deep validation against that platform.

### Manifest-level codes

These fire against the manifest's `agentSkills[]` array itself, before the package is even
inspected — all are severity Error:

| Code          | Meaning                                                                  |
| ------------- | ------------------------------------------------------------------------- |
| `ASKILL-M001` | An `agentSkills[]` entry is missing its required `folder` property        |
| `ASKILL-M002` | The `agentSkills` array declares more than 20 entries                    |
| `ASKILL-M003` | An `agentSkills[]` entry's `folder` path is longer than 256 characters   |

### Package-level codes

These fire once the referenced skill folders are actually opened inside the ZIP — all are
severity Error:

| Code          | Meaning                                                                  |
| ------------- | ------------------------------------------------------------------------- |
| `ASKILL-P001` | The folder an `agentSkills[]` entry points at doesn't exist in the package |
| `ASKILL-P002` | That folder has no `SKILL.md` file                                       |
| `ASKILL-P003` | `SKILL.md`'s frontmatter isn't valid, `---`-delimited YAML               |
| `ASKILL-P004` | `SKILL.md` frontmatter has no `name` field                               |
| `ASKILL-P005` | `SKILL.md` frontmatter has no `description` field                       |
| `ASKILL-P006` | `SKILL.md`'s `name` doesn't match its containing folder's name           |
| `ASKILL-P007` | `SKILL.md`'s `name` isn't valid kebab-case                               |
| `ASKILL-P008` | Two or more `agentSkills[]` entries point at the same `folder`           |

Companion-file size and path violations aren't part of this numbered set — they're rejected under
the rules in [Companion-file limits](#companion-file-limits) instead.

### Connector validation

Connectors are validated as part of the same package-first pass, against a separate set of
platform rules rather than numbered `ASKILL-*` codes:

- Every connector needs both an `id` and a `displayName`, and `id`s must be unique across the
  manifest's connector list.
- A connector must pick exactly one tool source — either `plugin` or `remoteMcpServer` — never
  both, never neither.
- `mcpServerUrl` must be a well-formed HTTPS URL.
- On manifest **1.28**, a `remoteMcpServer` connector must also carry `mcpToolDescription`, and the
  file it names must be present in the uploaded ZIP. wiqd's `add connector` targets the pinned
  **1.29** schema and writes URL-only entries, so wiqd-authored connectors never carry this field
  and never hit this rejection — see [Package anatomy](#package-anatomy) for why.
- `authorization.referenceId` is required whenever the auth type isn't `None`, and conversely must
  be absent when the type is `None`.

### Where each surfaces

| Failure class                                                                | Surfaces at                                                                        |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Declarative-agent manifest / API-plugin manifest / OpenAPI errors             | `wiqd plugin validate` (static, MVL)                                                |
| `ASKILL-*` codes, connector validation rules                                  | `wiqd plugin validate --mode deep` (package-first, AVL), and at upload/submission    |
| Top-level manifest `additionalProperties` rejections (a field the Cowork plugin schema doesn't define, under manifest 1.28) | `wiqd plugin validate --mode deep`, and at upload/submission — a separate, unnumbered schema rejection, not an `ASKILL-*` code |

## Cross-platform SKILL.md portability

`SKILL.md` follows the open Agent Skills standard, which is not wiqd- or Copilot-specific — the same
file format is understood by Claude Code, VS Code / GitHub Copilot, Gemini CLI, Cursor, JetBrains
Junie, OpenAI Codex, and other agent hosts. Authoring a skill once and exporting it (see
[Import / export](/getting-started/build-a-plugin/#import--export-interop)) is how you carry it to those other
tools without hand-translating the format.

## Skill-authoring best practices

- **Be specific about triggers.** Phrase `description` as "Use when the user asks to…" rather than
  a generic capability summary — vague descriptions produce skills that either never activate or
  activate for the wrong requests.
- **Write numbered workflow steps** that map to concrete, executable actions, not abstract
  guidance.
- **Define an explicit output format** so the agent's response is predictable and testable.
- **Reference connector tools by name.** If the skill drives an MCP connector, name its tools
  explicitly rather than describing them vaguely — inspect the server's advertised tool list before
  writing the instructions.
- **Keep `SKILL.md` lean.** Move detailed or rarely-needed material into `references/` — remember
  the body loads on every trigger, but references load only on demand.
- **Never embed secrets** in `SKILL.md` or any companion file. Use connector auth (see
  [Auth types](#auth-types)) instead.

## Learn-parity table

Every section of the Microsoft Learn "Build plugins for Copilot Cowork" page, mapped to its wiqd
equivalent:

| Learn section                     | Status                                                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| Package anatomy                      | **Covered here** — [Package anatomy](#package-anatomy)                                                  |
| Convert a Claude plugin               | **Covered** — [`wiqd plugin import`](/getting-started/build-a-plugin/#import--export-interop) replaces `Convert-ClaudePluginToMOS3.ps1` |
| Create a skill                       | **Covered** — [Build a Plugin → Path 1 & 2](/getting-started/build-a-plugin/), [SKILL.md frontmatter rules](#skillmd-frontmatter-rules) |
| Reference materials                  | **Covered** — [Three-layer context-loading model](#three-layer-context-loading-model)                   |
| Connector (MCP)                      | **Covered** — [Connector / remote MCP server requirements](#connector--remote-mcp-server-requirements)  |
| Manifest                             | **Covered** — [Package anatomy](#package-anatomy)                                                       |
| Icons                                 | **Covered** — [Package anatomy](#package-anatomy) (192×192 / 32×32)                                    |
| Package (zip with Compress-Archive)   | **Covered, different mechanism** — `wiqd plugin package` replaces hand-zipping                          |
| Test / sideload                       | **Covered, different mechanism** — `wiqd plugin provision` + `wiqd plugin share` replace raw `atk install` sideloading |
| Publish to tenant                     | **Covered** — [Build a Plugin → Publishing paths](/getting-started/build-a-plugin/#publishing-paths)                    |
| Publish to the public store           | **Out of scope for wiqd** — Partner Center certification/submission is a human/admin step outside wiqd; see [Publishing paths](/getting-started/build-a-plugin/#publishing-paths) |
| Test connector via dev tunnels         | **Out of scope for wiqd** — wiqd does not manage dev tunnels; expose your MCP server yourself and pass its public `https://` URL to `wiqd plugin add connector` |
| Packaging patterns                    | **Covered** — [Package anatomy](#package-anatomy)                                                       |
| Skill best practices                  | **Covered** — [Skill-authoring best practices](#skill-authoring-best-practices)                          |
| Validation rules                      | **Covered** — [Validation codes](#validation-codes)                                                     |
| Cross-platform (Claude, Cursor, etc.) | **Covered** — [Cross-platform SKILL.md portability](#cross-platform-skillmd-portability), [`wiqd plugin export`](/getting-started/build-a-plugin/#import--export-interop) |
| MCP annotations                       | **Out of scope for wiqd** — `wiqd plugin add connector` is URL-only and does not scaffold tool-level MCP annotations; the remote server owns them |
| Common questions                      | **Covered** — spread across this page and [Build a Plugin](/getting-started/build-a-plugin/); ask the conversational path (see [Path 1](/getting-started/build-a-plugin/#path-1--build-it-conversationally)) for anything not covered |

## Go deeper

- [Build a Plugin](/getting-started/build-a-plugin/) — the step-by-step walkthrough (agentic and CLI paths)
- [What is a plugin?](/concepts/plugins/) — the mental model and the three meanings of "skill"
- [`wiqd plugin`](/cli/reference/#wiqd-plugin) — the full command reference
- [`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) — static vs. deep validation
