---
title: Environments
description: How Work IQ Dev Tools use local, dev, staging, and prod environments
---

# Environments

An **environment** in Work IQ Dev Tools is a named slot that holds the configuration and cloud resources for one instance of your plugin. The same project source can be provisioned into multiple environments, each with its own M365 app registration, tenant, and configuration values. Existing agent-focused projects use the same lifecycle concept.

By default, environments live in `env/.env.<name>` files inside your project.
`m365agents.yml` can select a different project-contained `environmentFolderPath`.
Work IQ Dev Tools and the core lifecycle backend name environments based on
the file's suffix: `.env.local` becomes `local`, `.env.dev` becomes `dev`, and so on.

## The conventional names

| Name | When to use it |
|------|----------------|
| `local` | Your laptop. Provisions to your own dev tenant. Recreated freely. |
| `dev` | Shared dev tenant for the whole team. |
| `staging` | Pre-production tenant for final validation. |
| `prod` | Production tenant — the one your real users hit. |

These are conventions, not enforced names. Choose a portable filename segment
such as `qa` or `customer-acme`, not a path. Existing agent projects can manage
definitions with `wiqd agent env add --name <name>`.

## How environments enter every command

Plugin lifecycle commands accept `--env <name>`. Use the same explicit
environment when provisioning, packaging, validating deeply, sharing, and
publishing. Defaults and supported options remain command-specific.

The documentation uses **`dev` as its standard example environment** and
passes `--env dev` explicitly. This does not change CLI defaults: commands
that currently default to `local` still do so when the option is omitted.

```bash
wiqd plugin provision --env dev
wiqd plugin package --env dev
wiqd plugin validate --mode deep --env dev
wiqd plugin publish --env dev
```

The selected environment determines which `.env.<name>` file Work IQ Dev Tools read, which tenant the upstream tool authenticates against, and which app registration gets updated.

## The first provision creates the slot

When you run `wiqd plugin provision --env dev` for the first time, Work IQ Dev
Tools register the plugin and write the resulting IDs into `.env.dev` in the
configured environment folder. Provision before package or share, which depend
on that file. Re-provisioning uses the existing environment identity. Never
commit credentials or assume provisioning commits files to Git.

## Listing and inspecting

Use `wiqd plugin show` to inspect a plugin project. The following commands
provide agent-focused views for existing agent projects:

- `wiqd agent env list` — show every environment defined in the project.
- `wiqd agent show --env dev` — view the agent's identity and provisioned resources for one environment.
- `wiqd agent show` (no `--env`) — show all of them at once.

## When you don't need environments

Static `wiqd plugin validate` checks the declarative-agent source surface
offline without provisioning. Deep validation uses the selected environment's
built package. Agent evaluation targets a deployed declarative-agent component,
not all capabilities in a plugin.

## Go deeper

- [Build a Plugin](/getting-started/build-a-plugin/) — where environments fit into plugin delivery
- [Agent component lifecycle](/concepts/agent-lifecycle/) — existing agent-project workflows
- [`wiqd agent env`](/cli/reference/#wiqd-agent-env) — manage environments
- [`wiqd plugin provision`](/cli/reference/#wiqd-plugin-provision), [`wiqd plugin publish`](/cli/reference/#wiqd-plugin-publish)
- [wiqd Core extension](/extensions/provided/core/) — the upstream that defines the `.env.*` file format
