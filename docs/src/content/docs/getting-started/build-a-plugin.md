---
title: Build a Plugin
description: Build a Microsoft 365 Copilot plugin — an app package composing an agent, skills, and connectors — by describing it to the wiqd Copilot CLI plugin, or with the wiqd plugin CLI directly. Replaces the "Build plugins for Copilot Cowork" Learn walkthrough end to end.
---

# Build a Plugin

A **plugin** is a Microsoft 365 app package that composes a declarative agent, one or more skills,
and/or agent connectors (remote MCP servers or references to existing OpenAPI custom connectors)
into a single, independently shippable unit. This guide
gets you from nothing to a validated, provisioned, and shared plugin — the same outcome the
Microsoft Learn "Build plugins for Copilot Cowork" walkthrough targets, reached the wiqd way. If
you haven't yet, read [What is a plugin?](/concepts/plugins/) first for the mental model.

:::caution
**Alpha.** The `wiqd plugin` command tree is enabled by default, but the surface is still alpha and
the interface may change without notice.
:::

## Prerequisites

1. **Install wiqd** (the CLI, optional VS Code extension, and public WIQD plugin
   for detected native coding-assistant hosts):

   **Windows (PowerShell):**

   ```powershell
   iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
   ```

   **macOS/Linux:**

   ```bash
   curl -fsSL https://aka.ms/wiqd/install.sh | bash
   ```

   See [Installation](/getting-started/installation/) for flags, troubleshooting, and manual steps.

2. **Install the WIQD coding-assistant plugin from its marketplace** if you want
   guided authoring and did not install it in Step 1. This guide plugin is distinct
   from the Microsoft 365 plugin you will create:

   ```bash
   copilot plugin install wiqd@awesome-copilot
   ```

   Or use the WIQD marketplace:

   ```bash
   copilot plugin marketplace add microsoft/wiqd
   copilot plugin install wiqd@wiqd
   ```

   For Claude Code, add `microsoft/wiqd` and install `wiqd@wiqd`. Start a new
   host session.

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
Build → Improve → Preview → Publish plugin lifecycle. You never have to remember a flag; you just
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

**You say:** "Validate my plugin in dev."
**wiqd does:** runs `wiqd plugin validate --env dev` (the offline static check). On a clean result, it
suggests provisioning the plugin or exporting it for another tool. There is no shipped command
that merges a whole plugin into an existing agent. For an OpenAPI custom connector, it omits export because that format cannot represent the
`ConnectionVault` reference, and explains that static validation does not establish packaging or
deployment readiness.

**You say:** "Provision it in dev, then package and share it with my team using dev."
**wiqd does:** explains that standard projects use `local` for personal testing and `dev`
for shared deployment, checks the project's actual scope configuration, and selects the
shared environment. It validates, runs `wiqd plugin provision --env dev`, then
`wiqd plugin package --env dev`, then
`wiqd plugin share --env dev --scope users --email <you supply>`. Each step's
report tells you what ran and what's next, so a multi-step request like this one still gives you a
checkpoint after every command.

If you already provisioned in personal `local`, asking to share does not make
that deployment shareable. Copilot explains the restriction and asks permission
for any additional cloud provisioning not already authorized, then validates and
prepares the shared environment before sharing. A ready shared deployment is
reused without redundant provisioning. Custom environment names and scope settings
are respected; missing or conflicting configuration is reported rather than
silently replaced. Help and read-only requests do not deploy anything, and
tenant-wide sharing requires explicit audience confirmation.

This mirrors the same `create → add → validate → provision → package → share` lifecycle you'd run
by hand — the orchestrator just chooses and sequences the commands for you, one reported step at a
time.

## Path 2 — Use the CLI directly

Reach for the CLI directly instead of the conversational path when you're scripting a CI/CD
pipeline, need fully deterministic and reproducible non-interactive automation, or you simply
prefer typing commands yourself. Every command below is the same one the conversational path runs
under the hood — nothing here is a different surface, just a different way to drive it.

