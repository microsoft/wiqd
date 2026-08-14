---
title: Build a Plugin
description: Build a Microsoft 365 Copilot plugin — an app package composing an agent, skills, and connectors — by describing it to the wiqd Copilot CLI plugin, or with the wiqd plugin CLI directly. Replaces the "Build plugins for Copilot Cowork" Learn walkthrough end to end.
---

# Build a Plugin

A **plugin** is a Microsoft 365 app package that composes a declarative agent, one or more skills,
and/or one or more remote MCP connectors into a single, independently shippable unit. This guide
gets you from nothing to a validated, provisioned, and shared plugin — the same outcome the
Microsoft Learn "Build plugins for Copilot Cowork" walkthrough targets, reached the wiqd way. If
you haven't yet, read [What is a plugin?](/concepts/plugins/) first for the mental model.

:::caution
**Alpha.** The `wiqd plugin` command tree is enabled by default, but the surface is still alpha and
the interface may change without notice.
:::

## Prerequisites

1. **Install wiqd** (the CLI, the VS Code extension, and the GitHub Copilot CLI plugin, all in one
   step):

   **Windows (PowerShell):**

   ```powershell
   iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
   ```

   **macOS/Linux:**

   ```bash
   curl -fsSL https://aka.ms/wiqd/install.sh | bash
   ```

   See [Installation](/getting-started/installation/) for flags, troubleshooting, and manual steps.

2. **Confirm the Copilot CLI plugin is installed** (the installer does this by default; run it
   explicitly if you skipped that step or want to reinstall):

   ```bash
   wiqd component plugin install
   ```

3. **Sign in** — provisioning and sharing a plugin touch your Microsoft 365 tenant:

   ```bash
   wiqd auth login --interactive
   ```

   See [Authentication](/getting-started/authentication/) for how sign-in works across providers.

4. **Verify your environment**:

   ```bash
   wiqd doctor
   ```

With that done, you have two paths to the same result. **Start with Path 1** — it's the fastest way
to build a plugin and it teaches you the lifecycle as you go. Reach for Path 2 when you need
scripting, CI, or exact reproducibility.

## Path 1 — Build it conversationally

### How it works

Once the wiqd plugin is installed, GitHub Copilot CLI carries a plugin-authoring orchestrator: you
describe what you want in natural language, and it drives the `wiqd` CLI on your behalf —
including the full `wiqd plugin ...` surface — while orienting you on the underlying
Build → Improve → Preview → Publish agent lifecycle. You never have to remember a flag; you just
say what you want next.

### What to say

Saying any of these in GitHub Copilot CLI routes the conversation into the plugin-authoring
workflow:

> create a standalone plugin · build a plugin with a skill · build a plugin with a connector ·
> add a skill to my plugin · add a connector to my plugin · add an agent to my plugin ·
> validate my plugin · package my plugin · share my plugin ·
> show my plugin · list my plugins · import an open plugin · import a claude plugin ·
> export my plugin for claude · export my plugin for cursor · delete my plugin

### A conversational walkthrough

**You say:** "Create a standalone plugin called Triage Helper."
**wiqd does:** runs `wiqd plugin create --name "Triage Helper"`, `cd`s into the new project, and
reports back — then suggests the logical next moves: add a skill, add an MCP connector, or add a
declarative agent.

**You say:** "Add a skill for triaging incoming issues."
**wiqd does:** runs `wiqd plugin add skill --name "Triage Issues"`, scaffolding
`appPackage/skills/triage-issues/SKILL.md` and registering it in the manifest. It then suggests
adding another capability, or validating what you have so far.

**You say:** "Validate my plugin."
**wiqd does:** runs `wiqd plugin validate` (the offline static check). On a clean result, it
suggests provisioning the plugin, reusing it inside an existing agent, or exporting it for another
tool.

**You say:** "Provision it, then package and share it with my team."
**wiqd does:** runs `wiqd plugin provision`, then `wiqd plugin package` now that the environment
file it needs exists, then `wiqd plugin share --scope users --email <you supply>`. Each step's
report tells you what ran and what's next, so a multi-step request like this one still gives you a
checkpoint after every command.

This mirrors the same `create → add → validate → provision → package → share` lifecycle you'd run
by hand — the orchestrator just chooses and sequences the commands for you, one reported step at a
time.

## Path 2 — Use the CLI directly

Reach for the CLI directly instead of the conversational path when you're scripting a CI/CD
pipeline, need fully deterministic and reproducible non-interactive automation, or you simply
prefer typing commands yourself. Every command below is the same one the conversational path runs
under the hood — nothing here is a different surface, just a different way to drive it.

