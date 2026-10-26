---
name: plugin
description: >
  Author a standalone, reusable M365 Copilot plugin — a Teams app package that composes a
  declarative agent, skill(s), and/or agent connector(s) as a first-class, independently
  packageable and validatable deliverable — via the alpha `wiqd plugin` construct. A
  "Copilot Cowork plugin" is this same artifact, not a different platform. This is
  distinct from adding a plugin capability into a single agent (that is `wiqd agent`), and
  distinct from the GitHub Copilot CLI plugin (`wiqd@wiqd`), which is installed with
  `wiqd component plugin install` and is not authored by this workflow. Covers
  the full flow: create (or import an existing Open Plugin) → add skill / connector / agent →
  validate → provision / package / publish / share, plus export back out to Open Plugin, Claude,
  or Cursor format, including remote MCP connectors and references to existing OpenAPI custom
  connectors.
trigger-summary: 'create a plugin, cowork plugin, standalone plugin, reusable plugin, plugin project, build a plugin, plugin with a skill, plugin with a connector, discover connectors, add an existing connector, custom connector plugin, openapi connector, MCP plugin project, package a plugin, validate a plugin, publish a plugin, share a plugin, delete a plugin, tear down a plugin, import an open plugin, export to claude, export to cursor, convert a plugin'
triggers: >
  create a plugin, create a standalone plugin, new plugin, new plugin project, build a plugin,
  build a standalone plugin, author a plugin, make a reusable plugin, reusable plugin,
  standalone plugin, plugin project, plugin with a skill, plugin with a connector,
  plugin with a custom connector, add an existing custom connector to my plugin,
  add an openapi connector to my plugin, connection vault connector,
  discover connectors, use an existing catalog connector, add an existing connector to my plugin,
  add the Azure DevOps connector to my plugin, add Azure DevOps MCP to my plugin,
  cowork plugin, build a cowork plugin, create a cowork plugin, copilot cowork plugin,
  build a plugin for cowork, microsoft copilot plugin, m365 copilot plugin,
  add a skill to my plugin, add a connector to my plugin, add an agent to my plugin,
  validate my plugin, package my plugin, publish my plugin, submit my plugin to the org catalog,
  dry run plugin publish, share my plugin, show my plugin,
  list my plugins,
  import an open plugin, import a claude plugin, import a cursor plugin,
  convert an open plugin to a wiqd plugin, open a claude plugin in wiqd,
  turn a cursor plugin into an M365 plugin, bring in an existing open plugin,
  export my plugin, export my plugin to open plugin, export my plugin for claude,
  export my plugin for cursor, convert my plugin to open plugin format,
  make my plugin work in claude, make my plugin work in cursor, share my plugin with other tools,
  delete my plugin, uninstall my plugin, tear down my plugin, remove my plugin from the tenant,
  clean up my provisioned plugin, delete the plugin app registration, undo plugin provision
routing-label: 'Plugin authoring (alpha)'
routing-intent: 'Authoring a standalone, reusable plugin (create or import, add skill/connector/agent, validate, provision, package, publish/share, export)'
routing-order: 2
contract-version: 1
routing-requires:
  [
    plugin create,
    plugin import,
    plugin add skill,
    plugin add connector,
    connector list,
    connector show,
    plugin add agent,
    plugin validate,
    plugin show,
    plugin list,
    plugin provision,
    plugin package,
    plugin publish,
    plugin share,
    plugin export,
    plugin delete,
  ]
---

# Plugin — Standalone Plugin Authoring (alpha)

