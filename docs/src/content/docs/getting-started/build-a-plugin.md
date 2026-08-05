---
title: Build a Plugin
description: A step-by-step walkthrough of the alpha wiqd plugin construct — compose an agent, a skill, and a connector into one Microsoft 365 app package, then validate, package, provision, and share it.
---

# Build a Plugin: Compose Your First Standalone Plugin

This guide walks you through composing a standalone **plugin** — a Microsoft 365 app package that
can carry a declarative agent, one or more skills, and one or more remote MCP connectors — then
validating, packaging, provisioning, and sharing it. The plugin is the primary construct; the
declarative agent you add in Step 2 is simply one of its capabilities. If you haven't yet, read
[What is a plugin?](/concepts/plugins/) first for the mental model.

:::caution
**Alpha.** The `wiqd plugin` command tree is enabled by default, but the surface is still alpha and
the interface may change without notice.
:::

## Step 1: Create the plugin project

```bash
wiqd plugin create --name my-plugin
cd my-plugin
```

This scaffolds a minimal Microsoft 365 app package (`atk new -c blank` under the hood — the same
Teams manifest, icons, and `m365agents.yml` shape `wiqd agent create` produces) and writes a
`wiqd.plugin.json` descriptor at the project root so the rest of the `wiqd plugin` commands
recognize it. It pins `appPackage/manifest.json` to `manifestVersion: "1.29"` so the capabilities
you add next stay on a numbered (GA) schema. The project starts with **no capabilities** — you
compose them in the next three steps.

## Step 2: Add a declarative agent

```bash
wiqd plugin add agent
```

Adds a declarative agent component: `appPackage/declarativeAgent.json` and
`appPackage/instruction.txt`, with an entry merged into the manifest's
`copilotAgents.declarativeAgents[]`. This is the same artifact `wiqd agent create` produces — a
plugin's agent capability and a standalone agent project are structurally the same thing, which is
why the declarative agent is best understood as a capability of the plugin rather than a separate
surface.

## Step 3: Add a skill

```bash
wiqd plugin add skill --name "Triage Issues"
```

Scaffolds a `SKILL.md` folder under `appPackage/skills/` and registers it in the manifest's
`agentSkills[]`. Skills compose at the plugin level and don't require the agent component from
Step 2 — a plugin can be skill-only.

:::note
This is **not** the same command as `wiqd agent add skill`, which adds a skill to an *existing
agent project* instead of a standalone plugin. See [What is a plugin? → Three things wiqd calls a
"skill"](/concepts/plugins/#three-things-wiqd-calls-a-skill) if you're unsure which one you
need.
:::

## Step 4: Add a remote MCP connector

```bash
wiqd plugin add connector --name "Contoso Tools" \
  --description "Contoso toolbelt over MCP" --url https://tools.contoso.com/mcp
```

Adds a remote MCP agent connector to the manifest's `agentConnectors[]`. Under `manifestVersion`
1.29 the connector is **URL-only** — just the remote MCP server's `https://` URL; the server
advertises its own tools at runtime, so there's no separate tool-description file to author.

## Step 5: Validate (static)

```bash
wiqd plugin validate
```

Runs the offline **MVL** (Manifest Validation Library) engine over the declarative-agent surface —
`declarativeAgent.json` plus any referenced API-plugin manifest or OpenAPI specs. It does not check
the top-level Teams manifest or `agentSkills`/`agentConnectors` content, so a skill-only or
connector-only plugin passes this step vacuously. Full coverage comes from the deep mode in Step 7.

## Step 6: Package

```bash
wiqd plugin package
```

Builds a deployable `.zip` from the composed app package (`appPackage/build/appPackage.<env>.zip`
by default). This is a prerequisite for deep validation and for provisioning to some environments.

## Step 7: Validate (deep, package-first)

```bash
wiqd plugin validate --mode deep
```

Validates the **built package** from Step 6 against **AVL** (App Validation Library) through the
Teams Developer Portal, via ATK. Deep mode is package-first — it resolves the newest
`appPackage/build/*.zip` (or `--package-file`) and fails closed (exit `2`) if no package exists yet,
so it must come after `wiqd plugin package`, not before.

## Step 8: Provision

```bash
wiqd plugin provision
```

Registers the plugin with Microsoft 365 for the target environment (`local` by default) and writes
the resulting `env/.env.<env>` file.

## Step 9: Share

```bash
wiqd plugin share --scope users --email you@contoso.com
```

Shares the provisioned plugin with specific users. To share with your entire tenant instead:

```bash
wiqd plugin share --scope tenant
```

## Alternative entry point: import an existing plugin

Already have a plugin authored as an Open Plugin (or in the Claude or Cursor plugin shape)? Import
it instead of starting from `wiqd plugin create`:

```bash
wiqd plugin import --path ./my-open-plugin \
  --privacy-url https://contoso.com/privacy \
  --terms-url https://contoso.com/terms
```

`wiqd plugin import` runs `atk import openplugin` under the hood and then derives the
`wiqd.plugin.json` capability set from the resulting manifest. An imported project flows through the
**read-only** lifecycle — [validate](/cli/reference/#wiqd-plugin-validate) and
[show & list](/cli/reference/#wiqd-plugin-show) — but **cannot yet be packaged, provisioned, or
shared** (Steps 6–9): `atk import openplugin` omits the local deploy scaffold those steps need. See
[`wiqd plugin import`](/cli/reference/#wiqd-plugin-import) for the current limitation.
`--privacy-url` and `--terms-url` are only required when the source doesn't already carry the
round-trip metadata a prior `wiqd plugin export` would have written.

## Alternative exit point: export to another format

To hand your plugin to a tool other than Microsoft 365 — or round-trip it back through
`wiqd plugin import` later — export it:

```bash
wiqd plugin export --format open-plugin
```

`--format` also accepts `claude-plugin` and `cursor-plugin` to emit those hosts' plugin shapes. The
output defaults to `<path>/export/<format>` and is an uncompressed directory (`wiqd plugin package`
is the separate step that produces the compressed Microsoft 365 `.zip`).

## What's Next?

- [What is a plugin?](/concepts/plugins/) — the mental model and the three meanings of "skill"
- [`wiqd plugin`](/cli/reference/#wiqd-plugin) — the full command reference
- [`wiqd plugin validate`](/cli/reference/#wiqd-plugin-validate) — static vs. deep validation in depth
- [`wiqd plugin package`](/cli/reference/#wiqd-plugin-package) — the deploy lifecycle (package, provision & share)
- [`wiqd plugin import`](/cli/reference/#wiqd-plugin-import) / [`wiqd plugin export`](/cli/reference/#wiqd-plugin-export) — the interop commands in full
- [Quickstart](/getting-started/quickstart/) — the equivalent 5-minute walkthrough for a plain `wiqd agent` project