```bash
# 1. Scaffold the plugin container
wiqd plugin create --name my-plugin
cd my-plugin

# 2. Compose whatever capabilities you need, in any combination
wiqd plugin add agent
wiqd plugin add skill --name "Triage Issues"
wiqd plugin add connector --name "Contoso Tools" \
  --description "Contoso toolbelt over MCP" --url https://tools.contoso.com/mcp

# 3. Validate offline before you provision or package
wiqd plugin validate

# 4. Provision first — it writes the env file package/share both depend on
wiqd plugin provision

# 5. Build the deployable .zip
wiqd plugin package

# 6. Run the full package-first deep validation against AVL
wiqd plugin validate --mode deep

# 7. Share it
wiqd plugin share --scope users --email you@contoso.com
# …or share with your whole tenant:
wiqd plugin share --scope tenant

# Inspect at any point
wiqd plugin show
wiqd plugin list --root .

# Tear down what provision created (--yes skips the confirmation prompt for non-interactive use)
wiqd plugin delete --env local --yes
```

:::note
**Order matters:** `provision` must run before `package` — `provision` is the only command that
writes `env/.env.<env>`, which `package` needs to resolve manifest variables and which `share`
requires as a preflight. `wiqd plugin validate --mode deep` is itself package-first, so it needs
Step 5's `.zip` to already exist.
:::

For every flag on every one of these commands, see
[`wiqd plugin` in the CLI reference](/cli/reference/#wiqd-plugin) rather than duplicating the
full flag set here.

## Import / export (interop)

Already have a plugin authored for another host, or want to hand yours to one? Two commands bracket
the lifecycle instead of requiring a hand-rolled conversion script:

```bash
# Bring a foreign-format plugin into wiqd instead of starting from `create`
wiqd plugin import --path ./my-open-plugin \
  --privacy-url https://contoso.com/privacy \
  --terms-url https://contoso.com/terms

# Hand a wiqd plugin project to another host
wiqd plugin export --format claude-plugin
```

`wiqd plugin import` recognizes an Open Plugin, Claude plugin, or Cursor plugin source and produces
a new wiqd plugin project from it. `--privacy-url`/`--terms-url` are only required on a plugin's
**first** import — if the source was produced by a prior `wiqd plugin export`, the round-trip
metadata already carries them. `wiqd plugin export` does the inverse, defaulting to
`--format open-plugin` (also accepts `claude-plugin` and `cursor-plugin`), writing an uncompressed
directory under `<path>/export/<format>`.

**Current limitation:** an imported project flows through the **read-only** lifecycle —
[validate](/cli/reference/#wiqd-plugin-validate) and
[show & list](/cli/reference/#wiqd-plugin-show) — but **cannot yet be packaged, provisioned, or
shared**, because the import doesn't yet scaffold the local deploy files
(`m365agents.local.yml` + `env/.env.local`) those steps need. This is a tracked, known gap, not a
design choice — see [`wiqd plugin import`](/cli/reference/#wiqd-plugin-import) for the
up-to-date status.

## Validation as a first-class step

Rather than assembling a package and hoping upload-time validation passes, validate continuously as
you build:

- **Static (default)** — `wiqd plugin validate` runs the offline MVL (Manifest Validation Library)
  engine over the **declarative-agent surface only**: `declarativeAgent.json` plus any referenced
  API-plugin manifest or OpenAPI specs. It does **not** inspect the top-level Teams manifest or the
  content of `agentSkills[]`/`SKILL.md` files — so a skill-only or connector-only plugin passes
  static validation vacuously. This is expected, not a gap: it's an inner-loop check, not full
  coverage.
- **Deep (`--mode deep`)** — package-first: after `wiqd plugin package` builds a `.zip`,
  `wiqd plugin validate --mode deep` validates that built package against AVL (App Validation
  Library) through the Teams Developer Portal, via ATK. This is where manifest-schema rejections
  and skill-content issues actually surface. See the
  [Plugin authoring reference](/getting-started/plugin-reference/#validation-codes) for the full validation-code
  tables and how they map to static vs. deep.

## Publishing paths

wiqd carries you through build → validate → provision → package → share. Where you go from there
depends on your audience:

- **Your tenant** — `wiqd plugin share --scope tenant` makes the plugin available org-wide, or an
  admin can upload the packaged `.zip` directly via the Microsoft 365 admin center's "Upload custom
  app" step.
- **The public store** — certification and store submission happen in Partner Center, a human/admin
  process outside wiqd.

**Where wiqd stops:** wiqd's job ends at `share` (or at handing you the packaged `.zip`). Admin
center uploads and Partner Center certification/submission are deliberate, human/admin actions —
there is no `wiqd plugin publish` command, because publishing to the public store isn't something
wiqd automates today.

## What's Next?

- [What is a plugin?](/concepts/plugins/) — the mental model and the three meanings of "skill"
- [`wiqd plugin`](/cli/reference/#wiqd-plugin) — the full command reference
- [Plugin authoring reference](/getting-started/plugin-reference/) — package anatomy, `SKILL.md` rules, connector
  requirements, validation codes, and the section-by-section Learn parity table
- [Quickstart](/getting-started/quickstart/) — the equivalent 5-minute walkthrough for a plain `wiqd agent` project
