---
title: Getting Started
---

# Getting Started with Work IQ Dev Tools

Welcome to Work IQ Dev Tools (the `wiqd` CLI). This section walks you through installation, authentication, and creating your first M365 Copilot declarative agent.

## What are Work IQ Dev Tools?

Work IQ Dev Tools provide a developer CLI for building, validating, and publishing M365 Copilot declarative agents. They deliver a streamlined experience for the full agent lifecycle — from scaffolding a new project to sharing it with your organization.

## Where to Start

1. **[Installation](/getting-started/installation/)** — Install `wiqd` with a single command.
2. **[Quickstart](/getting-started/quickstart/)** — Create your first agent in 5 minutes.
3. **[Authentication](/getting-started/authentication/)** — Sign in to your Microsoft 365 account.

## Prerequisites

- **Node.js 24+** (auto-installed via fnm on Windows, or nvm/Homebrew on macOS/Linux)
- **A Microsoft 365 account** with access to Copilot
- **An Azure subscription** (for provisioning agents)

## Quick Install

Install `wiqd` and all dependencies with a single command:

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
