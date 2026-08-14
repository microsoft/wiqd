---
title: Quickstart
---

# Quickstart: Create Your First Agent in 5 Minutes

This guide walks you through creating, validating, provisioning, and sharing a declarative agent for Microsoft 365 Copilot.

## Step 1: Install

Install `wiqd` and all dependencies with a single command:

```powershell
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
```

This installs Node.js (if needed), the `wiqd` CLI, ATK, and the VS Code extension.

:::tip
See [Installation](/getting-started/installation/) for all options.
:::

## Step 2: Authenticate

Sign in to your Microsoft 365 account:

```bash
wiqd auth login --interactive
```

Verify your session:

```bash
wiqd auth status
```

## Step 3: Create an Agent

Scaffold a new agent project from a template:

```bash
wiqd agent create --name my-first-agent
```

This creates a new directory `my-first-agent/` with the agent manifest and supporting files.

:::note
Run `wiqd agent create list` to see all available templates.
:::

## Step 4: Validate

Validate the agent manifests to catch errors before deployment:

```bash
wiqd agent validate --path my-first-agent
```

A clean validation returns exit code `0` with no errors.

:::note
Use `--mode deep` for enhanced validation that checks external references and API plugin schemas.
:::

## Step 5: Provision

Deploy the agent to your development environment:

```bash
wiqd agent provision --path my-first-agent
```

This packages and uploads your agent to Microsoft 365.

## Step 6: Share

Share the agent with specific users:

```bash
wiqd agent share --scope users --email colleague@contoso.com --path my-first-agent
```

Or share across the entire tenant:

```bash
wiqd agent share --scope tenant --path my-first-agent
```

## Prefer a Conversational Workflow?

Instead of running each command yourself, you can drive the entire lifecycle through Copilot CLI in interactive mode. The `--agent wiqd:wiqd` flag routes your request to the wiqd orchestrator, which handles skill routing, lifecycle orchestration, and next-step suggestions end-to-end:

```bash
copilot -i "create a new declarative agent" --agent wiqd:wiqd
copilot -i "validate my agent" --agent wiqd:wiqd
copilot -i "deploy my agent locally" --agent wiqd:wiqd
```

:::tip
Always include `--agent wiqd:wiqd` so Copilot CLI targets the wiqd orchestrator rather than falling back to generic behavior.
:::

## What's Next?

- [CLI Reference](/cli/reference/) — Explore the full command set
- [Validation & MVL](/concepts/validation-mvl/) — Learn about validation architecture
- [Environments](/concepts/environments/) — Manage multiple deployment targets
- [VS Code Extension](/concepts/vscode-extension/) — Get real-time validation in your editor
