---
title: Getting Started
---

# Getting Started with Work IQ Dev Tools

Welcome to Work IQ Dev Tools. This section walks you through installing the
WIQD agentic experience or CLI, authenticating, and creating your first
Microsoft 365 Copilot plugin.

## What are Work IQ Dev Tools?

**WIQD is the agentic experience for the end-to-end Microsoft 365 Copilot plugin
lifecycle:** build, improve, preview, and publish. A plugin is the app package
you ship; skills, connectors, and declarative agents are components you compose
into it. A declarative agent supplies a conversational experience when your
plugin needs one, rather than defining the whole product.

## Where to Start

1. **[Installation](/getting-started/installation/)** — Choose marketplace-first agentic setup or the existing installation script.
2. **[Quickstart](/getting-started/quickstart/)** — Create, validate, provision, and share your first plugin.
3. **[Authentication](/getting-started/authentication/)** — Sign in to your Microsoft 365 account.
4. **[Build a Plugin](/getting-started/build-a-plugin/)** — Compose skills, connectors, and an optional declarative agent, then package and publish.
5. **[Cookbooks](/cookbooks/)** — Explore outcome-focused recipes for plugin components.

## Prerequisites

- **GitHub Copilot CLI or Claude Code** for marketplace-first setup
- **Node.js 24+** for the installation-script path
- **A Microsoft 365 account** with access to Copilot
- **An Azure subscription** only when your plugin's backing services require Azure resources

## Choose an installation path

### Option 1: Install the marketplace plugin

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

Start a new host session and begin agentic authoring. This installs WIQD's
coding-assistant plugin, not the Microsoft 365 plugin you will create, and does
not install the `wiqd` CLI.

### Option 2: Use the installation script

Install the CLI and the components managed by the existing installer:

```powershell
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
```

On macOS / Linux:

```bash
curl -fsSL https://aka.ms/wiqd/install.sh | bash
```

:::tip
See [Installation](/getting-started/installation/) for all options.
:::

## Guided Experiences with `--agent wiqd:wiqd`

Work IQ Dev Tools also ship a Copilot CLI guide agent. Once the WIQD marketplace
plugin is installed, drive your plugin lifecycle conversationally with
`--agent wiqd:wiqd`. The guide routes workflows and helps you compose, validate,
improve, and deliver your plugin:

```bash
copilot -i "create a plugin with a triage skill and a declarative agent" --agent wiqd:wiqd
```

Always include `--agent wiqd:wiqd` so Copilot CLI targets the wiqd orchestrator rather than generic behavior.
