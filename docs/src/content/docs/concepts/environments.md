---
title: Environments
description: How Work IQ Dev Tools use local, dev, staging, and prod environments
---

# Environments

An **environment** in Work IQ Dev Tools is a named slot that holds the configuration and cloud resources for one instance of your plugin. The same project source can be provisioned into multiple environments, each with its own M365 app registration, tenant, and configuration values. Existing agent-focused projects use the same lifecycle concept.

By default, environments live in `env/.env.<name>` files inside your project.
`m365agents.yml` can select a different project-contained `environmentFolderPath`.
Work IQ Dev Tools name environments based on
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
definitions with `wiqd plugin add environment --name <name>`.

## How environments enter every command

Plugin lifecycle commands accept `--env <name>`. Use the same explicit
environment when provisioning, packaging, validating source or packages, sharing, and
publishing. Defaults and supported options remain command-specific.

The documentation uses **`dev` as its standard example environment** and
passes `--env dev` explicitly. This does not change CLI defaults: commands
that currently default to `local` still do so when the option is omitted.

```bash
wiqd plugin provision --env dev
wiqd plugin package --env dev
wiqd plugin validate --mode package --env dev --package-file "<zip>"
wiqd plugin publish --env dev
```

For lifecycle operations, the selected environment determines which `.env.<name>`
file Work IQ Dev Tools read and which provisioned identity they use. Validation's
`--env` supplies source context; it does not select a ZIP or authenticate a package
upload against the lifecycle environment's tenant.

## The first provision creates the slot

When you run `wiqd plugin provision --env dev` for the first time, Work IQ Dev
Tools register the plugin and write the resulting IDs into `.env.dev` in the
configured environment folder. Provision before package or share, which depend
on that file. Re-provisioning uses the existing environment identity. Never
commit credentials or assume provisioning commits files to Git.

## Listing and inspecting

Use `wiqd plugin show` to inspect a plugin project. The following commands
provide agent-focused views for existing agent projects:

- `wiqd plugin list environments` — show every environment defined in the project.
- `wiqd plugin show --env dev` — view the agent's identity and provisioned resources for one environment.
- `wiqd plugin show` (no `--env`) — show all of them at once.

## When you don't need environments

`wiqd plugin validate --mode source` reads saved source using only the selected environment context
(`local` by default). Use the same path/environment before packaging or provisioning. Package
validation checks captured ZIP bytes; `--env` does not choose or rebuild that ZIP.
`provision`, `package`, `publish`, `eval`, `monitor`, `share` and `delete` need the intended slot.

`wiqd plugin validate --mode source` checks the declarative-agent source surface
offline without provisioning; use the same explicit project/environment context.
Bare `wiqd plugin validate` defaults to package mode and uploads an existing ZIP.
For package or Marketplace, pass `--package-file "<exact.zip>"` to select the
intended artifact. Explicit ZIP-only input requires no source project. Otherwise
the selected project must pass structural recognition and contain exactly one
nonrecursive ZIP in `appPackage/build/`; missing or ambiguous ZIPs fail.
`--env` never selects or rebuilds a ZIP. Agent evaluation targets a deployed
declarative-agent component, not all capabilities in a plugin.

## Go deeper

- [Build a Plugin](/getting-started/build-a-plugin/) — where environments fit into plugin delivery
- [Agent component lifecycle](/concepts/agent-lifecycle/) — existing agent-project workflows
- [`wiqd plugin list environments`](/cli/reference/#wiqd-plugin-list-environments) — list environments; use the sibling add/reset commands to mutate them
- [`wiqd plugin provision`](/cli/reference/#wiqd-plugin-provision), [`wiqd plugin publish`](/cli/reference/#wiqd-plugin-publish)
- [wiqd Core extension](/extensions/provided/core/) — the upstream that defines the `.env.*` file format
