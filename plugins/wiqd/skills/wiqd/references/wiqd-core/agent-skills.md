# Agent Skills for M365 Copilot Agents

Agent Skills package a reusable playbook — instructions, and optionally companion scripts or
reference files — into a `SKILL.md` folder that Copilot loads on demand, instead of keeping it
permanently resident in the agent's `instructions` text. This guide covers when to use a skill,
the authoring flow through `wiqd agent add skill`, the manifest shape, the platform's validation
codes, and — most importantly — the WIQD feature flag that decides whether skill generation and
packaging are enabled.

> **⛔ TWO HOST-SPECIFIC SKILL SETS — DO NOT REQUIRE DUAL REGISTRATION.**
> `agentSkills[]` (Teams app manifest, camelCase) registers app-level Cowork skills, while
> `agent_skills[]` (declarative-agent manifest, snake_case) registers DA Chat skills. Both use a
> `folder` property and they may deliberately point at the same folder, but they may also name
> different folders. `wiqd plugin add skill` writes the root Cowork registration, while
> `wiqd agent add skill` writes the DA registration. Neither command silently adds the other
> host's registration. Read
> [The Two Surfaces](#the-two-surfaces) before editing either one.

## Overview

An Agent Skill is a folder — `appPackage/skills/<slug>/` — containing a `SKILL.md` file, plus
optional companion files, that Copilot loads progressively rather than all at once:

1. **Frontmatter** (`name` + `description`) loads for every skill at startup, always. The
   `description` is the only content Copilot has already "seen" for a skill that hasn't
   activated yet.
2. **The `SKILL.md` body** loads only once a trigger phrase matches and the skill activates.
3. **`references/` files** load on demand, only when the active skill's own instructions point at
   a specific one.
4. **`scripts/` files** are never loaded into context at all — they're executed, and only their
   output joins the conversation.

This progressive loading is what makes an Agent Skill different from always-on `instructions`
text (capped at 8,000 characters): a skill can carry as much procedural detail as it needs without
permanently occupying the agent's instruction budget.

## The Two Surfaces

A skill folder can be registered on either of two host-specific surfaces. Both arrays use a
`folder` property resolved from the app package, but the registrations are independent: a project
may use Cowork-only skills, DA Chat-only skills, or intentionally point both surfaces at the same
bytes.

|                  | **Teams app manifest**                                                | **Declarative-agent manifest**                                                                    |
| ---------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Array             | `agentSkills[]` (camelCase)                                             | `agent_skills[]` (snake_case)                                                                          |
| Points at         | a Cowork skill folder, via a `folder` property                          | a DA Chat skill folder, via a `folder` property                                                       |
| Written to        | `appPackage/manifest.json`                                              | the declarative-agent manifest                                                                         |
| Copilot exposure  | implied by the entry's presence in the array                           | explicit, via the `expose_skill_to_copilot` boolean — not set automatically (see below)               |
| Validation        | `ASKILL-*` codes (e.g. `ASKILL-P002` if the folder has no `SKILL.md`)   | not yet covered by any `ASKILL-*` code — see below                                                     |
| Produced by       | `wiqd plugin add skill`                                                  | `wiqd agent add skill` — `folder` only; add `expose_skill_to_copilot` yourself                         |

Do not add a second registration merely to satisfy WIQD packaging. The commands preserve the
surface boundary: `wiqd plugin add skill` writes `manifest.json#agentSkills[]`, and
`wiqd agent add skill` writes the declarative-agent manifest's `agent_skills[]`. A DA-only folder
is included by fx-core only when the `agent-skills` packaging capability is active; WIQD now
refuses package/provision while that capability is off instead of producing a known-incomplete
archive.

**Current tooling status:** wiqd's static validator (MVL) does not yet recognize `agent_skills` as
a known member of the declarative-agent manifest — adding the key today is flagged as an
unrecognized property, and there is no dedicated `ASKILL-*` validation for the referenced folder's
content on this surface yet. That reflects a gap between the published schema and the underlying
toolchain, not evidence that the registration doesn't work — the toolchain fully implements and
packages it behind a feature flag (see below); it just isn't in the published schema yet. See
[The Declarative-Agent Registration](#the-declarative-agent-registration-agent_skills) for the
full picture, including why the published schema agrees with MVL's rejection today. Everything
below this point up to that section describes the `agentSkills[]` surface specifically.

## Enable the `agent-skills` Feature Flag First

Enable WIQD's `agent-skills` flag before adding, packaging, provisioning, or publishing a
declarative-agent skill. The
`microsoft.wiqd.core` backend is the only lifecycle backend; when the evaluated WIQD flag is on,
core temporarily sets the SDK environment required for skill generation and packaging during the
fx-core operation, then restores the previous environment afterward. Do not set
SDK-specific environment variables yourself for WIQD flows.

```bash
wiqd config flags set agent-skills true
```

The flag matters for `wiqd agent add skill` and for every fx-core path that builds an app package:
`wiqd agent package`, `wiqd agent provision`, `wiqd plugin package`, and
`wiqd plugin provision`, plus normal `wiqd agent publish` and `wiqd plugin publish`. If a
hand-edited DA manifest contains `agent_skills[].folder` and that
folder is not already registered as a top-level `agentSkills[]` Cowork skill, enable the flag
before package, provision, or publish. WIQD fails before fx-core with the command above when the
folder would otherwise be omitted; it does not add a second registration or rewrite the project.

## When to Use Agent Skills

Reach for an Agent Skill when the agent needs:

- A **detailed, occasionally-needed procedure** (a troubleshooting playbook, a multi-step approval
  process, a style guide) that would crowd out the 8,000-character `instructions` budget if kept
  always-on.
- **Reusable guidance across agents** — a skill folder can be exported and re-imported into
  another project with `wiqd agent add skill --from`, instead of copy-pasting instruction text.
- Content that should load **only when triggered** by specific user phrasing, rather than being
  considered on every turn.

**Don't reach for an Agent Skill when:**

- The guidance is short and always relevant — put it directly in `instructions`.
- The agent needs to call an external API or tool — that's an [API plugin](api-plugins.md) or
  [MCP server plugin](mcp-plugin.md). A skill's `scripts/` files can shell out, but a skill is not
  itself a calling mechanism.
- You're unsure whether the skill belongs in a standalone plugin, an existing agent project, or
  both — see [Where a Skill Lives](#where-a-skill-lives-plugin-agent-or-both) below instead of
  guessing.

## Where a Skill Lives: Plugin, Agent, or Both

Two different `wiqd` commands can produce the same kind of artifact — a `SKILL.md` folder — but
they register it on different host surfaces and operate on different kinds of projects. Pick the
command based on the host and project you already have:

| Question                                                                                   | Command                                                                 | What it does                                                                                                                                                         |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Composing a **new, independent** skill (or a skill-only package), with no existing agent? | `wiqd plugin add skill`                                                 | Composes a capability into a **standalone plugin project** (`wiqd.plugin.json`) from scratch. A plugin can be skill-only — it doesn't require a declarative agent.       |
| Extending an agent project you **already have**?                                          | `wiqd agent add skill`                                                  | Adds the skill directly into that **existing agent project**, in place, through the in-process wiqd core lifecycle backend. Also supports `--from` to import an existing skill directory or `.zip`.                |
| Want the skill **exposed to Copilot directly**, on top of however it got there?           | Add `expose_skill_to_copilot: true` to the matching `agent_skills[]` entry | The entry itself is already written for you by `wiqd agent add skill` — it just doesn't set this property. See [The Declarative-Agent Registration](#the-declarative-agent-registration-agent_skills). |

In short: `wiqd agent add skill` extends an existing agent project by writing an
`agent_skills[]` DA Chat registration. `wiqd plugin add skill` starts or extends a plugin project
by writing a top-level `agentSkills[]` Cowork registration and does not require an agent to exist.
A project that intentionally targets both hosts must maintain both registrations explicitly.

## Authoring Flow

### Step 1: Scaffold or Open an Agent Project

Agent Skills attach to the same `appPackage/` a declarative agent already uses. If there's no
project yet:

```bash
wiqd agent create --name my-agent
```

### Step 2: Run `wiqd agent add skill`

```bash
# Add a new skill
wiqd agent add skill --name "policy-explainer" \
    --description "Explains HR policies in plain language"

# Import an existing skill from another project or a .zip
wiqd agent add skill --from ./weather-lookup.zip
```

#### Options

| Flag             | Description                                                                     |
| ----------------- | ---------------------------------------------------------------------------------- |
| `--name`         | Skill name. Required unless `--from` is used.                                  |
| `--description`  | Skill description. Optional at the CLI, but the shipped `SKILL.md` frontmatter's `description` field is not — a missing or empty one is an `ASKILL-P005` validation Error, not just a discoverability problem. See [Frontmatter Contract](#skillmd-frontmatter-contract). |
| `--from`         | Register a directory already under `appPackage`, or import an external `.zip`. |

`-f`/`--folder` (agent project directory, default `.`) and `-v`/`--verbose` are shared across
every `agent add` subcommand, not specific to `add skill`.

### Step 3: Locate the Generated Files

`wiqd agent add skill` creates the skill folder and registers it in the same operation:

```
appPackage/
└── skills/
    └── policy-explainer/
        └── SKILL.md
```

...and adds a matching entry to the declarative-agent manifest's `agent_skills[]` array — see
[The Declarative-Agent Registration](#the-declarative-agent-registration-agent_skills). You
should not need to hand-edit that array for a normal add or import. The command does not add a
root `appPackage/manifest.json#agentSkills[]` Cowork registration.

**Importing** (`--from`) registers content that already exists — a directory under
`appPackage/skills/`, or the contents of an external `.zip` — so Step 4 doesn't apply; the
`SKILL.md` content is already there. Still run Step 5 (validate) on it — importing doesn't
re-validate the frontmatter for you.

### Step 4: Write the SKILL.md Content

See [SKILL.md Frontmatter Contract](#skillmd-frontmatter-contract) for the required frontmatter
fields. In the body, write clear, imperative instructions — the same way you'd write playbook
steps for a person, since Copilot follows them literally once the skill activates. Keep companion
files inside the skill folder. `references/`, `scripts/`, and `assets/` are useful organizational
conventions, but custom descendant files and directories are allowed by the Agent Skills format —
see [Companion Files](#companion-files) for host-specific limits.

### Step 5: Validate and Package

```bash
wiqd agent validate --mode source --path . --env local
wiqd agent package --path . --env local --output ./appPackage/build/skills.zip
wiqd agent validate --mode package --package-file ./appPackage/build/skills.zip
```

Use `wiqd agent validate --mode package` for this **agent** authoring workflow.
Plugin validation uses the same mode contract; only plugin source mode requires
`wiqd.plugin.json` and `appPackage/manifest.json`. Package validation submits the captured ZIP
to TDP through Core; report actual returned platform diagnostics rather than promising a particular
rule inventory. Source checks only the saved declarative-agent manifest, not top-level
`agentSkills[]` or `SKILL.md` content. See [Validation](#validation-the-askill--codes).

## SKILL.md Frontmatter Contract

Every `SKILL.md` must be fully conformant to the
[Agent Skills specification](https://agentskills.io/specification) — the open, platform-neutral
format `SKILL.md` follows across every host that reads it (Copilot, Claude Code, Cursor, and
others). The required-field limits below are not a wiqd-specific rule layered on top of that spec
— they're the spec's own limits, so conforming to the public specification is exactly what
satisfies the platform's `ASKILL-*` validation codes.

Every `SKILL.md` starts with `---`-delimited YAML frontmatter. The spec requires exactly two
fields — this section documents those two and their naming rules only; it does not cover the
spec's optional fields (`license`, `compatibility`, `metadata`, `allowed-tools`), which wiqd does
not generate:

| Field         | Length             | Constraint                                                                                                                                    |
| ------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | 1–64 characters    | Required. Unicode lowercase alphanumeric characters (`a-z`, `0-9`) and hyphens only. **Must not start or end with a hyphen.** **Must not contain consecutive hyphens (`--`).** **Must exactly match the containing folder's name.** A kebab-case violation is `ASKILL-P007`; a name/folder mismatch is `ASKILL-P006`. |
| `description` | 1–1024 characters  | Required, non-empty — omitting it entirely is an `ASKILL-P005` validation Error, not just a discoverability problem. Should describe both what the skill does **and** when to use it, packed with the keywords a user would actually type — it's the only content Copilot has seen for this skill until it's triggered. |

Valid `name` examples: `pdf-processing`, `data-analysis`, `code-review`. Invalid: `PDF-Processing`
(uppercase letters), `-pdf` (leading hyphen), `pdf--processing` (consecutive hyphens).

```markdown
---
name: policy-explainer
description: Explains HR policies in plain language when a user asks about leave, benefits, or workplace conduct.
---

# Policy Explainer

<the skill's instructions go here>
```

## Companion Files

Agent Skills requires `SKILL.md`. The following descendant directories are conventions, not an
exhaustive allowlist:

- `references/` — supporting documentation, schemas, data files, and examples that Copilot can
  load on demand.
- `scripts/` — executable helpers, subject to the selected host's supported script types and
  runtime.
- `assets/` — templates, images, and other output resources.

Custom names such as `playbooks/` or `workflows/`, and companion files directly under the skill
folder, are format-valid. Do not report a file as misplaced or unsupported solely because it is
outside `references/`, `scripts/`, or `assets/`. Host-specific restrictions still apply to every
companion file.

### Cowork plugin limits (`manifest.json#agentSkills[]`)

For a skill registered in the root Teams manifest's `agentSkills[]`, Microsoft 365 Copilot Cowork
applies these limits:

| Limit                          | Maximum |
| ------------------------------ | ------- |
| Companion files per skill      | 20      |
| Size per companion file        | 5 MB    |
| Total companion size per skill | 10 MB   |

`SKILL.md` is required and does not count as one of the 20 companion files. Every other descendant
file counts, regardless of whether it is in a conventional or custom directory. Each companion-file
path must also be relative (no absolute paths), free of `..` segments, backslashes, and null bytes;
not a hidden file (no leading `.` in the filename); not a Windows reserved name (`CON`, `PRN`,
`AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`, with or without an extension); and composed of safe
filename characters only.

### Declarative-agent limits (`declarativeAgent.json#agent_skills[]`)

A skill referenced only by a declarative agent's `agent_skills[]` uses the DA limits instead: at
most 8 skills per agent, 350 files across all skills, and directory depth 3.

| Limit                                        | Maximum |
| -------------------------------------------- | ------- |
| Skills per declarative agent                 | 8       |
| Files across all skills                      | 350     |
| Directory depth                              | 3       |
| Agent Builder file size                      | 25 MB   |
| Agent Builder skill ZIP                      | 50 MB   |
| Agents Toolkit complete application package  | 10 MB   |

Agents Toolkit uses a skill directory and does not state a separate DA skill-level per-file limit.
The supported file and script types still apply. Cowork's 20-companion limit does not apply to a
DA-only skill.

If a plugin contains a declarative agent but the skill is registered through the root
`agentSkills[]`, that root registration remains a Cowork plugin skill. If the same folder is
registered on both surfaces, it must satisfy both sets of constraints.

These limits and surface distinctions were verified on October 14, 2026 against the
[Cowork plugin development documentation](https://learn.microsoft.com/microsoft-365/copilot/cowork/cowork-plugin-development),
the
[declarative-agent custom skills documentation](https://learn.microsoft.com/microsoft-365/copilot/extensibility/declarative-agent-skills),
and the [Agent Skills specification](https://agentskills.io/specification).

## Manifest Shape: `agentSkills[]` (Shipped Today)

`agentSkills[]` is a root-level array in `appPackage/manifest.json` (the Teams app manifest) — a
sibling of `agentConnectors[]`, not a property of `declarativeAgent.json`. Each entry has exactly
one field:

```json
{
  "agentSkills": [{ "folder": "./skills/policy-explainer" }]
}
```

| Field    | Description                                                                                                          |
| -------- | ---------------------------------------------------------------------------------------------------------------------- |
| `folder` | Path to the skill's folder, relative to `manifest.json` itself (i.e. relative to `appPackage/`) — `./skills/<slug>` for a wiqd-authored skill. |

**Platform limits — enforced by the platform, not advisory:**

| Limit                                    | Value           | Violation if exceeded |
| ------------------------------------------ | ------------------ | ------------------------ |
| Maximum entries in `agentSkills[]`       | 20               | `ASKILL-M002`          |
| Maximum `folder` path length             | 256 characters   | `ASKILL-M003`          |
| Duplicate `folder` values across entries | not allowed      | `ASKILL-P008`          |

## The Declarative-Agent Registration: `agent_skills[]`

`agent_skills[]` (snake_case) is the declarative-agent manifest's DA Chat registration. It is
independent from the app manifest's `agentSkills[]` Cowork registration and uses the same
package-root-relative `folder` property shape. Identical folder values deliberately share bytes;
different values preserve separate host-specific skill sets. Every referenced folder contains an
uppercase `SKILL.md`; there is no lowercase `skill.md` variant:

```json
{
  "agent_skills": [
    {
      "folder": "./skills/policy-explainer",
      "expose_skill_to_copilot": true
    }
  ]
}
```

`wiqd agent add skill` already writes this entry for you today: the underlying fx-core
`addSkill` call initializes `agent_skills[]` if it's missing and pushes `{ folder }` —
**`folder` only**. It does not set `expose_skill_to_copilot`; add that property yourself, to the
entry `wiqd agent add skill` already wrote, when you want the skill exposed to Copilot directly.

**Required manifest version:** an agent that uses `agent_skills[]` must set the declarative-agent
manifest's `version` field to the exact value `"v1.9"`:

```json
{
  "version": "v1.9",
  "agent_skills": [{ "folder": "./skills/policy-explainer" }]
}
```

`wiqd agent add skill` enforces this after the backend succeeds, preserving every other manifest
field. This is the `version` field in `appPackage/declarativeAgent.json`, not the separate
`manifestVersion` field in the Teams app's `appPackage/manifest.json`. `wiqd plugin add skill`
does not perform this declarative-agent update — it only writes the Teams app's `agentSkills[]`
entry, since a skill-only plugin may have no declarative agent for `agent_skills[]` to attach to.

Grounded facts about this registration:

- The array key is snake_case (`agent_skills`), not camelCase, and it lives in the
  declarative-agent manifest rather than `appPackage/manifest.json`. The underlying toolchain also
  accepts an `x-agent_skills` (extension-prefixed) form as a packaging-time fallback, but
  `wiqd agent add skill` always writes to `agent_skills`, never the `x-` form.
- The entry's only confirmed path property is `folder` — the same package-root-relative shape as
  `agentSkills[]`'s `folder`, without requiring the same value or a matching top-level entry. Do
  not invent IDs or capability gates.
- Exposure is the explicit `expose_skill_to_copilot` boolean. It is not written automatically by
  `wiqd agent add skill` — set it yourself in the entry already on disk.
- `agent_skills` is not present in the published declarative-agent manifest schema: the v1.8
  schema (`https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v1.8/schema.json`)
  declares a closed `propertyNames` enum that excludes it, and no later schema version is publicly
  published yet — so wiqd's static validator (MVL) currently rejects an `agent_skills` key as an
  unrecognized member, matching the published schema. That is a **schema-publication gap, not a
  toolchain gap**: the underlying toolchain fully implements `agent_skills[]`, including packaging
  the referenced skill folders into the built `.zip` when WIQD's `agent-skills` flag is enabled —
  it just isn't in the published schema yet. Treat captured-package validation and the
  platform itself as the authority on whether an entry is accepted, and re-check this reference
  once a schema that includes `agent_skills` is published.

## Validation: the `ASKILL-*` Codes

The `ASKILL-*` codes are the Microsoft 365 Copilot platform's own Agent Skills validation codes —
emitted by **AVL** (App Validation Library) and at upload/submission time, not defined or
implemented by wiqd. `wiqd agent validate --mode source` does not check top-level `agentSkills[]`
or `SKILL.md` content. Build first, then use `--mode package --package-file "<zip>"` and inspect
the platform diagnostics actually returned. Plugin package validation uses the same captured-ZIP
runtime and does not require a plugin source project.
A source pass is not skill-package acceptance; perform package validation before submission.

### Manifest-Level Codes

Fire against the `agentSkills[]` array itself, before the package is even opened. All severity
Error:

| Code          | Fires when                                                             | Authoring mistake                                                                             | Fix                                                                                       |
| ------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `ASKILL-M001` | An `agentSkills[]` entry is missing its required `folder` property     | A hand-edited or partially-written entry has no `folder` key at all                            | Add `folder` pointing at the skill's directory, e.g. `"folder": "./skills/policy-explainer"` |
| `ASKILL-M002` | The `agentSkills` array declares more than 20 entries                  | Too many skills accumulated in one package, often after merging plugins via `agent add plugin --from` | Consolidate related skills into fewer, broader `SKILL.md` files, or remove unused entries — 20 is a hard ceiling |
| `ASKILL-M003` | An `agentSkills[]` entry's `folder` path is longer than 256 characters | An overly long or deeply-nested slug, often carried over from an imported `--from` path         | Shorten the folder name — it only needs to be unique under `appPackage/skills/`, not descriptive |

### Package-Level Codes

Fire once the referenced skill folders are actually opened inside the built `.zip`. All severity
Error:

| Code          | Fires when                                                       | Authoring mistake                                                                                                    | Fix                                                                                        |
| ------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `ASKILL-P001` | The folder an `agentSkills[]` entry points at doesn't exist in the package | The folder was deleted, renamed, or excluded from the build after the manifest entry was written                    | Restore the folder under `appPackage/skills/`, or remove the stale manifest entry              |
| `ASKILL-P002` | That folder has no `SKILL.md` file                                | The folder exists but is empty, or holds only `references/`/`scripts/` companion files with no top-level `SKILL.md` | Add `SKILL.md` directly inside the folder, at its root                                        |
| `ASKILL-P003` | `SKILL.md`'s frontmatter isn't valid, `---`-delimited YAML        | The opening/closing `---` fences are missing or mismatched, or the YAML between them doesn't parse                  | Confirm the file opens with `---` on line 1, closes the block with a second `---`, and the YAML in between is valid |
| `ASKILL-P004` | `SKILL.md` frontmatter has no `name` field                       | The frontmatter is valid YAML but `name` was never filled in — common when a template placeholder was deleted instead of completed | Add `name: <kebab-case-slug>`                                                                  |
| `ASKILL-P005` | `SKILL.md` frontmatter has no `description` field                | Same class of omission as `ASKILL-P004`, for `description` — often skipped because the folder name seemed self-explanatory | Add a `description` stating when Copilot should trigger this skill                             |
| `ASKILL-P006` | `SKILL.md`'s `name` doesn't match its containing folder's name    | The skill was renamed on only one side — folder renamed but frontmatter left stale, or vice versa, easy to do with a manual `mv` | Rename both together; treat folder name and frontmatter `name` as one value, never edited independently |
| `ASKILL-P007` | `SKILL.md`'s `name` isn't valid kebab-case                       | `name` has uppercase letters, underscores, spaces, a leading/trailing hyphen, or consecutive hyphens (e.g. `Policy_Explainer`, `policy--explainer`) | Rewrite using only lowercase letters, digits, and single hyphens                               |
| `ASKILL-P008` | Two or more `agentSkills[]` entries point at the same `folder`   | An entry was copy-pasted to add a second skill, but its `folder` value was never changed to point at the new directory | Give every entry a distinct `folder`                                                           |

## Runtime Behavior

Once a skill passes validation and the package is live, its `SKILL.md` frontmatter `description`
is what Copilot's orchestrator matches against user phrasing to decide whether to load the skill —
the same trigger-phrase mechanic used for API-plugin function `description` fields (see
[API Plugins](api-plugins.md)). A vague or generic `description` means the skill may never
trigger; one that packs in the actual phrases users say is what makes the skill discoverable.

Loading is progressive, not all-or-nothing:

1. Every skill's frontmatter loads at startup, always — the only part of an unused skill Copilot
   has already "seen."
2. The `SKILL.md` body loads only once a trigger phrase matches.
3. `references/` files load on demand, only when the active skill's own instructions point at one.
4. `scripts/` files are executed, not loaded — only their output joins the conversation.

**The WIQD `agent-skills` flag has no runtime effect on a shipped, validated agent.** It only
gates whether the authoring toolchain can generate skill artifacts and whether fx-core package
generation during agent/plugin package, provision, or publish includes DA-only skill folders — see
[Enable the `agent-skills` Feature Flag First](#enable-the-agent-skills-feature-flag-first). Once
a skill is packaged and validated, Copilot's runtime behavior toward it is identical regardless of
which flag state originally produced it.

## Common Issues

| Issue                                                              | Cause                                                                    | Solution                                                                                          |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Package/provision/publish refuses a DA-only skill folder | WIQD's `agent-skills` flag is disabled and no top-level `agentSkills[]` Cowork registration would include that exact archive path | Run `wiqd config flags set agent-skills true`, then retry. Do not add an unrelated top-level registration just to bypass the check. |
| `wiqd agent add skill` fails or produces an incomplete manifest    | WIQD's `agent-skills` flag is disabled | Enable the flag — see [Enable the `agent-skills` Feature Flag First](#enable-the-agent-skills-feature-flag-first) — and re-run the command |
| Skill never triggers in conversation                               | `description` is too generic, or doesn't contain the phrases users actually say | Rewrite `description` around real trigger phrases, not a summary of the skill's purpose             |
| Source validation passes but the upload still fails | Source does not check top-level `agentSkills[]` or `SKILL.md` | Build, then run `wiqd agent validate --mode package --package-file "<zip>"`; inspect returned diagnostics |
| Manifest edit didn't produce a working skill                       | A skill registration was hand-edited without also creating a matching `SKILL.md` folder | Use `wiqd agent add skill` for `agent_skills[]` or `wiqd plugin add skill` for root `agentSkills[]`; if you must hand-edit, create the folder and the matching entry together |
| Imported skill (`--from`) behaves differently than expected | `--from` registers content as-is; it does not validate or rewrite `SKILL.md` | Build and validate the final package; the frontmatter contract still applies to imported skills |

## Best Practices

1. **Enable the flag before add, package, provision, or publish.** Confirm WIQD's `agent-skills` flag is
   enabled before attempting the DA skills path and before `wiqd agent package`,
   `wiqd agent provision`, `wiqd agent publish`, `wiqd plugin package`,
   `wiqd plugin provision`, or `wiqd plugin publish` when a DA-only folder is present.
2. **Keep `name` and folder in lockstep.** Treat the frontmatter `name` and the containing folder
   name as a single value — rename both together, always.
3. **Write `description` for triggering, not for summarizing.** Pack in the actual phrases a user
   would say; a technically-accurate but generic description means the skill may never activate.
4. **Preserve the intended host scope.** Use `agentSkills[]` for Cowork, `agent_skills[]` for DA
   Chat, or both when both hosts should load the same folder. Use `wiqd plugin add skill` for the
   Cowork registration and `wiqd agent add skill` for the DA registration. For a hand-authored
   DA-only entry, keep the flag enabled before package/provision rather than adding an unrelated
   top-level registration. Add
   `expose_skill_to_copilot: true` only when that DA behavior is intended.
5. **Run package validation before publishing.** `wiqd agent validate --mode source` cannot see
   `agentSkills[]` or `SKILL.md` content — always follow `wiqd agent package` with
   `wiqd agent validate --mode package --package-file "<zip>"` before a submission.
6. **Prefer the matching command over hand-editing.** `wiqd agent add skill` creates the folder and
   DA registration together; `wiqd plugin add skill` creates the folder and Cowork registration
   together.
7. **Mind the host-specific ceilings.** Root Cowork `agentSkills[]` allows at most 20 entries,
   limits each `folder` value to 256 characters, and rejects duplicate `folder` values. DA
   `agent_skills[]` allows at most 8 skills per agent. Apply the constraints for each surface where
   the folder is registered.

## Related Documentation

- [API Plugins](api-plugins.md) — the other in-DA capability for calling external systems
- [MCP Server Plugin Integration](mcp-plugin.md) — another flag-adjacent, manifest-shape-driven capability
- [Manifest Schema Reference](schema.md) — version compatibility and how to look up capability properties
- [M365 Agent Developer Best Practices](best-practices.md)
