# Changelog

## [0.12.2] — 2026-08-14

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

_Maintenance release — no user-facing changes to the CLI, skills, or references._

## [0.12.1] — 2026-08-13

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

_Maintenance release — no user-facing changes to the CLI, skills, or references._

## [0.12.0] — 2026-08-11

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- Share an agent through a guided flow that helps you pick the target — one or more people, a mail-enabled security group, or your whole tenant — and inspects the project first so you confirm what will be shared before it happens

### Fixes

- `wiqd plugin import` and `wiqd plugin export` now refuse a plugin whose declarative agent references a file outside the plugin's own package, and stop on a corrupt source manifest instead of quietly importing without the agent. `wiqd plugin create` now tells a non-empty destination apart from an unreadable one and reports the real inspection error
- With the `devui` preview flag enabled (`wiqd config flags set devui true`), `wiqd devui start` now runs the server in its own visible console window on interactive, non-CI Windows runs unless `--no-window` is used; on macOS and Linux it still runs in the background. The new `wiqd devui stop` command shuts down servers started by this release cleanly. The server no longer holds a lock on its own install directory, so upgrades and uninstalls are not blocked. When upgrading from an earlier release, if a DevUI server is already running and the installer reports a locked file, end the `node` process listening on port 7317 or reboot, then retry. If its preferred trace port is busy, DevUI now listens on a free port and prints the exact `workiq config set otlpEndpoint=...` command needed to point tracing at it
- Validate agents against declarative agent manifest v1.7 and v1.8, and offer both when completing the `$schema` field. Validation selects its rules from the manifest's `version` field — set `version` to pin a schema version; `$schema` drives editor completion and hover only

### Changes

- Agent authoring guidance now covers the `EmailActions` and `MeetingActions` capabilities, which require declarative agent manifest v1.8 or later, and no longer pins a "latest" manifest version anywhere — it explains how to look up the current published version instead, so the guidance stays correct as new versions ship

## [0.11.0] — 2026-08-03

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- Build a plugin end to end with the `wiqd plugin` commands, including OpenPlugin import and export
- Sign in to Microsoft 365 directly through `wiqd auth login`, so authentication no longer needs a separate CLI installed

### Fixes

- Report upstream tool timeouts clearly, with recovery guidance that matches the actual failure
- Accept an agent-relayed EULA consent without naming a version, and accept more natural URL phrasing
- Recognize an agent project even when its marker file name differs in casing
- Honor the EULA you accept during install, so the installer finishes setting up the Copilot plugin
- Refresh the Copilot and Claude plugin during `wiqd update`, so skills no longer go stale after an upgrade
- Fix 26 defects across the `wiqd plugin` lifecycle, so `plugin create` no longer overwrites an existing provisioned project
- Route a standalone plugin request to the plugin commands instead of agent scaffolding, and restore the skill description so Copilot reliably picks up wiqd in a conversation

## [0.10.0] — 2026-07-30

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Fixes

- Fail fast with sign-in guidance before tenant-backed commands

## [0.9.0] — 2026-07-29

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- Check for prerequisite CLIs and offer a consent-gated install
- Notify you when a newer release is available, show what changed after an update, and browse version ranges with `wiqd changelog --from/--to`

### Fixes

- Seed extensions on first run, and repair them from the doctor, when a post-install step is blocked
- Install the evaluation and Work IQ extensions as first-class dependencies
- Scope the doctor's antivirus exclusion advice to the project instead of a whole drive
- Distinguish active from installed extensions in `wiqd ext list`, with clearer version reporting
- Report upstream and precondition failures with actionable diagnostics
- Describe the `wiqd agent add` command group properly in help output
- apply --log-level to the shared logger before command actions

## [0.8.0-rc.1] — 2026-07-22

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- Scaffold declarative agent projects from built-in templates
- Add OpenAPI actions, skills, and authentication to an agent from the CLI
- Validate agent manifests offline and check publish readiness before you ship
- Provision an agent to a named environment and get its Copilot deep link
- Package, share, inspect, publish, and delete agents across their full lifecycle
- Initialize and run scored agent evaluations with concurrency and threshold controls
- Ask, list, and monitor deployed agents from the terminal with structured output
- Launch a local browser DevUI to build, debug, and evaluate agents on your machine
- Drive the full build, improve, preview, and publish lifecycle from one guided Copilot skill
- Create and edit agents safely with project checks and read-before-write safeguards
- Generate and analyze evaluation suites with approval gates that protect the quality bar
- Guide partners from a validated package through listing, certification, and go-live
- Sign in, sign out, and inspect authentication across active extensions
- Check for and install updates by version or channel, with dry-run support
- Read installed release notes by version in text, JSON, or Markdown
- Activate extensions and install Copilot, Claude, and editor integrations
- Submit and browse product feedback from the CLI, with optional context
- Emit versioned JSON success and error envelopes for scriptable use
- Generate shell tab completion for Bash, Zsh, PowerShell, and Fish
- Ship schemas and guides for extension manifests, OpenAPI, MCP, and OAuth
