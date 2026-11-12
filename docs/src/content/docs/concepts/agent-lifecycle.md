---
title: Agent component lifecycle
description: Agent-specific authoring and iteration within WIQD's plugin-first lifecycle, including existing wiqd agent projects.
---

# Agent component lifecycle

**Start with the [plugin lifecycle](/getting-started/build-a-plugin/)** when
building a new Microsoft 365 Copilot experience. The plugin is the app package;
a declarative agent is an optional component alongside skills and connectors.
Compose it with `wiqd plugin add agent`, and use `wiqd plugin` lifecycle
commands to deliver the plugin as a unit.

This page covers agent-specific authoring and iteration, including existing
`wiqd agent` projects. Those commands remain supported. They are not evidence
that every plugin requires an agent or that the two command trees are already
interchangeable.

## The phases

```text
create ─▶ edit ─▶ validate ─▶ provision ─▶ package ─▶ publish ─▶ monitor
                     ▲                                              │
                     └──────────────── iterate ─────────────────────┘
```

### 1. Create

Scaffold a new project from a template.

```bash
wiqd plugin create --name my-plugin
cd my-plugin
wiqd plugin add agent --name my-agent
```

The first command creates the marked container; the second adds the referenced
declarative-agent files without flattening root plugin skills or connectors.

### 2. Edit

Open the project in your editor. Tweak the instructions, add knowledge sources, attach actions, or add conversation starters with the bundled VS Code extension. You can also script edits with `wiqd agent add action` and `wiqd agent add skill` (the latter is behind the `agent-skills` preview flag — see [Feature flags](/cli/reference/#feature-flags)).

#### Worker Agents

Ask the WIQD Skill to add or connect a Worker. Until friendly-name resolution ships, provide the
canonical `worker_agents[].id` value directly. Once the resolver is available, the Skill will use it
automatically; you do not need to invoke the resolver or supply an internal workflow ID. The Skill
will not guess from a friendly name or truncate a full composite agent ID. Worker authoring requires
a schema version that supports `worker_agents` (v1.6 or later), and it adds only `{ "id": "..." }`
entries; local `{ "file": "..." }` Workers are not supported.

You can also ask the Skill to remove or disconnect a Worker. It confirms the exact ID and removes
only the matching manifest reference; it never deletes the deployed Worker. When the last reference
is removed, the Skill removes the `worker_agents` property instead of leaving an empty array. This
keeps v1.6 manifests valid and normalizes the same state for later schema versions. Adding an
existing ID or removing an absent ID is a no-op. In either flow the Skill preserves unrelated
manifest content and validates the project before editing and again after a changed edit. An invalid
project remains unchanged. Validation does not deploy the change: provisioning happens only when
you explicitly ask to deploy or provision. Test and evaluate requests use the eval workflow and do
not implicitly provision.

### 3. Validate

Catch problems before deploying.

```bash
wiqd plugin validate --mode source --path . --env local  # offline saved-source diagnostics
wiqd plugin validate --mode package --package-file ./final.zip  # existing final ZIP through TDP
```

Source mode runs saved-source diagnostics offline through the same service as the editor.
Package mode uploads an existing ZIP to Teams Developer Portal; Marketplace adds StoreOps checks
on that same captured ZIP. Neither mode builds automatically. Source is not whole-plugin
or final-package acceptance. See [Validation & MVL](/concepts/validation-mvl/).

### 4. Provision

Deploy the agent to an [environment](/concepts/environments/). The first run creates the M365 app registration; subsequent runs update it.

```bash
wiqd plugin provision --env dev
```

Provision validates the package references it is about to upload. DA-only
`agent_skills[].folder` entries require
`wiqd config flags set agent-skills true`; local `worker_agents[].file` entries are rejected in
favor of published `worker_agents[].id` references. WIQD follows the DA file paths declared by
`appPackage/manifest.json` and never assumes a fixed DA filename.

### 5. Package

Build the distributable `.zip` for sideloading or upload.

```bash
wiqd plugin package --env dev
```

Package checks referenced files before building the ZIP. Top-level
`agentSkills[]` Cowork skills and DA-manifest `agent_skills[]` Chat skills remain separate sets;
dual registration is not required. See [`wiqd plugin package`](/cli/plugin-package/) for the
full contract. Package fails closed when `appPackage/.generated/manifest.json` exists or the active
lifecycle configuration contains `typeSpec/compile`; use a supported source manifest
so the checked manifest is the one packaged.

### 6. Publish

Submit the package to the org catalog for tenant administrator approval.
Other users can discover it only after approval; submission is not approval.

```bash
wiqd plugin publish --env dev
```

Publish applies the same package-reference checks because it builds the
package before catalog submission. Enable `agent-skills` for DA-only skill
folders, and use published `worker_agents[].id` references instead of local
Worker files. With `--manifest`, validation and packaging both use that exact
contained app manifest and resolve its references from the manifest's parent
directory; without it they use `appPackage/manifest.json`. Normal publish uses
the same generated/TypeSpec fail-closed rule as package.

### 7. Monitor & iterate

Once the agent is live, query its usage and health, then loop back to step 2.

```bash
wiqd agent monitor --env dev     # ask the Insights Agent
wiqd plugin ask --component agent -q "..." # send a test prompt
wiqd agent eval --env dev        # run quality evaluations
```

## Side branches

A few commands sit outside the linear pipeline but you'll use them often:

- **`wiqd plugin show`** — complete local project inspection.
- **`wiqd agent show --id|--name`** — the deployed agent's Work IQ card.
- **`wiqd plugin list environments` / `add environment` / `reset environment`** — manage environment definitions.
- **`wiqd plugin share`** — give other users access during development.
- **`wiqd plugin delete`** — tear down cloud resources.

## Go deeper

- [Environments](/concepts/environments/) — `local`, `dev`, `staging`, `prod`
- [`wiqd plugin create`](/cli/reference/#wiqd-plugin-create), [`plugin add agent`](/cli/reference/#wiqd-plugin-add-agent), [`provision`](/cli/reference/#wiqd-plugin-provision), [`package`](/cli/reference/#wiqd-plugin-package), [`publish`](/cli/reference/#wiqd-plugin-publish)
- [wiqd Core extension](/extensions/provided/core/) — implements most of these phases
- [Eval extension](/extensions/provided/eval/) — quality evaluations on deployed agents