Author a **standalone, reusable M365 Copilot plugin** as a first-class, independently shippable unit — not something bolted inside one agent project. A plugin is a **Teams app package** (the same `appPackage/` infrastructure `wiqd agent` uses) that composes one or more capabilities: a **declarative agent**, one or more **skills** (`SKILL.md` folders), and one or more **agent connectors** (a remote MCP server or a reference to an existing OpenAPI custom connector). It is marked by a light `wiqd.plugin.json` descriptor and flows through the familiar lifecycle: `create → add → validate → provision → package → publish / share`, with `show` / `list` available for inspection at any point. `publish` submits to the tenant organization app catalog for administrator approval; `share` grants direct access and is not the same operation. Two interoperability commands bracket that lifecycle: `import` is an alternate **entry point** (in place of `create`) that converts an existing Open Plugin / Claude / Cursor plugin into a wiqd plugin project, and `export` is an **exit point** that converts a wiqd plugin project back out to those formats.

> **Convention:** When calling `wiqd` commands from this skill, always pass `--skill wiqd --workflow plugin`, and add `--json` for any command whose output you need to parse (structured, machine-readable output instead of lossy table text).

> **Terminology — one artifact, many names.** "**Cowork plugin**", "**Copilot Cowork plugin**", "**Microsoft 365 Copilot plugin**", and "**standalone plugin**" all name the **same artifact** this workflow builds: one Microsoft 365 app package. An unqualified "**Copilot plugin**" names that same artifact **whenever the request points at an M365 host surface, or names no host at all**. "Standalone" is a wiqd word that separates a reusable plugin project from a declarative-agent project — it is **not** a platform qualifier. Cowork, Microsoft 365 Copilot chat, Teams, and Office are **host surfaces** for that one package, not separate plugin platforms with their own SDKs. A request to "build a Cowork plugin" belongs **here** — never treat it as out of scope or redirect the user to another toolchain.

> **Exception — a GitHub Copilot CLI plugin is a different artifact.** When the request names **GitHub Copilot CLI** as the host ("a plugin **for Copilot CLI**", "the **`wiqd@wiqd` plugin**", "install the wiqd Copilot plugin"), it is **not** a Microsoft 365 app package and `wiqd plugin create` would scaffold the wrong thing. That plugin is a wiqd **component** — the composed skills + guide-agent bundle Copilot CLI itself loads — installed with `wiqd component plugin install`, not authored here. wiqd does not author third-party Copilot CLI plugins: say so and point at the install command instead of scaffolding.

> **Alpha.** The `wiqd plugin` construct is enabled by default. The interface may change without notice.

## When to use this workflow

Use this workflow — **not** the `wiqd-core` (agent) workflow — when the user wants a **standalone / reusable plugin**:

- "Create a **standalone plugin**" / "build a **plugin project**" / "author a **reusable plugin**"
- "Build a **Cowork plugin**" / "a **Microsoft Copilot plugin**" — same artifact, named by its host surface (see Terminology above)
- "Build a **plugin with a skill**" (optionally one that calls an MCP server)
- "Add a **skill** / **connector** / **agent** **to my plugin**"
- "Validate / provision / package / publish / share **my plugin**"
- "**Import** an Open Plugin / Claude plugin / Cursor plugin" — bring an existing cross-tool plugin into the wiqd lifecycle
- "**Export** my plugin to Open Plugin / Claude / Cursor" / "make my plugin work in Claude"

## Plugin vs. agent — disambiguation (read this first)

The words "plugin", "skill", and "import" are all overloaded. Route correctly:

