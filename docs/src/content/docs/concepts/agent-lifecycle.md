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
wiqd agent create --name my-agent
```

You get a directory with the `appPackage/` files described in [Declarative agents](/concepts/declarative-agents/), plus a `m365agents.yml` driver file for the lifecycle commands.

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
wiqd agent validate --env dev              # fast static checks
wiqd agent validate --mode deep --env dev  # full Microsoft 365 project validation
```

Static mode runs the Microsoft Validation Layer (MVL) engine offline — no network, no auth, sub-second. Deep mode adds semantic project checks through the validation/core extension boundary. See [Validation & MVL](/concepts/validation-mvl/).

### 4. Provision

Deploy the agent to an [environment](/concepts/environments/). The first run creates the M365 app registration; subsequent runs update it.

```bash
wiqd agent provision --env dev
```

Provision validates the package references it is about to upload. DA-only
`agent_skills[].folder` entries require
`wiqd config flags set agent-skills true`; local `worker_agents[].file` entries are rejected in
favor of published `worker_agents[].id` references. WIQD follows the DA file paths declared by
`appPackage/manifest.json` and never assumes a fixed DA filename.

### 5. Package

Build the distributable `.zip` for sideloading or upload.

```bash
wiqd agent package --env dev
```

Package applies the same fail-fast reference checks before fx-core starts. Top-level
`agentSkills[]` Cowork skills and DA-manifest `agent_skills[]` Chat skills remain separate sets;
dual registration is not required. See [`wiqd agent package`](/cli/agent/agent-package/) for the
full contract. Package fails closed when `appPackage/.generated/manifest.json` exists or the active
lifecycle configuration contains `typeSpec/compile`, because the pinned SDK can otherwise replace
the manifest WIQD validated.

### 6. Publish

Submit the package to the org catalog for tenant administrator approval.
Other users can discover it only after approval; submission is not approval.

```bash
wiqd agent publish --env dev
```

Publish applies the same package-reference checks because fx-core builds the
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
wiqd agent ask -q "..."  # send a test prompt
wiqd agent eval --env dev        # run quality evaluations
```

## Side branches

A few commands sit outside the linear pipeline but you'll use them often:

- **`wiqd agent show`** — glanceable summary of what's in a project (local) or a deployed agent (remote).
- **`wiqd agent env`** — manage environment definitions.
- **`wiqd agent share`** — give other users access during development.
- **`wiqd agent delete`** — tear down cloud resources.

## Go deeper

- [Environments](/concepts/environments/) — `local`, `dev`, `staging`, `prod`
- [`wiqd agent create`](/cli/reference/#wiqd-agent-create), [`provision`](/cli/reference/#wiqd-agent-provision), [`package`](/cli/reference/#wiqd-agent-package), [`publish`](/cli/reference/#wiqd-agent-publish)
- [wiqd Core extension](/extensions/provided/core/) — implements most of these phases
- [Eval extension](/extensions/provided/eval/) — quality evaluations on deployed agents
