---
title: What is a plugin?
description: The mental model behind the wiqd plugin construct — a Microsoft 365 app package that composes an agent, skills, and connectors — and how it differs from the other things wiqd calls a "skill".
---

# What is a plugin?

:::caution
**Alpha.** The `wiqd plugin` command tree is enabled by default, but the surface is still alpha
and the interface may change without notice.
:::

`wiqd plugin` is the **primary, superordinate developer construct** in wiqd. A plugin is a
Microsoft 365 / Teams **app package** — the same `appPackage/` infrastructure wiqd already
scaffolds, not a new artifact type — and it is the **source-of-truth artifact**: everything wiqd
knows about a plugin's capabilities is derived from it, not from any wiqd-side cache.

A **declarative agent is one of the capabilities a plugin composes**, not a separate parallel
surface. A standalone [`wiqd plugin`](/cli/reference/#wiqd-plugin-create) project is simply the
special case of a plugin whose single capability is a declarative agent — structurally the two are
the same app package. Think in terms of the plugin first, and reach for the declarative agent as
the capability that gives the plugin its conversational surface.

## One artifact, many names

"**Cowork plugin**", "**Copilot Cowork plugin**", "**Microsoft 365 Copilot plugin**", and
"**standalone plugin**" all describe the **same artifact**: one MOS (Teams) app package. An
unqualified "**Copilot plugin**" means that package too, whenever the surface in question is an
M365 one. "Standalone" is a wiqd word that distinguishes a reusable plugin project from a
declarative-agent project — it is not a platform qualifier. Copilot Cowork, Microsoft 365 Copilot
chat, Teams, and Office are **surfaces that host that one package**, not separate plugin platforms
with their own SDKs. So if you came here to build a plugin for Copilot Cowork, you are in the right
place — `wiqd plugin` is the toolchain. Start with the
[build-a-plugin walkthrough](/getting-started/build-a-plugin/).

:::note[The GitHub Copilot CLI plugin is a different artifact]
The `wiqd@wiqd` **Copilot CLI plugin** — the skills and guide agent that teach GitHub Copilot CLI
how to drive `wiqd` — is **not** an M365 app package and is **not** authored with `wiqd plugin`. It
is installed through the host's [marketplace flow](/getting-started/installation/#path-1-install-from-the-marketplace),
independently of the CLI, rather than scaffolded. See Extension-contributed Copilot
skills below for what it is made of.
:::

## A plugin composes capabilities

A plugin can carry one or more of these, declared as top-level components in the app manifest:

| Capability      | Manifest location                             | Added by                                    |
| ---------------- | ---------------------------------------------- | -------------------------------------------- |
| An **agent**     | `copilotAgents.declarativeAgents` (→ `declarativeAgent.json`) | [`wiqd plugin add agent`](/cli/reference/#wiqd-plugin-add-agent) |
| **Skills**       | `agentSkills[]` (each a `SKILL.md` folder)     | [`wiqd plugin add skill`](/cli/reference/#wiqd-plugin-add-skill) |
| **Connectors**   | `agentConnectors[]` (remote MCP or existing OpenAPI custom connectors) | [`wiqd plugin add connector`](/cli/reference/#wiqd-plugin-add-connector) — or reuse a published catalog connector found with [`wiqd connector`](/cli/connector/) |

A declarative agent brings its own API plugins (`actions[]`) and MCP references along with it —
those live inside the agent's own manifest, not as separate top-level plugin components.

WIQD recognizes a project structurally from contained `m365agents.yml` and
`appPackage/manifest.json`. The app manifest owns the normalized project name
and capability collections; `show`, `list`, and `validate` derive them on every
read without an identity/cache file. A historical `wiqd.plugin.json` is ignored
and may be deleted manually after checking external-tool dependencies.

`wiqd plugin create` pins the scaffolded manifest to `manifestVersion: "1.29"` — the numbered (GA)
Teams schema that supports `agentSkills` (1.28) and, at 1.29, url-only `agentConnectors` (where
`mcpToolDescription` becomes optional) — so composed capabilities validate against a stable schema
rather than `devPreview`.

That stable default remains unchanged when you add a remote MCP connector. Referencing an existing
OpenAPI custom connector is a separate, explicitly preview-only path:

```bash
wiqd plugin add connector --kind openapi --name "Contoso Kusto" \
  --description "Existing custom connector" \
  --auth-reference-id shared_kusto --dev-preview
```

This writes only a `ConnectionVault` logical-name pointer and updates both app-manifest version
fields to `devPreview`. It does not create the custom connector, invent an endpoint, or treat a
tentative numbered manifest version as supported.

Local devPreview packaging supports
`agentConnectors[].toolSource.openApiConnector` and remote MCP connectors using `ConnectionVault`,
preserving their fields without changing the source manifest. Local packaging success does not
guarantee server-side acceptance.
Package validation needs a built ZIP selected with `--package-file`; use
`wiqd plugin validate --mode package --package-file "<zip>"`. Preserve the
connector and inspect the actual validation verdict; do not rewrite or drop it to bypass
the local schema. See the
[plugin authoring reference](/getting-started/plugin-reference/#existing-openapi-custom-connectors)
for the current limitations.

### Local packaging without registration

For a **devPreview connector/skill-only plugin**, build a ZIP for manual upload testing
without provisioning or Teams registration:

```bash
wiqd plugin package --offline --path ./my-plugin --output ./plugin.zip
```

No app ID input or Teams setup is needed. A literal manifest GUID is reused; otherwise
WIQD generates a GUID once and saves it in `wiqd.plugin.id` at the project root.
Keep this file with your project so later packages use the same identity. It is local
package metadata, not a Teams or Entra registration, and is never included in the ZIP.
A malformed saved ID fails rather than being replaced. The ID may remain after a later
packaging failure so retries keep the same identity. No source manifest or environment
file is changed.
Only `${{TEAMS_APP_ID}}` and `${{APP_NAME_SUFFIX}}` are resolved in the archived manifest;
other unresolved placeholders fail. `--env` labels the output, not a credential environment.

Offline packaging preserves remote MCP and OpenAPI connectors, including ConnectionVault
references, and includes registered top-level skill folders, icons and explicit tool-description
JSON files. Declarative agents, bots, tabs, localization and TypeSpec/generated manifests are
not supported in this mode. Unsafe paths, symlinks, secret-like filenames and duplicate ZIP
members fail; input/archive limits are 64 MiB, 1 MiB per JSON, 2,000 visited entries and
32 directory levels. An existing ZIP is preserved if packaging fails.

The local validator uses the unmodified DevPreview schema packaged with the SDK, including
both connector types, without fetching the live schema URL. **A successful local ZIP is not
proof of Cowork, AVL or Store acceptance.** No upload or server validation occurs.
Normal provisioned packaging and `plugin validate` remain unchanged.

## The build loop

Capabilities compose into a single app package, in any combination, through one lifecycle — the
same lifecycle a declarative-agent-only plugin uses:

```bash
wiqd plugin create --name my-plugin                 # scaffold from the core blank app template
cd my-plugin
wiqd plugin add agent                               # add a declarative agent component
wiqd plugin add skill --name "Triage Issues"        # add a SKILL.md skill
wiqd plugin add connector --name "Tools" \
  --description "Toolbelt over MCP" --url https://tools.contoso.com/mcp
wiqd plugin validate --mode source --env dev        # offline check of the DA surface
wiqd plugin provision --env dev                     # register with Microsoft 365 (writes env/.env.dev)
wiqd plugin package --env dev                       # build a deployable .zip
wiqd plugin validate --mode package --env dev --package-file "<zip>" # validate the final captured ZIP
wiqd plugin publish --env dev                       # submit to the org catalog for tenant admin approval
wiqd plugin share --scope users --email you@contoso.com --env dev
```

Already have a plugin authored for another host? [`wiqd plugin import`](/cli/reference/#wiqd-plugin-import)
converts an Open Plugin (or Claude/Cursor plugin) into a wiqd plugin project instead of starting
from `create`, and [`wiqd plugin export`](/cli/reference/#wiqd-plugin-export) does the inverse.
See the [build-a-plugin walkthrough](/getting-started/build-a-plugin/) for the full
step-by-step.

## Three things wiqd calls a skill

The word "skill" is overloaded across wiqd — it means three genuinely different things depending on
which command you're looking at. Confusing them is the most common source of friction when you're
new to the plugin construct.

| # | Surface                                            | What it does                                                                                                    | Lives in                                                          |
| - | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| 1 | [`wiqd plugin add skill`](/cli/reference/#wiqd-plugin-add-skill) | Scaffolds a `SKILL.md` folder and registers it in the **plugin's own app manifest** (`agentSkills[]`)          | A structural standalone plugin project (`m365agents.yml` + root app manifest) |
| 2 | [`wiqd agent add skill`](/cli/reference/#wiqd-agent-add-skill) | Adds a skill to an existing **declarative agent** project's own skill surface, via the core lifecycle backend       | An agent project (`m365agents.yml`)                                |
| 3 | Extension-contributed **Copilot skills** | The `SKILL.md` packages a wiqd *extension* bundles, that the host loads as part of the marketplace plugin | A wiqd extension's `skills/` directory, selected by the marketplace release profile |

### 1. `wiqd plugin add skill` — a plugin capability

This scaffolds `appPackage/skills/<slug>/SKILL.md` and adds an entry to the manifest's
`agentSkills[]` — one of the three top-level capabilities a **standalone plugin** composes (see
above). It requires a plugin project and does not require an agent component to be present; a
plugin can be skill-only.

### 2. `wiqd agent add skill` — an agent's own skill

This adds a skill directly into an **existing agent project**,
in-place. It produces a `SKILL.md` folder referenced from the declarative-agent manifest's
`agent_skills[]`; it does not add the root Cowork `agentSkills[]` registration. The command also
supports `--from <path>` to import an existing skill directory or `.zip`. Use this when you're
extending an agent you already have; use `wiqd plugin add skill` when you're composing a new,
independent Cowork plugin from scratch.

`wiqd agent add skill` sits behind the `agent-skills` [feature flag](/cli/reference/#feature-flags)
(off by default) while the declarative-agent manifest schema for skills is not yet
worldwide (WW). Enable it with `wiqd config flags set agent-skills true`. Once a skill is added, the
declarative-agent file selected by the root app manifest is bumped to manifest version `v1.9` so
downstream services keep working ahead of general availability. Custom contained DA paths are
preserved; WIQD does not create a second default manifest. `wiqd plugin create`'s own scaffold
version is untouched by this.

Keep the flag enabled when packaging, provisioning or publishing an agent that
uses these skills.

### 3. Extension-contributed Copilot skills

This is a different axis entirely — it's not about the M365 app package at all. A wiqd *extension*
(the packages that contribute `wiqd` CLI commands, like the Core or Work IQ extensions)
can ship its own `SKILL.md` files that teach **GitHub Copilot CLI itself** how to drive that
extension's commands conversationally. Install or update the coding-assistant
plugin through its marketplace; installing a CLI extension alone does not refresh
these skills. They have nothing to do with
`agentSkills[]` or any M365 app package.

## Go deeper

- [`wiqd plugin`](/cli/reference/#wiqd-plugin) — the full command reference
- [Build a plugin](/getting-started/build-a-plugin/) — a step-by-step walkthrough
- [`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) — source, package (default) and Marketplace validation
- [Declarative agents](/concepts/declarative-agents/) — the agent capability a plugin can compose
- [Host vs extensions](/concepts/host-vs-extensions/) — how wiqd itself is structured (a different use of "extension")