**Choose the deployment scope first.** The example below uses the standard shared
`dev` environment because it ends in sharing. Use `local` for personal testing,
not sharing. These are scaffold defaults: check the effective lifecycle
configuration and `AGENT_SCOPE` in the selected environment under
`environmentFolderPath` (default `./env`); an environment name alone does not prove
it is shared. `--scope users|tenant` selects the sharing audience, not deployment
scope. There is no `wiqd plugin provision --scope shared` option.

Direct `wiqd plugin share` (and `wiqd agent share`) checks the selected environment
file for `AGENT_SCOPE=shared` before sharing. Missing, invalid, duplicate, or
non-shared scope fails with `INVALID_AGENT_SCOPE` (exit `1`); the CLI does not
provision automatically. Correct the shared deployment configuration, validate,
and provision using the same explicit `--path` and `--env`, then retry sharing.
Do not relabel a personal deployment or copy its IDs to bypass this check.

```bash
# 1. Scaffold the plugin container
wiqd plugin create --name my-plugin
cd my-plugin

# 2. Compose whatever capabilities you need, in any combination
wiqd plugin add agent
wiqd plugin add skill --name "Triage Issues"
wiqd plugin add connector --name "Contoso Tools" \
  --description "Contoso toolbelt over MCP" --url https://tools.contoso.com/mcp

# Or reuse a connector the Microsoft 365 catalog already publishes — the catalog
# supplies its URL and credential reference. Copy the selector from `connector list`.
wiqd connector list --search "Azure DevOps"
wiqd plugin add connector --selector "Azure DevOps MCP"

# Or reference an existing custom connector by its logical name.
# --dev-preview explicitly updates both manifestVersion and $schema.
wiqd plugin add connector --kind openapi --name "Contoso Kusto" \
  --description "Queries the existing Contoso Kusto connector" \
  --auth-reference-id shared_kusto --dev-preview

# 3. Validate offline before you provision or package
wiqd plugin validate --env dev

# 4. Provision first — it writes the env file package/share both depend on
wiqd plugin provision --env dev

# 5. Build the deployable .zip
wiqd plugin package --env dev

# 6. Run the full package-first deep validation against AVL
wiqd plugin validate --env dev --mode deep

# 7. Share it
wiqd plugin share --env dev --scope users --email you@contoso.com
# …or share with your whole tenant:
wiqd plugin share --env dev --scope tenant

# Inspect at any point
wiqd plugin show
wiqd plugin list --root .

# Tear down what provision created (--yes skips the confirmation prompt for non-interactive use)
wiqd plugin delete --env dev --yes
```

:::note
**Order matters:** `provision` must run before `package` — `provision` writes `.env.<env>` under
the `m365agents.yml` `environmentFolderPath` (default `./env`), which `package` needs to resolve
manifest variables and which `share` requires as a preflight. Re-provision detection and
project-mode delete use that same configured folder. The folder must remain inside the plugin
project, and `--env` must be one portable filename segment (for example `dev` or `test-west`, not
a path). `wiqd plugin validate --mode deep` is itself package-first, so it needs Step 5's `.zip`
to already exist.
:::

