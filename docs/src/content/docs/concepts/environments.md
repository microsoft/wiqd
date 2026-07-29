---
title: Environments
description: How Work IQ Dev Tools use local, dev, staging, and prod environments
---

# Environments

An **environment** in Work IQ Dev Tools is a named slot that holds the configuration and cloud resources for one instance of your agent. The same project source can be provisioned into multiple environments, each with its own M365 app registration, tenant, and configuration values.

Environments live in `env/.env.<name>` files inside your project. Work IQ Dev Tools, like ATK underneath, name them based on the file's suffix: `env/.env.local` becomes the `local` environment, `env/.env.dev` becomes `dev`, and so on.

## The conventional names

| Name | When to use it |
|------|----------------|
| `local` | Your laptop. Provisions to your own dev tenant. Recreated freely. |
| `dev` | Shared dev tenant for the whole team. |
| `staging` | Pre-production tenant for final validation. |
| `prod` | Production tenant — the one your real users hit. |

These are conventions, not enforced names. You can add `qa`, `customer-acme`, or any other slot that fits your workflow with `wiqd agent env add --name <name>`.

## How environments enter every command

Most agent commands accept `--env <name>`. The default is whatever the command's spec says (usually `local` for development, but `wiqd agent show` reads them all when you omit `--env`).

```bash
wiqd agent provision --env local
wiqd agent eval --env staging
wiqd agent publish --env prod
```

The selected environment determines which `.env.<name>` file Work IQ Dev Tools read, which tenant the upstream tool authenticates against, and which app registration gets updated.

## The first provision creates the slot

When you run `wiqd agent provision --env dev` for the first time, Work IQ Dev Tools (via the Agents Toolkit) create the M365 app registration, write the resulting IDs back into `env/.env.dev`, and commit the slot. Re-running the command updates the existing app instead of creating a new one. Use `wiqd agent env reset --env dev` if you want to wipe a slot and start fresh.

## Listing and inspecting

- `wiqd agent env list` — show every environment defined in the project.
- `wiqd agent show --env staging` — view the agent's identity and provisioned resources for one environment.
- `wiqd agent show` (no `--env`) — show all of them at once.

## When you don't need environments

The command that doesn't care about environments at all is `wiqd agent validate` (it reads source files only). Everything else — `provision`, `package`, `publish`, `eval`, `monitor`, `share`, `delete` — needs to know which slot you mean.

## Go deeper

- [Agent lifecycle](/concepts/agent-lifecycle/) — where environments fit into the bigger flow
- [`wiqd agent env`](/cli/reference/#wiqd-agent-env) — manage environments
- [`wiqd agent provision`](/cli/reference/#wiqd-agent-provision), [`wiqd agent publish`](/cli/reference/#wiqd-agent-publish)
- [Agents Toolkit extension](/extensions/provided/atk/) — the upstream that defines the `.env.*` file format
