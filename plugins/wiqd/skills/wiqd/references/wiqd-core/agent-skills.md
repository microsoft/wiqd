# Agent Skills for M365 Copilot Agents

Agent Skills package a reusable playbook — instructions, and optionally companion scripts or
reference files — into a `SKILL.md` folder that Copilot loads on demand, instead of keeping it
permanently resident in the agent's `instructions` text. This guide covers when to use a skill,
the authoring flow through `wiqd agent add skill`, the manifest shape, the platform's validation
codes, and — most importantly — the environment-variable gate that decides whether skill
generation even works on your machine.

> **⛔ ONE SKILL FOLDER, TWO REGISTRATIONS — DON'T MIX UP THE SYNTAX.** A single skill folder —
> `appPackage/skills/<slug>/SKILL.md` — is the one underlying artifact. `agentSkills[]` (Teams app
> manifest, camelCase) and `agent_skills[]` (declarative-agent manifest, snake_case) are two
> registrations that both use the same `folder` property to point at that same folder —
> `wiqd agent add skill` already writes both of them for you today. The second one is what exposes
> the skill to Copilot, via its `expose_skill_to_copilot` boolean; that property isn't set
> automatically, so add it yourself in the entry already on disk when you want the exposure. Read
> [The Two Surfaces](#the-two-surfaces) before touching either one — the two registrations differ
> only in array key casing (camelCase `agentSkills` vs. snake_case `agent_skills`) and which
> manifest they live in, and an `agentSkills[]` entry missing its required `folder` property fires
> `ASKILL-M001`.

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

A skill folder — `appPackage/skills/<slug>/SKILL.md` — can be registered on two different
surfaces. Both registrations point at the exact same folder, through the exact same `folder`
property: they are two registrations of one artifact, not two independent experiences that each
need their own files.

|                  | **Teams app manifest**                                                | **Declarative-agent manifest**                                                                    |
| ---------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Array             | `agentSkills[]` (camelCase)                                             | `agent_skills[]` (snake_case)                                                                          |
| Points at         | the skill's folder, via a `folder` property                            | the same skill's folder, via the same `folder` property                                              |
| Written to        | `appPackage/manifest.json`                                              | the declarative-agent manifest                                                                         |
| Copilot exposure  | implied by the entry's presence in the array                           | explicit, via the `expose_skill_to_copilot` boolean — not set automatically (see below)               |
| Validation        | `ASKILL-*` codes (e.g. `ASKILL-P002` if the folder has no `SKILL.md`)   | not yet covered by any `ASKILL-*` code — see below                                                     |
| Produced by       | `wiqd agent add skill`, automatically                                   | also `wiqd agent add skill`, automatically — `folder` only; add `expose_skill_to_copilot` yourself     |

Use `agent_skills[]` **in addition to** `agentSkills[]`, not instead of it — `wiqd agent add skill`
already writes both entries for you, pointing at the identical folder through the identical
`folder` property. The Teams app manifest registration is what makes the folder a skill at all;
the declarative-agent registration is what exposes it to Copilot directly, once you set its
`expose_skill_to_copilot` boolean to `true` yourself — that part isn't automatic.

**Current tooling status:** wiqd's static validator (MVL) does not yet recognize `agent_skills` as
a known member of the declarative-agent manifest — adding the key today is flagged as an
unrecognized property, and there is no dedicated `ASKILL-*` validation for the referenced folder's
content on this surface yet. That reflects a gap between the published schema and the underlying
toolchain, not evidence that the registration doesn't work — the toolchain fully implements and
packages it behind a feature flag (see below); it just isn't in the published schema yet. See
[The Declarative-Agent Registration](#the-declarative-agent-registration-agent_skills) for the
full picture, including why the published schema agrees with MVL's rejection today. Everything
below this point up to that section describes the `agentSkills[]` surface specifically.

## Check the `TEAMSFX_AGENT_SKILLS` Flag First

Enable WIQD's `agent-skills` flag before adding a DA skill. With the in-process FxCore
backend, that evaluated flag also enables `ATK_FRONTIER` during SDK operations, including
packaging, provisioning, and publishing; wiqd restores the previous value afterward.
No separate SDK environment setting is needed for this backend.

The `TEAMSFX_AGENT_SKILLS` checks and shell instructions below apply only to the legacy
`microsoft.atk` backend, whose environment handling is unchanged:

| Backend                                              | What happens to the flag                                                                                                                                     | What you must do                                                                    |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `microsoft.wiqd.core` (in-process fx-core)            | wiqd temporarily sets `ATK_FRONTIER=true` during SDK operations when the evaluated `agent-skills` flag is enabled, then restores the previous value          | Enable WIQD's `agent-skills` flag for generation and packaging                   |
| `microsoft.atk` (shells out to ATK via `ManifestExecutor`) | wiqd never sets this variable — it appears in zero extension manifests. The spawned ATK subprocess inherits the parent process's entire environment, so whatever is (or isn't) set on the machine is exactly what ATK sees | **You must confirm the variable is already set on the machine — this is the load-bearing case** |

A machine-level value set once genuinely enables skill generation on the ATK path today, because
subprocess environments are inherited wholesale, not curated. Check it directly before proceeding:

- Windows PowerShell: `$env:TEAMSFX_AGENT_SKILLS`
- macOS/Linux: `echo $TEAMSFX_AGENT_SKILLS`

**If it is unset (or not `true`) and the active backend is `microsoft.atk`:** do not run
`wiqd agent add skill` expecting it to work — tell the user directly instead of letting the
command fail opaquely:

> "Agent Skills needs the `TEAMSFX_AGENT_SKILLS` environment variable set on this machine before I
> can generate one. I'll show you how to set it, then we can try again."

Then give the exact command for their shell:

**Windows PowerShell — current session only:**

```powershell
$env:TEAMSFX_AGENT_SKILLS = 'true'
```

**Windows PowerShell — persists across sessions:**

```powershell
[Environment]::SetEnvironmentVariable('TEAMSFX_AGENT_SKILLS', 'true', 'User')
```

**macOS/Linux — current shell only:**

```bash
export TEAMSFX_AGENT_SKILLS=true
```

**macOS/Linux — persists across sessions:**

```bash
echo 'export TEAMSFX_AGENT_SKILLS=true' >> ~/.zshrc   # or ~/.bashrc, depending on the user's shell
```

A "current session only" `export`/`$env:` set is not visible to a process that was already
running when it was set — after setting it, re-run `wiqd agent add skill` in the same shell, not
in a separate one.

**On the legacy ATK backend, the flag also gates packaging, not just generation.** `wiqd agent package` copies each
`agent_skills[]`-referenced skill folder into the built `.zip` only when `TEAMSFX_AGENT_SKILLS` is
set at package time — if it's unset, that packaging step silently skips those directories
entirely, with no warning. This means the flag must be set for **both** commands, not just
`add skill`: generating a skill with the flag on, then running `wiqd agent package` in a later
shell or CI job where the flag isn't set, produces a package that's silently missing its skill
directories. Check the flag before `wiqd agent package` too, exactly as you would before
`wiqd agent add skill`.

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

Two different `wiqd` commands can produce the same kind of artifact — a `SKILL.md` folder
registered in `agentSkills[]` — but they operate on different kinds of projects, and picking the
right one depends on what you already have:

| Question                                                                                   | Command                                                                 | What it does                                                                                                                                                         |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Composing a **new, independent** skill (or a skill-only package), with no existing agent? | `wiqd plugin add skill`                                                 | Composes a capability into a **standalone plugin project** (`wiqd.plugin.json`) from scratch. A plugin can be skill-only — it doesn't require a declarative agent.       |
| Extending an agent project you **already have**?                                          | `wiqd agent add skill`                                                  | Adds the skill directly into that **existing agent project**, in place, via ATK. Also supports `--from` to import an existing skill directory or `.zip`.                |
| Want the skill **exposed to Copilot directly**, on top of however it got there?           | Add `expose_skill_to_copilot: true` to the matching `agent_skills[]` entry | The entry itself is already written for you by `wiqd agent add skill` — it just doesn't set this property. See [The Declarative-Agent Registration](#the-declarative-agent-registration-agent_skills). |

In short: `wiqd agent add skill` extends a project you're already building; `wiqd plugin add skill`
starts a new one and doesn't require an agent to exist first. Either path produces the same
`agentSkills[]` registration. Only `wiqd agent add skill` also writes the `agent_skills[]`
registration automatically, since it operates on a project that already has a declarative-agent
manifest — add `expose_skill_to_copilot: true` to that entry when you want the skill exposed to
Copilot directly. A skill-only plugin from `wiqd plugin add skill` has no declarative-agent
manifest yet, so add a declarative agent (`wiqd plugin add agent`) before that registration can
apply.

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

...and adds a matching entry to `appPackage/manifest.json`'s `agentSkills[]` array — see
[Manifest Shape](#manifest-shape-agentskills-shipped-today). You should not need to hand-edit
`manifest.json` for a normal add or import.

**Importing** (`--from`) registers content that already exists — a directory under
`appPackage/skills/`, or the contents of an external `.zip` — so Step 4 doesn't apply; the
`SKILL.md` content is already there. Still run Step 5 (validate) on it — importing doesn't
re-validate the frontmatter for you.

### Step 4: Write the SKILL.md Content

See [SKILL.md Frontmatter Contract](#skillmd-frontmatter-contract) for the required frontmatter
fields. In the body, write clear, imperative instructions — the same way you'd write playbook
steps for a person, since Copilot follows them literally once the skill activates. Keep any
companion files under `references/` (loaded on demand) or `scripts/` (executed, never loaded into
context) inside the same folder, not scattered at the folder root alongside `SKILL.md` — see
[Companion Files](#companion-files) for size and path limits.

### Step 5: Validate and Package

```bash
wiqd agent validate                # static MVL — does NOT check agentSkills[] or SKILL.md content
wiqd agent package --env local     # builds the .zip
wiqd agent validate --mode deep    # reaches AVL — this is what actually checks agentSkills[]
```

Use `wiqd agent validate --mode deep` — this is an **agent** project (there's no
`wiqd.plugin.json` here), so the sibling `wiqd plugin validate --mode deep` command exits `2`
("not a plugin project") if you run it instead. The two commands reach the identical AVL check
for their respective project types — `plugin validate` reuses `agent validate` verbatim under the
hood — but `agent validate` is the one that actually works against a `wiqd agent add skill`
project. See [Validation](#validation-the-askill--codes) for what's actually being checked and why
static mode alone isn't enough.

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

A skill folder may carry companion files under `references/` (loaded on demand) and `scripts/`
(executed, never loaded into context — see [Runtime Behavior](#runtime-behavior)), subject to
platform limits:

| Limit                               | Value          |
| -------------------------------------- | ---------------- |
| Files per skill                     | At most 20     |
| Size per individual file            | At most 5 MB   |
| Total size across the skill folder  | At most 10 MB  |

Every companion-file path must also be relative (no absolute paths), free of `..` segments,
backslashes, and null bytes; not a hidden file (no leading `.` in the filename); not a Windows
reserved name (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`, with or without an
extension); and composed of safe filename characters only.

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

`agent_skills[]` (snake_case) is the declarative-agent manifest's own registration for a skill —
a second, opt-in registration of the same skill an `agentSkills[]` entry already registers, not a
competing array. It uses the exact same `folder` property as `agentSkills[]`, resolved relative to
the declarative-agent manifest's own directory — the same `appPackage/` directory `manifest.json`
resolves `folder` against — so an identical `folder` value in both registrations points at the
identical skill folder, containing the identical uppercase `SKILL.md`. There is no lowercase
`skill.md` variant on this surface, or any other:

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

`wiqd agent add skill` already writes this entry for you today, on both backends (the
`microsoft.atk` shell-out and the in-process `microsoft.wiqd.core` engine): the underlying
`atk add skill` / fx-core `addSkill` call initializes `agent_skills[]` if it's missing and pushes
`{ folder }` — **`folder` only**. It does not set `expose_skill_to_copilot`; add that property
yourself, to the entry `wiqd agent add skill` already wrote, when you want the skill exposed to
Copilot directly.

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
- The entry's only confirmed property is `folder` — the same name, same meaning, and same
  resolution base as `agentSkills[]`'s `folder`. Do not invent any property beyond `folder` and
  `expose_skill_to_copilot`.
- Exposure is the explicit `expose_skill_to_copilot` boolean. It is not written automatically by
  `wiqd agent add skill` — set it yourself in the entry already on disk.
- `agent_skills` is not present in the published declarative-agent manifest schema: the v1.8
  schema (`https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v1.8/schema.json`)
  declares a closed `propertyNames` enum that excludes it, and no later schema version is publicly
  published yet — so wiqd's static validator (MVL) currently rejects an `agent_skills` key as an
  unrecognized member, matching the published schema. That is a **schema-publication gap, not a
  toolchain gap**: the underlying toolchain fully implements `agent_skills[]`, including packaging
  the referenced skill folders into the built `.zip` (gated behind the same `TEAMSFX_AGENT_SKILLS`
  flag covered above) — it just isn't in the published schema yet. Treat deep validation and the
  platform itself as the authority on whether an entry is accepted, and re-check this reference
  once a schema that includes `agent_skills` is published.

## Validation: the `ASKILL-*` Codes

The `ASKILL-*` codes are the Microsoft 365 Copilot platform's own Agent Skills validation codes —
emitted by **AVL** (App Validation Library) and at upload/submission time, not defined or
implemented by wiqd. Static `wiqd agent validate` (no `--mode deep`) does not check `agentSkills[]`
or `SKILL.md` content at all — you will only ever see these codes from `wiqd agent validate
--mode deep`, run against an already-built package. (The sibling `wiqd plugin validate --mode
deep` reaches the identical AVL check, but only for a **plugin** project with its own
`wiqd.plugin.json` — it exits `2` against an ordinary agent project, so it is not the command to
reach for here.) If you only ever run static validation, an `ASKILL-*`-class mistake passes
silently and surfaces later at upload — always run deep mode before publishing a skill.

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

**The `TEAMSFX_AGENT_SKILLS` flag has no runtime effect on a shipped, validated agent.** It only
gates whether the authoring toolchain can generate skill artifacts and whether `wiqd agent package`
includes their skill folders in the built `.zip` — see
[Check the Flag First](#check-the-teamsfx_agent_skills-flag-first). Once a skill is packaged and
validated, Copilot's runtime behavior toward it is identical regardless of which backend or flag
state originally produced it.

## Common Issues

| Issue                                                              | Cause                                                                    | Solution                                                                                          |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Package is missing its skill directories after `wiqd agent package` | `TEAMSFX_AGENT_SKILLS` wasn't set when packaging ran, even though it was set when the skill was added | Set the flag before packaging too, not just before `add skill` — see [Check the Flag First](#check-the-teamsfx_agent_skills-flag-first) |
| `wiqd agent add skill` fails or produces an incomplete manifest    | `TEAMSFX_AGENT_SKILLS` isn't set on the machine, and the active backend is `microsoft.atk` | Set the flag — see [Check the Flag First](#check-the-teamsfx_agent_skills-flag-first) — and re-run in the same shell |
| Skill never triggers in conversation                               | `description` is too generic, or doesn't contain the phrases users actually say | Rewrite `description` around real trigger phrases, not a summary of the skill's purpose             |
| Static `wiqd agent validate` passes but the upload still fails     | Static mode (MVL) doesn't check `agentSkills[]` or `SKILL.md` content at all | Run `wiqd agent package` then `wiqd agent validate --mode deep` before publishing                    |
| Manifest edit didn't produce a working skill                       | `agentSkills[]` was hand-edited without also creating a matching `SKILL.md` folder | Prefer `wiqd agent add skill`; if you must hand-edit, create the folder and the manifest entry together |
| Imported skill (`--from`) behaves differently than expected        | `--from` registers existing content as-is; it does not validate or rewrite the imported `SKILL.md` | Run deep validation after import — the frontmatter contract still applies to imported skills        |

## Best Practices

1. **Check the flag before add AND before package.** Confirm `TEAMSFX_AGENT_SKILLS` is set before
   attempting the skills path on the `microsoft.atk` backend, and again before
   `wiqd agent package` — the flag gates packaging too, so a package built without it is silently
   missing its skill directories.
2. **Keep `name` and folder in lockstep.** Treat the frontmatter `name` and the containing folder
   name as a single value — rename both together, always.
3. **Write `description` for triggering, not for summarizing.** Pack in the actual phrases a user
   would say; a technically-accurate but generic description means the skill may never activate.
4. **Add `expose_skill_to_copilot`, don't hand-author `agent_skills[]`.**
   `wiqd agent add skill` already writes both the `agentSkills[]` (Teams app manifest) entry and
   the `agent_skills[]` (declarative-agent manifest) entry — the latter with `folder` only. Add
   `expose_skill_to_copilot: true` to that entry in `appPackage/declarativeAgent.json` when you
   want the skill exposed to Copilot directly; wiqd's static validator currently flags the
   `agent_skills` key as unrecognized regardless.
5. **Run deep validation before publishing.** Static `wiqd agent validate` cannot see
   `agentSkills[]` or `SKILL.md` content — always follow `wiqd agent package` with
   `wiqd agent validate --mode deep` before a submission. (`wiqd plugin validate --mode deep`
   reaches the same check, but only for a plugin project with its own `wiqd.plugin.json` — not
   this file's audience.)
6. **Prefer `wiqd agent add skill` over hand-editing.** It creates the folder and the manifest
   entry together, avoiding the `ASKILL-P001`/`ASKILL-P002` class of mistakes that come from doing
   these steps separately.
7. **Mind the platform ceilings.** 20 entries max, 256 characters max per `folder`, no duplicate
   `folder` values — consolidate rather than sprawl.

## Related Documentation

- [API Plugins](api-plugins.md) — the other in-DA capability for calling external systems
- [MCP Server Plugin Integration](mcp-plugin.md) — another flag-adjacent, manifest-shape-driven capability
- [Manifest Schema Reference](schema.md) — version compatibility and how to look up capability properties
- [M365 Agent Developer Best Practices](best-practices.md)
