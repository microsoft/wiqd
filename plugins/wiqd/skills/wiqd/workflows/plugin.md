---
name: plugin
description: >
  Author a standalone, reusable M365 Copilot plugin — a Teams app package that composes a
  declarative agent, skill(s), and/or agent connector(s) as a first-class, independently
  packageable and validatable deliverable — via the alpha `wiqd plugin` construct. This is
  distinct from adding a plugin capability into a single agent (that is `wiqd agent`). Covers
  the full flow: create (or import an existing Open Plugin) → add skill / connector / agent →
  validate → provision / package / share, plus export back out to Open Plugin, Claude, or Cursor
  format, including authoring a skill that calls a remote MCP server through an agent connector.
trigger-summary: 'create a plugin, standalone plugin, reusable plugin, plugin project, build a plugin, plugin with a skill, plugin with a connector, MCP plugin project, package a plugin, validate a plugin, share a plugin, delete a plugin, tear down a plugin, import an open plugin, export to claude, export to cursor, convert a plugin'
triggers: >
  create a plugin, create a standalone plugin, new plugin, new plugin project, build a plugin,
  build a standalone plugin, author a plugin, make a reusable plugin, reusable plugin,
  standalone plugin, plugin project, plugin with a skill, plugin with a connector,
  add a skill to my plugin, add a connector to my plugin, add an agent to my plugin,
  validate my plugin, package my plugin, share my plugin, show my plugin,
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
routing-intent: 'Authoring a standalone, reusable plugin (create or import, add skill/connector/agent, validate, package, export)'
routing-order: 2
contract-version: 1
routing-requires:
  [
    plugin create,
    plugin import,
    plugin add skill,
    plugin add connector,
    plugin add agent,
    plugin validate,
    plugin show,
    plugin list,
    plugin provision,
    plugin package,
    plugin share,
    plugin export,
    plugin delete,
  ]
---

# Plugin — Standalone Plugin Authoring (alpha)

Author a **standalone, reusable M365 Copilot plugin** as a first-class, independently shippable unit — not something bolted inside one agent project. A plugin is a **Teams app package** (the same `appPackage/` infrastructure `wiqd agent` uses) that composes one or more capabilities: a **declarative agent**, one or more **skills** (`SKILL.md` folders), and one or more **agent connectors** (most often a remote MCP server). It is marked by a light `wiqd.plugin.json` descriptor and flows through the familiar lifecycle: `create → add → validate → provision → package → share`, with `show` / `list` available for inspection at any point. Two interoperability commands bracket that lifecycle: `import` is an alternate **entry point** (in place of `create`) that converts an existing Open Plugin / Claude / Cursor plugin into a wiqd plugin project, and `export` is an **exit point** that converts a wiqd plugin project back out to those formats.

> **Convention:** When calling `wiqd` commands from this skill, always pass `--skill wiqd --workflow plugin`, and add `--json` for any command whose output you need to parse (structured, machine-readable output instead of lossy table text).

> **Alpha.** The `wiqd plugin` construct is enabled by default. The interface may change without notice.

## When to use this workflow

Use this workflow — **not** the `wiqd-core` (agent) workflow — when the user wants a **standalone / reusable plugin**:

- "Create a **standalone plugin**" / "build a **plugin project**" / "author a **reusable plugin**"
- "Build a **plugin with a skill**" (optionally one that calls an MCP server)
- "Add a **skill** / **connector** / **agent** **to my plugin**"
- "Validate / provision / package / share **my plugin**"
- "**Import** an Open Plugin / Claude plugin / Cursor plugin" — bring an existing cross-tool plugin into the wiqd lifecycle
- "**Export** my plugin to Open Plugin / Claude / Cursor" / "make my plugin work in Claude"

## Plugin vs. agent — disambiguation (read this first)

The words "plugin", "skill", and "import" are all overloaded. Route correctly:

