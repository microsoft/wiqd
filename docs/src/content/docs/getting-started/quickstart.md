---
title: Quickstart
description: Create your first Microsoft 365 Copilot plugin with WIQD, compose its capabilities, and validate, provision, package, and share it.
---

# Quickstart: Create Your First Plugin

WIQD is the agentic experience for the end-to-end Microsoft 365 Copilot plugin
lifecycle. Start with a **plugin**, the app package you ship, then compose
**skills**, **connectors**, and an optional **declarative agent** into it.
This walkthrough builds a plugin with a skill and a declarative-agent component.

Lifecycle examples explicitly use `--env dev` throughout. This is the
documentation's example environment, not a change to CLI defaults; keep the
same environment across validation, provisioning, packaging, sharing, and publishing.

:::caution[Alpha]
The `wiqd plugin` commands are enabled by default, but their interface is still
alpha and may change without notice.
:::

## Step 1: Choose an installation path

### Path 1: Marketplace-first agentic setup

Install WIQD's coding-assistant plugin for your preferred host. This is the
guide that helps you build Microsoft 365 plugins, not the app package you ship.

**GitHub Copilot CLI:**

```text
copilot plugin install wiqd@awesome-copilot
```

Or use the WIQD marketplace:

```text
copilot plugin marketplace add microsoft/wiqd
copilot plugin install wiqd@wiqd
```

**Claude Code:**

```text
claude plugin marketplace add microsoft/wiqd
claude plugin install wiqd@wiqd
```

Start a new host session. In GitHub Copilot CLI:

```bash
copilot -i "create a plugin called Triage Helper with a triage skill and a declarative agent" --agent wiqd:wiqd
```

In Claude Code, ask for the same outcome in your new session.

Marketplace installation does not install the `wiqd` CLI. You can begin
file-based authoring immediately; install the CLI separately before running
the validation and tenant lifecycle commands below.

### Path 2: Installation script

Install the CLI and optional editor/host integrations:

```powershell
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
```

On macOS / Linux:

```bash
curl -fsSL https://aka.ms/wiqd/install.sh | bash
```

See [Installation](/getting-started/installation/) for prerequisites, options,
and troubleshooting.

## Step 2: Create and compose your plugin

For a direct CLI walkthrough:

```bash
wiqd plugin create --name my-first-plugin
cd my-first-plugin
wiqd plugin add skill --name "Triage Issues"
wiqd plugin add agent
```

The project contains `wiqd.plugin.json`, `m365agents.yml`, and an
`appPackage/` directory. The app manifest registers the skill and declarative
agent as components of the same plugin.

Edit the skill's `SKILL.md` and the agent's instructions to describe the behavior
you want. The agent component is optional: a plugin can contain only skills or
connectors. See [Build a Plugin](/getting-started/build-a-plugin/) to add an
MCP connector or reuse a catalog connector.

If WIQD already created the project conversationally, continue in that project
instead of scaffolding a second one.

## Step 3: Validate and improve

```bash
wiqd plugin validate --env dev
```

Static validation is offline and checks the declarative-agent surface and its
references. It does not establish that root skills, connectors, or the entire
app package are valid. Ask WIQD to explain findings and help you repair them,
then validate again.

## Step 4: Authenticate and provision

Sign in to the Microsoft 365 tenant where you will preview the plugin:

```bash
wiqd auth login --interactive
wiqd auth status
wiqd plugin provision --env dev
```

Provisioning registers the plugin and writes the selected environment file.
Run it before packaging or sharing, which depend on that environment.

## Step 5: Package and validate deeply

```bash
wiqd plugin package --env dev
wiqd plugin validate --mode deep --env dev
```

Packaging produces the distributable `.zip`. Deep validation checks the built
app package through Microsoft 365's validation service; it requires that ZIP
and is not a substitute for trying the plugin's behavior.

Inspect the returned findings before continuing. In JSON automation, also check
`data.valid`: deep validation can complete with exit code `0` while reporting
`data.valid: false`. See [Validation & MVL](/concepts/validation-mvl/).

## Step 6: Share for preview, then publish

Grant a teammate access:

```bash
wiqd plugin share --scope users --email colleague@contoso.com --env dev
```

Try the plugin in its target Microsoft 365 experience and iterate on its
components. When it is ready for organization-wide discovery, submit it to
your tenant catalog:

```bash
wiqd plugin publish --env dev
```

Submission is not approval: a tenant administrator must approve the plugin
before users can discover it in the catalog. Sharing and catalog submission
are separate operations. Public-store submission and certification remain
Partner Center steps, not `wiqd plugin publish`.

## Continue conversationally

With the WIQD marketplace plugin installed, you can ask for the same lifecycle
steps instead of typing each CLI command:

```bash
copilot -i "validate my plugin in dev and help me fix the findings" --agent wiqd:wiqd
copilot -i "provision my plugin in dev, package it, and share it with my teammate using dev" --agent wiqd:wiqd
```

If your plugin includes a declarative agent, use agent-specific evaluation
guidance for that deployed component. Do not interpret an agent evaluation as
validation of every plugin capability.

## What's Next?

- [Build a Plugin](/getting-started/build-a-plugin/) - Full composition, import/export, and publishing walkthrough
- [What is a plugin?](/concepts/plugins/) - The package and its components
- [Plugin authoring reference](/getting-started/plugin-reference/) - Manifests, skills, connectors, and validation codes
- [CLI Reference](/cli/reference/#wiqd-plugin) - Script the same plugin lifecycle
- [Declarative agents](/concepts/declarative-agents/) - Add or maintain a conversational component; existing `wiqd agent` projects remain supported
