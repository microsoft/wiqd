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
surface. A standalone [`wiqd agent`](/cli/reference/#wiqd-agent-create) project is simply the
special case of a plugin whose single capability is a declarative agent — structurally the two are
the same app package. Think in terms of the plugin first, and reach for the declarative agent as
the capability that gives the plugin its conversational surface.

## A plugin composes capabilities

A plugin can carry one or more of these, declared as top-level components in the app manifest:

| Capability      | Manifest location                             | Added by                                    |
| ---------------- | ---------------------------------------------- | -------------------------------------------- |
| An **agent**     | `copilotAgents.declarativeAgents` (→ `declarativeAgent.json`) | [`wiqd plugin add agent`](/cli/reference/#wiqd-plugin-add-agent) |
| **Skills**       | `agentSkills[]` (each a `SKILL.md` folder)     | [`wiqd plugin add skill`](/cli/reference/#wiqd-plugin-add-skill) |
| **Connectors**   | `agentConnectors[]` (remote MCP servers)       | [`wiqd plugin add connector`](/cli/reference/#wiqd-plugin-add-connector) |

A declarative agent brings its own API plugins (`actions[]`) and MCP references along with it —
those live inside the agent's own manifest, not as separate top-level plugin components.

A wiqd-owned descriptor, `wiqd.plugin.json`, marks the project root and caches the capability list
for fast enumeration (used by [`wiqd plugin list`](/cli/reference/#wiqd-plugin-list)). It is an
**advisory cache** — the app manifest (`appPackage/manifest.json`) is always the source of truth,
and commands like `wiqd plugin show` and `wiqd plugin validate` read the manifest itself rather
than trusting the cache.

`wiqd plugin create` pins the scaffolded manifest to `manifestVersion: "1.29"` — the numbered (GA)
Teams schema that supports `agentSkills` (1.28) and, at 1.29, url-only `agentConnectors` (where
`mcpToolDescription` becomes optional) — so composed capabilities validate against a stable schema
rather than `devPreview`.

## The build loop

Capabilities compose into a single app package, in any combination, through one lifecycle — the
same lifecycle a declarative-agent-only plugin uses:

```bash
wiqd plugin create --name my-plugin                 # scaffold from the ATK blank app template
cd my-plugin
wiqd plugin add agent                               # add a declarative agent component
wiqd plugin add skill --name "Triage Issues"        # add a SKILL.md skill
wiqd plugin add connector --name "Tools" \
  --description "Toolbelt over MCP" --url https://tools.contoso.com/mcp
wiqd plugin validate                                # static MVL check of the DA surface
wiqd plugin package                                 # build a deployable .zip
wiqd plugin validate --mode deep                    # full app-package validation via ATK/AVL
wiqd plugin provision                               # register with Microsoft 365
wiqd plugin share --scope users --email you@contoso.com
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
| 1 | [`wiqd plugin add skill`](/cli/reference/#wiqd-plugin-add-skill) | Scaffolds a `SKILL.md` folder and registers it in the **plugin's own app manifest** (`agentSkills[]`)          | A standalone plugin project (`wiqd.plugin.json`)                  |
| 2 | [`wiqd agent add skill`](/cli/reference/#wiqd-agent-add-skill) | Adds a skill to an existing **declarative agent** project's own skill surface, via ATK (`atk add skill`)       | An agent project (`m365agents.yml`)                                |
| 3 | Extension-contributed **Copilot skills**            | The `SKILL.md` packages a wiqd *extension* bundles, that Copilot CLI itself loads as part of the `wiqd@wiqd` plugin | A wiqd extension's `skills/` directory, merged at `wiqd install plugin` time |

### 1. `wiqd plugin add skill` — a plugin capability

This scaffolds `appPackage/skills/<slug>/SKILL.md` and adds an entry to the manifest's
`agentSkills[]` — one of the three top-level capabilities a **standalone plugin** composes (see
above). It requires a plugin project and does not require an agent component to be present; a
plugin can be skill-only.

### 2. `wiqd agent add skill` — an agent's own skill

This shells out to `atk add skill` to add a skill directly into an **existing agent project**,
in-place. It produces the same kind of artifact (a `SKILL.md` folder referenced from
`agentSkills[]`), but the command operates on an agent project rather than a standalone plugin, and
it additionally supports `--from <path>` to import an existing skill directory or `.zip`, and
`--expose-to-copilot` to expose the skill to mainline M365 Copilot. Use this when you're extending
an agent you already have; use `wiqd plugin add skill` when you're composing a new, independent
plugin from scratch.

### 3. Extension-contributed Copilot skills

This is a different axis entirely — it's not about the M365 app package at all. A wiqd *extension*
(the packages that contribute `wiqd` CLI commands, like the Agents Toolkit or Work IQ extensions)
can ship its own `SKILL.md` files that teach **GitHub Copilot CLI itself** how to drive that
extension's commands conversationally. Those skills are merged into the single bundled `wiqd@wiqd`
Copilot plugin at install time — they have nothing to do with `agentSkills[]` or any M365 app
package.

## Go deeper

- [`wiqd plugin`](/cli/reference/#wiqd-plugin) — the full command reference
- [Build a plugin](/getting-started/build-a-plugin/) — a step-by-step walkthrough
- [`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) — static MVL vs. package-first deep validation
- [Declarative agents](/concepts/declarative-agents/) — the agent capability a plugin can compose
- [Host vs extensions](/concepts/host-vs-extensions/) — how wiqd itself is structured (a different use of "extension")