For every flag on every one of these commands, see
[`wiqd plugin` in the CLI reference](/cli/reference/#wiqd-plugin) rather than duplicating the
full flag set here.

`--kind openapi` does not author an OpenAPI API-plugin action and does not create a custom
connector. It writes a `ConnectionVault` pointer to an existing custom connector. The
`--auth-reference-id` value is its logical name (for example `shared_kusto`), not a URL, secret,
connection instance, or OAuth registration id. This connector shape is currently available only
through explicit `devPreview` authoring; wiqd does not assume a tentative numbered manifest version
supports it.

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
directory under `<path>/export/<format>`. The output layout uses the core backend:
writes the selected format layout; FxCore always writes `plugin.json` at the export root and uses
`--format` only for the default output directory and reported format.

The imported project is ready for the full lifecycle. The TeamsFx importer creates its deployment
environment (currently `dev`), and wiqd binds the package manifest to that environment's
`TEAMS_APP_ID`. For a default import with no app ID, continue with `wiqd plugin validate`, then run
`wiqd plugin provision --env dev` **before** `wiqd plugin package --env dev`,
`wiqd plugin publish --env dev`, `wiqd plugin share --env dev`, or package-first deep validation. Packaging through either backend
fails closed while the selected environment file is missing or its `TEAMS_APP_ID` is empty,
unresolved, or malformed, instead of allowing a random package-only ID.

Mock import follows the same finalized project contract: the package manifest keeps the
`${{TEAMS_APP_ID}}` binding, the generated `dev` environment is present, and an explicit
`--app-id` is written to that environment before provision/package checks run.

If you pass `--app-id`, or a supported source extension carries a real GUID, import writes that ID
into `.env.dev`; the project is already identity-bound for packaging. A wiqd export does not invent
or preserve an unresolved `${{TEAMS_APP_ID}}` token as a round-trip ID, so only a real GUID from a
supported producer qualifies. Provision/update remains the normal tenant lifecycle step before
sharing a newly imported app.

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
  Library) through the Teams Developer Portal, via deep validation. This is where manifest-schema rejections
  and skill-content issues actually surface. See the
  [Plugin authoring reference](/getting-started/plugin-reference/#validation-codes) for the full validation-code
  tables and how they map to static vs. deep.

Static validation does not inspect root `agentConnectors[]`, including `openApiConnector`.
For a preview custom connector, package before deep validation. The bundled fx-core
`3.1.5-alpha.36e30da2f6.0` supports local devPreview packaging of OpenAPI and remote MCP
connectors using `ConnectionVault`, preserving their fields and leaving the source manifest
unchanged. Local packaging success is not a server verdict. Check the built ZIP with
`wiqd plugin validate --mode deep --package-file <zip>`. Report the returned findings rather than
assuming every rejection is a rollout issue. Runtime invocation and Store/Partner Center acceptance
remain separate checks. `wiqd plugin export` also fails explicitly for this connector kind
because Open Plugin has no verified representation for the `ConnectionVault` logical reference.

## Publishing paths

wiqd carries you through build → validate → provision → package → publish or share. Choose the
tenant path based on how users should receive the plugin:

- **Organization app catalog** — `wiqd plugin publish --env <env>` submits the provisioned plugin
  to the tenant's org admin catalog. Submission succeeds before approval; tenant users can discover
  the plugin only after an administrator approves it.
- **Direct access** — `wiqd plugin share --scope users --email ...` grants access to named users, or
  `wiqd plugin share --scope tenant` grants tenant-wide access. Sharing is a different operation
  from catalog submission.
- **Public store** — run `wiqd plugin package --env <env>` and submit the `.zip` through Partner
  Center. wiqd does not automate Partner Center certification or public-store submission.

Normal publish validates the effective app manifest that it sends to fx-core:
`appPackage/manifest.json` by default, or the contained file selected with
`--manifest`. All DA manifests, skill folders, Worker references, and other
package files resolve from that selected manifest's directory. A valid override
is not blocked by stale or invalid DA references in the unused default
manifest.

Before catalog submission, you can run a no-submit readiness check:

```bash
# Fully offline: project/path checks plus the applicable static DA phase
wiqd plugin publish --dry-run --no-runtime --no-network --env dev

# Full applicable validation for a plugin that contains a declarative agent
wiqd plugin publish --dry-run --env dev
```

Declarative-agent checks are explicitly skipped for skill/connector-only plugins; a skip does not
claim those components received full runtime validation.

**Where wiqd stops:** wiqd automates submission to the tenant organization app catalog, but tenant
administrator approval remains an admin action. Partner Center certification and public-store
publication also remain outside wiqd.

## What's Next?

- [What is a plugin?](/concepts/plugins/) — the mental model and the three meanings of "skill"
- [`wiqd plugin`](/cli/reference/#wiqd-plugin) — the full command reference
- [Plugin authoring reference](/getting-started/plugin-reference/) — package anatomy, `SKILL.md` rules, connector
  requirements, validation codes, and the section-by-section Learn parity table
- [Quickstart](/getting-started/quickstart/) — a shorter walkthrough for your first plugin
- [Agent component lifecycle](/concepts/agent-lifecycle/) — agent-specific workflows and existing `wiqd agent` projects
