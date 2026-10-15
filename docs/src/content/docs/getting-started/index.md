---
title: Getting Started
---

# Getting Started with Work IQ Dev Tools

Welcome to Work IQ Dev Tools. This section walks you through installing the
WIQD agentic experience or CLI, authenticating, and creating your first
Microsoft 365 Copilot declarative agent.

## What are Work IQ Dev Tools?

Work IQ Dev Tools provide agentic workflows and a developer CLI for building,
validating, and publishing Microsoft 365 Copilot declarative agents.

## Where to Start

1. **[Installation](/getting-started/installation/)** — Choose marketplace-first agentic setup or the existing installation script.
2. **[Quickstart](/getting-started/quickstart/)** — Create your first agent in 5 minutes.
3. **[Authentication](/getting-started/authentication/)** — Sign in to your Microsoft 365 account.
4. **[Cookbooks](/cookbooks/)** — Build useful agents with end-to-end, outcome-focused recipes.

## Prerequisites

- **GitHub Copilot CLI or Claude Code** for marketplace-first setup
- **Node.js 24+** for the installation-script path
- **A Microsoft 365 account** with access to Copilot
- **An Azure subscription** (for provisioning agents)

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

Start a new host session and begin agentic authoring. This path does not install
the `wiqd` CLI.

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

Work IQ Dev Tools also ship a Copilot CLI agent. Once installed, you can drive the agent lifecycle conversationally in interactive mode by passing `--agent wiqd:wiqd`, which routes your request to the wiqd orchestrator for skill routing, lifecycle orchestration, and next-step suggestions:

```bash
copilot -i "create a new declarative agent" --agent wiqd:wiqd
```

Always include `--agent wiqd:wiqd` so Copilot CLI targets the wiqd orchestrator rather than generic behavior.