| The user wants…                                                                                                         | Workflow                        | Why                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------- |
| A **standalone / reusable plugin** as its own deliverable (create, add skill/connector/agent, validate, package, share) | **this `plugin` workflow**      | The artifact is a plugin app package with its own lifecycle, not an agent                               |
| To **convert an existing Open Plugin / Claude / Cursor plugin into a wiqd plugin project**                              | **this `plugin` workflow** → `plugin import` | Cross-**format** conversion producing a whole new plugin project                                         |
| To convert **a wiqd plugin project out** to Open Plugin / Claude / Cursor format                                        | **this `plugin` workflow** → `plugin export` | Cross-**format** conversion producing an interoperable output directory                                 |
| To add an **API / MCP plugin capability into one existing declarative agent**                                           | `wiqd-core` workflow → Adding Plugins | There "plugin" means a capability composed _inside_ a single agent's manifest (`actions[]` / MCP)       |
| To pull **an existing wiqd plugin into an agent** (`wiqd agent add plugin --from <path>`)                               | `wiqd-core` workflow                  | A **capability merge** into one agent — no format conversion, and the source is already a wiqd plugin   |
| To scaffold a **declarative agent** ("create an agent", "new agent")                                                    | `wiqd-core` workflow → Create         | The artifact is an agent, whose sole capability is a declarative agent                                  |

The two "import"s are the easiest confusion. Disambiguate on **what the source is** and **what comes out**:

- `wiqd plugin import --path <open-plugin-dir>` — source is a **foreign-format** plugin (Open Plugin / Claude / Cursor); output is a **new wiqd plugin project**.
- `wiqd agent add plugin --from <wiqd-plugin>` — source is **already a wiqd plugin**; output is an **existing agent**, modified in place. That is the `wiqd-core` workflow.

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

# A declarative agent component (copilotAgents.declarativeAgents)
wiqd plugin add agent [--folder <dir>]
```

Each `add …` updates `wiqd.plugin.json`'s `capabilities` array after its artifacts are written.

### 3. Validate

```bash
wiqd plugin validate [--path <dir>]
```

Validates the descriptor and component artifacts. Fix any reported errors and re-run until clean before packaging.

### 4. Inspect / lifecycle (as needed)

Inspection is available at any point; the deploy lifecycle runs in this order:

```bash
wiqd plugin show [--path <dir>]                # summary of one plugin
wiqd plugin list [--root <dir>]                # plugins under a directory

wiqd plugin provision [--env local]            # 1. register with M365, writes env/.env.<env>
wiqd plugin package                            # 2. build a deployable .zip
wiqd plugin share [--email <e>]                # 3. share with users/tenant

wiqd plugin delete [--env local]               # 4. tear down what provision created
```

> **`provision` comes before `package`.** `provision` is the only command that writes `env/.env.<env>`, which `package` needs to resolve manifest variables and which `share` requires as a preflight. Running `package` first yields an app package with unresolved tokens.

### 5. Teardown

`wiqd plugin delete` (alias `wiqd plugin uninstall`) is the inverse of `provision` — it removes the cloud resources (M365 app, app registration, bot registration) that provisioning created. It is the only plugin command that destroys tenant state, so it always confirms first unless `--yes` is passed.

```bash
wiqd plugin delete                             # project mode: reads env/.env.local, deletes, removes the env file
wiqd plugin delete --env dev --keep-env-file   # delete the cloud side but keep the local env file
wiqd plugin delete --title-id T_xxx --yes      # title-id mode: no local project needed, no prompt
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

- After `create` **or `import`** → "Add a skill", "Add an MCP connector", "Add a declarative agent".
- After `add …` → "Add another capability", or "Validate the plugin".
- After a clean `validate` → "Provision the plugin", "Reuse it inside an agent with `wiqd agent add plugin --from <path>`", or "Export it for Claude/Cursor".
- After `provision` → "Package the plugin", then "Share it".
- After `export` → tell the user **where** the output landed and that the whole directory must travel together for a lossless round trip.

## Anti-patterns

- ❌ Don't scaffold a `wiqd agent` when the user asked for a **standalone plugin** — that produces an agent, not a reusable plugin.
- ❌ Don't hand-author plugin manifest files — always go through `wiqd plugin add …` so `manifest.json` and `wiqd.plugin.json` stay in sync.
- ❌ Don't declare a plugin "ready" without a clean `wiqd plugin validate`.
- ❌ Don't silently enable the alpha flag — tell the user first (Preflight step 2).
- ❌ Don't `create` and then hand-copy an existing Open Plugin's files into it — use `plugin import`, which is the supported entry point and preserves round-trip data.
- ❌ Don't route "import a plugin" to `wiqd agent add plugin --from` — that merges an **already-wiqd** plugin into an agent and does no format conversion.
- ❌ Don't `package` before `provision` — `package` needs the `env/.env.<env>` that `provision` writes.
- ❌ Don't tell the user an export round-trips if they only keep the manifest — the `agent/` payload must travel with it.