| The user wants…                                                                                                         | Workflow                        | Why                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------- |
| A **standalone / reusable plugin** as its own deliverable (create, add skill/connector/agent, validate, package, publish/share) | **this `plugin` workflow**      | The artifact is a plugin app package with its own lifecycle, not an agent                               |
| A **Cowork plugin** / **Microsoft Copilot plugin** / **M365 Copilot plugin** — any **M365** host surface named in the request    | **this `plugin` workflow**      | All the same Microsoft 365 app package; the surface name is not a different product, SDK, or toolchain            |
| A **GitHub Copilot CLI plugin** — "a plugin for **Copilot CLI**", the **`wiqd@wiqd`** plugin                           | **neither** — not authored by wiqd | A wiqd **component**, not a Microsoft 365 app package. Install it with `wiqd component plugin install`; wiqd does not author third-party Copilot CLI plugins |
| To **convert an existing Open Plugin / Claude / Cursor plugin into a wiqd plugin project**                              | **this `plugin` workflow** → `plugin import` | Cross-**format** conversion producing a whole new plugin project                                         |
| To convert **a wiqd plugin project out** to Open Plugin / Claude / Cursor format                                        | **this `plugin` workflow** → `plugin export` | Cross-**format** conversion producing an interoperable output directory                                 |
| To add an **API / MCP plugin capability into one existing declarative agent**                                           | `wiqd-core` workflow → Adding Plugins | There "plugin" means a capability composed _inside_ a single agent's manifest (`actions[]` / MCP)       |
| To pull **an existing wiqd plugin into an agent**                                                                      | Not currently supported              | No shipped command merges a whole wiqd plugin into an existing agent; do not promise automatic composition |
| To scaffold a **declarative agent** ("create an agent", "new agent")                                                    | `wiqd-core` workflow → Create         | The artifact is an agent, whose sole capability is a declarative agent                                  |

Disambiguate importing a foreign-format plugin from composing capabilities into an existing agent:

- `wiqd plugin import --path <open-plugin-dir>` — source is a **foreign-format** plugin (Open Plugin / Claude / Cursor); output is a **new wiqd plugin project**.
- An **already-wiqd** plugin cannot currently be merged into an existing agent by a shipped command. Explain that limitation rather than inventing an import command; the core workflow covers adding individual supported API/MCP capabilities.

If in doubt, ask: _"Do you want a standalone, reusable plugin you can validate and ship on its own, or a capability added into an existing agent?"_

## Preflight

Run these checks before scaffolding. If the shell tool is unavailable, fall back to `view`/`glob`/`grep` and tell the user which manual step to run.

1. **wiqd CLI available** — see the shared `references/preflight.md` version check.
2. **Plugin command available** — `wiqd plugin --help` must succeed without feature-flag configuration. If it does not, the installed wiqd is too old or incomplete; update/reinstall wiqd rather than mutating flag state.
3. **Not already inside a project** — for `create`, verify the target directory does not already contain a `wiqd.plugin.json` or an `appPackage/`. If it does, this is an existing project: switch to the relevant `add …` step instead of `create`.
4. **wiqd runtime available** — if `plugin create` reports missing runtime assets, reinstall wiqd.

## Authoring flow

The primitive is **composition**: `create` scaffolds a bare plugin container, then each `add …` composes one capability into it.

**Do not infer capabilities.** If the user asks only for a standalone plugin and does not explicitly request an agent, skill, or connector, run `plugin create` and stop. A reusable or packageable plugin does not implicitly require `plugin add agent`, `plugin add skill`, or `plugin add connector`.

### 1. Create the plugin container

```bash
wiqd plugin create --name "<plugin-name>" [--output <dir>]
```

- `--name` / `-n` — plugin project name (**required**).
- `--output` / `-o` — parent directory (defaults to CWD). The project is scaffolded at `<output>/<name>`.

This scaffolds the blank plugin project, then writes `wiqd.plugin.json` with `capabilities: []`. **Enter the project directory** afterward — every `add …` / `validate` command operates on the plugin in the working directory (or takes `--folder` / `--path`):

```bash
cd <output>/<name>
```

> `create` refuses to scaffold over a non-empty destination. If the user genuinely wants to overwrite, pass `--force` — but check first, since that can clobber existing environment state.

#### 1-alt. …or import an existing Open Plugin instead

If the user already has an Open Plugin / Claude / Cursor plugin, **skip `create`** — `import` is the alternate entry point and produces the same kind of project:

```bash
wiqd plugin import --path <open-plugin-dir> [--output <dir>]
```

Then `cd` into the produced project and continue from step 2 exactly as if it had been created. Full details in [Interoperability](#interoperability-open-plugin--claude--cursor).

### 2. Add capabilities

Add whatever the request calls for, in any combination:

```bash
# Discover an existing catalog connector (a top-level `wiqd connector` command; no plugin needed),
# then add its exact canonical node to the plugin by the selector printed by `connector list`.
wiqd connector list --search "<name>"
wiqd connector show <selector>
wiqd plugin add connector --selector <selector> [--folder <dir>]

# A skill (a SKILL.md folder under appPackage/skills/<slug>/, registered in agentSkills[])
wiqd plugin add skill --name "<Skill Name>" [--folder <dir>]

# A remote MCP agent connector (root agentConnectors[] entry)
wiqd plugin add connector --name "<Connector Name>" --description "<what it does>" --url "https://<mcp-server>/mcp" [--folder <dir>]

# The same, but authenticated: point at a credential already registered in the Teams
# Developer Portal (Tools → OAuth client registration) or by an oauth/register step.
# The manifest carries only the reference id — never a client id, secret, or token.
wiqd plugin add connector --name "<Connector Name>" --description "<what it does>" \
  --url "https://<mcp-server>/mcp" --auth-type oauth --auth-reference-id "<reference-id>"

# ⛔ If the target is Copilot Cowork, supply --tool-description. The 1.29 schema marks it
# optional, but Cowork treats it as REQUIRED: a URL-only connector passes validate, deep
# validate, and provision, then shows "Could not verify connection" in the product. Capture
# the server's tools/list output to a file under appPackage/ and reference it here.
wiqd plugin add connector --name "<Connector Name>" --description "<what it does>" \
  --url "https://<mcp-server>/mcp" --tool-description "<file>.json"

# Dynamic client registration: omit the credential entirely. `--auth-type dcr` writes NO
# authorization node, which is how the host enables DCR.
wiqd plugin add connector --name "<Connector Name>" --description "<what it does>" \
  --url "https://<mcp-server>/mcp" --auth-type dcr

# An existing OpenAPI custom connector, only when the user explicitly asks for this preview
# shape and already knows its logical connector name. Never infer or suggest this path from
# catalog discovery because broad runtime support is not yet established. The reference is
# not an endpoint, secret, connection instance, OpenAPI file, or operation list.
# This capability is currently devPreview-only, so the flag explicitly updates both
# manifestVersion and $schema on a fresh numbered plugin.
wiqd plugin add connector --kind openapi --name "<Connector Name>" \
  --description "<what the existing custom connector does>" \
  --auth-reference-id "<logical-name>" --dev-preview

# A declarative agent component (copilotAgents.declarativeAgents)
wiqd plugin add agent [--folder <dir>]
```

Each `add …` updates `wiqd.plugin.json`'s `capabilities` array after its artifacts are written.

Prefer catalog discovery (`wiqd connector list/show`) plus `plugin add connector --selector` when the
requested connector already exists in the catalog. The catalog
title ID, connector element ID, display name, and vault reference ID are distinct; never substitute
one for another in the persisted node. Copy the selector printed by `connector list`; duplicate
display names for equivalent MCP definitions are deduplicated, while materially different
same-named connectors receive composite selectors automatically. `--selector` copies the exact
retained `agentConnectors` node and is limited to
`remoteMcpServer` nodes using the supported catalog authorization types; it cannot be combined with
`--name`, `--url`, `--kind`, or any other manual connector option. Catalog discovery
surfaces `openApiConnector` nodes for inspection, but they route to the explicit preview path only
after user confirmation.

#### Conversational connector catalog flow

When the user names an existing connector without supplying a URL — for example, **"Add the Azure
DevOps connector to my plugin"**:

1. Do **not** ask for an MCP URL, title ID, environment, or vault reference.
2. Run:
   ```bash
   wiqd connector list --search "<user's connector name>" --json --skill wiqd --workflow plugin
   ```
3. If exactly one `remoteMcpServer` result matches, copy its `selector` into:
   ```bash
   wiqd plugin add connector --selector "<selector>" --folder <plugin-dir> --json --skill wiqd --workflow plugin
   ```
   If the command reports an inline or unavailable tool-description asset, follow its manual
   `plugin add connector --tool-description <file>` guidance instead of retrying the catalog path.
4. If exactly one `openApiConnector` result matches, explain that it is preview-only and that broad
   runtime support is not established. Ask the user to confirm this preview choice. After
   confirmation, use the result's display name, description, and `referenceId` with:
   ```bash
   wiqd plugin add connector --kind openapi --name "<displayName>" \
     --description "<description>" --auth-reference-id "<referenceId>" \
     --dev-preview --folder <plugin-dir> --json --skill wiqd --workflow plugin
   ```
   Do **not** pass an OpenAPI result's selector to `plugin add connector --selector`.
5. If several results remain, show only their title, connector name, kind, authorization type, and
   selector, then ask the user to choose one. Never choose by response order.
6. If no result matches, report that the catalog did not return the named connector. Only then offer the
   manual `plugin add connector` paths.
7. After successful composition, run `wiqd plugin validate --path <plugin-dir>` and report the actual
   validation result.

The selector is the only discovery value the user needs to copy. Catalog title IDs remain provenance
inside the list/show output and are encoded into composite selectors only when needed for
disambiguation.

Use `--kind openapi` only after an explicit preview confirmation, with a logical name supplied by the
user or discovered from a catalog result. Do not ask for or invent a URL, OpenAPI file, operations,
credentials, or a connection instance id: the platform resolves those from `ConnectionVault` at
runtime. Do not route this request to the declarative-agent `actions[]` OpenAPI-plugin surface; that
is a different artifact. The preview authoring path does not prove public schema documentation,
numbered-manifest support, or Store/Partner Center acceptance. Package and deep-validate the result,
and report any upstream rollout failure rather than rewriting the connector.

### 3. Validate

```bash
wiqd plugin validate [--path <dir>]
```

Validates the descriptor and component artifacts. Fix any reported errors and re-run until clean before packaging.

### 4. Inspect / lifecycle (as needed)

Inspection is available at any point; the deploy lifecycle runs in this order:

**Choose the deployment environment before provisioning.** Explain the standard
scaffold defaults: `local` is personal testing; `dev` is shared deployment.
Ask which outcome the user needs only when their intent does not already settle
it. These are defaults, not scope guarantees: inspect the selected project's
effective lifecycle/environment configuration and `AGENT_SCOPE`, using its
configured `environmentFolderPath` (default `./env`). Respect an explicitly
selected shared environment. If configuration is missing, malformed, or conflicts
with the intended scope, explain what needs correcting and stop; never silently
overwrite it. There is no `provision --scope shared` flag; share's
`--scope users|tenant` selects the audience, not deployment scope.

```bash
wiqd plugin show [--path <dir>]                # summary of one plugin
wiqd plugin list [--root <dir>]                # plugins under a directory

wiqd plugin provision --env <env> [--path <dir>] # 1. provision the chosen personal/shared environment
wiqd plugin package --env <env> [--path <dir>]   # 2. package that same deployment
wiqd plugin publish --env <env> [--path <dir>]   # 3a. submit to the org catalog for admin approval
wiqd plugin share --env <shared-env> --scope users --email <e> [--path <dir>] # 3b. shared deployments only

wiqd plugin delete [--env local]               # 4. tear down what provision created
```

> **`provision` comes before `package`, `publish`, and `share`.** `provision` is the only command that writes the selected `.env.<env>` under the configured `environmentFolderPath`. `package` needs it to resolve manifest variables; `publish` and `share` require it as provisioning evidence.

#### Before sharing — prepare a shared deployment

Read **Shared deployment readiness** in `references/wiqd-core/share.md` before
executing a share request. Apply that checkpoint with **`wiqd plugin` commands**,
not `wiqd agent` commands.

If the current deployment is personal, explain: "This deployment is for personal
testing and cannot be shared. We need to prepare a shared deployment first
(normally `dev`)." Confirm additional cloud provisioning unless the user already
authorized it. Keep the same project path and selected shared environment
through validation, provisioning, packaging if needed, and sharing. Reuse
`references/wiqd-core/provision.md` for applicable shared-version handling, using
plugin validation/provision commands. Never treat the mere existence of an env
file as successful provisioning.

For a standard project whose `dev` configuration is confirmed shared, the
authorized preparation sequence is:

```bash
wiqd plugin validate --path <dir> --env dev --json --skill wiqd --workflow plugin
wiqd plugin provision --path <dir> --env dev --json --skill wiqd --workflow plugin
wiqd plugin share --path <dir> --env dev --scope users --email <recipient> --json --skill wiqd --workflow plugin
```

Stop on failed validation, failed provisioning, or cancellation; do not run the
next command or claim success. If a selected shared deployment is already ready,
share it without unnecessary re-provisioning. A custom shared environment stays
selected instead of being replaced with `dev`. Do not provision for help-only or
inspection requests. Tenant-wide sharing requires separate explicit audience
confirmation even if shared provisioning was approved.

Before catalog submission, use the no-submit readiness path when the user asks
for a check rather than an actual tenant change:

```bash
# Fully offline project/path + applicable static DA checks
wiqd plugin publish --dry-run --no-runtime --no-network --json --skill wiqd --workflow plugin

# Full applicable runtime validation for a plugin containing a DA
wiqd plugin publish --dry-run --env local --json --skill wiqd --workflow plugin
```

A skill/connector-only plugin returns an explicit DA-not-applicable skip. Do not
describe that skip as full skill or connector runtime validation. A successful
normal publish means **submitted for tenant admin approval**; it does not mean
approved, immediately tenant-wide, shared, or public-store published.

For an OpenAPI custom connector, static validation does not inspect the top-level connector.
Package first, then run `wiqd plugin validate --mode deep`. Local packaging and server-side AVL
support are separate: the bundled fx-core `3.1.5-alpha.36e30da2f6.0` supports local devPreview
packaging of OpenAPI and remote MCP connectors using `ConnectionVault`, preserving their fields
in the ZIP and leaving the source manifest unchanged. Do not infer server acceptance from local
packaging success. Supply a built ZIP with `--package-file` for deep validation and report its actual server verdict;
validation alone does not prove connector invocation or publication acceptance. `wiqd plugin export`
intentionally fails for this connector kind because Open Plugin has no verified
`ConnectionVault` representation.

### 5. Teardown

`wiqd plugin delete` (alias `wiqd plugin uninstall`) is the inverse of `provision` — it removes the cloud resources (M365 app, app registration, bot registration) that provisioning created. It is the only plugin command that destroys tenant state. Ask the user to confirm the exact target first; because agent command execution has no interactive TTY, add `--yes` only after that affirmative reply.

```bash
wiqd plugin delete --yes --skill wiqd                             # project mode: reads env/.env.local, deletes, removes the env file
wiqd plugin delete --env dev --keep-env-file --yes --skill wiqd   # delete the cloud side but keep the local env file
wiqd plugin delete --title-id T_xxx --yes --skill wiqd            # title-id mode: no local project needed
```

Two modes, chosen by whether `--title-id` is present:

| Mode         | Needs a local project? | Reads             | Use when                                                        |
| ------------ | ---------------------- | ----------------- | --------------------------------------------------------------- |
| **env**      | yes                    | `env/.env.<env>`  | you still have the project you provisioned from                 |
| **title-id** | no                     | nothing local     | the project is gone, or you're cleaning up someone else's upload |

Teardown **never touches plugin source** — `appPackage/`, `wiqd.plugin.json`, skills, and connectors all survive. Only cloud resources and (unless `--keep-env-file`) the env file for that environment are removed, so a delete can always be followed by a fresh `wiqd plugin provision`.

## Interoperability: Open Plugin / Claude / Cursor

`import` and `export` connect the wiqd plugin lifecycle to the cross-tool **Open Plugin** format (also consumed by Claude and Cursor).

### Import — an alternate entry point

```bash
wiqd plugin import --path <open-plugin-dir> [--output <dir>]
```

| Option                 | Notes                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| `--path` / `-p`        | **Required.** Source Open Plugin directory                                               |
| `--output` / `-o`      | Destination project directory (defaults to `./<plugin-name>`)                            |
| `--privacy-url`        | Privacy statement URL — **required unless** the source carries wiqd's round-trip block   |
| `--terms-url`          | Terms-of-use URL — **required unless** the source carries wiqd's round-trip block        |
| `--website-url`        | Website URL (the importer falls back to the source `plugin.json` homepage/author URL)     |
| `--app-id`             | Teams/M365 app id (UUID) to stamp                                                        |
| `--default-auth-type`  | `Auto` \| `None` \| `OAuthPluginVault` \| `ApiKeyPluginVault` (default: `Auto`)          |
| `--package-name`       | Reverse-DNS package name                                                                 |

The source must contain a recognizable plugin manifest (`plugin.json`, `.claude-plugin/`, or `.cursor-plugin/`); import fails with exit `2` if it does not, before the adapter is invoked.

**Privacy/terms URLs.** M365 requires them, and the Open Plugin standard has no slot for them, so on a **first** import of a foreign plugin the user must supply `--privacy-url` and `--terms-url`. If the source was produced by `wiqd plugin export`, they are already carried in the round-trip block and both flags are optional — don't prompt for them.

After import, `cd` into the produced project and continue with `add …` / `validate` as normal.

### Export — an interoperability output

```bash
wiqd plugin export [--path <dir>] [--output <dir>] [--format open-plugin|claude-plugin|cursor-plugin]
```

| Option            | Notes                                                                    |
| ----------------- | ------------------------------------------------------------------------ |
| `--path` / `-p`   | Plugin project path (defaults to CWD)                                    |
| `--output` / `-o` | Output directory (defaults to `<path>/export/<format>`)                  |
| `--format`        | `open-plugin` (default) \| `claude-plugin` \| `cursor-plugin`            |

Pick `--format` from the user's stated destination: "for Claude" → `claude-plugin`, "for Cursor" → `cursor-plugin`, generic/unstated → `open-plugin`.

**Round-tripping is lossless.** The Open Plugin standard has no slot for a declarative agent, so wiqd carries the DA manifest and its instructions file under `<export>/agent/` and records them in a wiqd-owned `x-wiqd` key in the exported manifest. Hosts that don't know the key ignore it and still see a valid standard plugin; `wiqd plugin import` reads it back and restores the agent. So `export` → `import` returns an equivalent project — but **only if the whole export directory is kept together**. If the user copies just the manifest, the agent is lost and import fails loudly rather than producing an agent-less project.

Validate before exporting — a plugin that doesn't pass `wiqd plugin validate` will export its problems.

## Authoring a skill that calls an MCP server

A common request is _"build a skill that calls the MCP server at `https://…`."_ In the plugin model these are **two composed capabilities**:

1. **The MCP server → an agent connector.** Register the remote MCP endpoint so the plugin can reach it:

   ```bash
   wiqd plugin add connector --name "<Server> MCP" --description "<what the server does>" --url "https://<mcp-server>/mcp"
   ```

2. **The workflow instructions → a skill.** Scaffold the `SKILL.md` and author the claims/workflow instructions in it:

   ```bash
   wiqd plugin add skill --name "<Skill Name>"
   ```

   Then edit the generated `appPackage/skills/<slug>/SKILL.md` to describe the end-to-end workflow — how the agent should use the connector's tools, the steps, inputs, and guardrails.

**Inspect the MCP server first.** Before designing the skill, inspect the server's advertised tools (fetch its tool list / manifest from the `--url`) so the SKILL.md instructions reference real tool names and shapes. Iterate on the SKILL.md until the plugin is coherent, then run `wiqd plugin validate` and resolve every finding before declaring it ready.

**If the server requires authentication.** `agentConnectors` supports `OAuthPluginVault`, `ApiKeyPluginVault`, and `DynamicClientRegistration` — all of which reference a credential stored elsewhere by id. The credential itself must be registered first, either in the Teams Developer Portal (**Tools → OAuth client registration**) or by an `oauth/register` step in `m365agents.yml` — see [authentication.md](../references/wiqd-core/authentication.md). Then wire the id in:

```bash
wiqd plugin add connector --name "<Server> MCP" --description "<what it does>" \
  --url "https://<mcp-server>/mcp" --auth-type oauth --auth-reference-id "<reference-id>"
```

Three things to tell the user up front, because each one is commonly discovered far too late:

- **`applicableToApps: AnyApp`** — if you register through `oauth/register`, set it explicitly. Left implicit it can bind the registration to the Teams app id, which Copilot never resolves, so every tool call 404s after a green provision.
- **Entra-protected servers cannot use DCR.** Entra publishes no RFC 7591 `registration_endpoint`, so `DynamicClientRegistration` is unusable against **any** Entra-protected MCP server — including every first-party Microsoft one. A client id must be registered by hand, and `agentConnectors` has no `microsoftEntra`/SSO type, so this is unavoidable. For servers that genuinely support DCR, use `--auth-type dcr`, which omits the authorization node — do not hand-author `{"type": "DynamicClientRegistration"}`.
- **Admin consent is not verified at provision time.** A scope nobody in the tenant can consent to still provisions cleanly and fails later at a "Need admin approval" page.

**Never** put a client id, client secret, or token in the manifest — only the reference id belongs there.

## Report + next steps

After each step, report the outcome and suggest the logical next action:

- After `create` **or `import`** → "Add a skill", "Add a connector", "Add a declarative agent".
- After `add …` → "Add another capability", or "Validate the plugin".
- After a clean `validate` → "Provision the plugin" or "Export it for Claude/Cursor". If the manifest contains `openApiConnector`, omit the export suggestion and explain that Open Plugin cannot represent its `ConnectionVault` reference; static validation does not establish packaging or deployment readiness.
- After personal `provision` → "Test the plugin yourself"; explain that sharing
  needs a shared deployment and offer preparation without starting it.
- After shared `provision` → "Package the plugin", then "Share it" using the same
  project path and shared environment, subject to the readiness checkpoint above.
- After `export` → tell the user **where** the output landed and that the whole directory must travel together for a lossless round trip.

## Anti-patterns

- ❌ Don't scaffold a `wiqd agent` when the user asked for a **standalone plugin** — that produces an agent, not a reusable plugin.
- ❌ Don't tell the user a **Cowork plugin** needs a different platform, SDK, or toolchain — it is the same Microsoft 365 app package this workflow builds (see Terminology). Treating a host surface as a separate product is never a reason to decline.
- ❌ Don't hand-author plugin manifest files — always go through `wiqd plugin add …` so `manifest.json` and `wiqd.plugin.json` stay in sync.
- ❌ Don't declare a plugin "ready" without a clean `wiqd plugin validate`.
- ❌ Don't silently enable the alpha flag — tell the user first (Preflight step 2).
- ❌ Don't `create` and then hand-copy an existing Open Plugin's files into it — use `plugin import`, which is the supported entry point and preserves round-trip data.
- ❌ Don't promise that importing a plugin merges its capabilities into an existing agent. The supported import flow creates a new plugin project from a foreign-format source.
- ❌ Don't `package` before `provision` — `package` needs the `env/.env.<env>` that `provision` writes.
- ❌ Don't tell the user an export round-trips if they only keep the manifest — the `agent/` payload must travel with it.
