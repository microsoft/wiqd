# Changelog

## [0.14.0] — 2026-09-04

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- manage isolated Work IQ and eval CLIs

### Fixes

- use canonical install recovery commands

## [0.13.1] — 2026-09-01

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Fixes

- harden failure isolation and unavailable-command fallback
- correct oauth/register binding and let add connector declare auth
- accept Copilot local marketplace installs

## [0.13.0] — 2026-08-28

> **Public preview.** wiqd is in preview; commands, output, and packaging may change before general availability.

### Features

- The `wiqd plugin` lifecycle — `create`, `provision`, `share`, and `delete` — now runs inside wiqd itself instead of shelling out to a separate toolkit, so it starts faster and surfaces failures directly. These commands now ask for Microsoft 365 sign-in rather than a separate toolkit sign-in; use `wiqd auth login --interactive`.
- The built-in agent backend now covers the full lifecycle command surface, so `wiqd agent` and `wiqd plugin` behave consistently whether a command runs inside wiqd or through the Microsoft 365 Agents Toolkit. `wiqd doctor` reports the backend's health alongside its other environment checks.
- Extensions can declare MCP servers in their manifest, and wiqd aggregates them into the composed plugin so they load automatically when your host CLI installs it — no per-server registration and no separate plugin install. `wiqd ext show` lists the servers an extension contributes.
- `wiqd agent show` now runs through wiqd's built-in agent backend, so it works without the Microsoft 365 Agents Toolkit installed. Choose the environment to inspect with `--env`.
- Extensions can contribute Copilot skills, which wiqd composes into the plugin so they reach the host CLI without a separate install.
- Telemetry from the built-in agent backend now flows through wiqd's own consent-aware pipeline, so it honors your telemetry setting and is redacted for personal data and secrets like every other wiqd event.
- Shipped agent-authoring guidance now covers attaching Graph connectors, embedding agent skills, and adding MCP actions with `wiqd` commands, and documents which MCP authentication modes are supported. `wiqd agent add action` now requires explicit `METHOD /path` operation selectors.
- Extension manifests can declare `transformFailureNonFatal`, so a failed post-invocation transform degrades the render instead of failing a write command whose upstream work already succeeded; the `--json` envelope carries `transformFailed` so a consumer can tell that apart from having nothing to report. `@microsoft/wiqd-extension-sdk` adds a `./digest` export with `sha256File`, `sha256Fd`, and `readAndDigestFile` for size-capped SHA-256 hashing of a file or an already-open descriptor.
- `wiqd agent eval` adds `--judge-backend` and `--log-level`. The default `github-copilot` judge runs evaluations with no Azure setup, while `--judge-backend azure` opts into Azure OpenAI for GPT-5.x and o-series models and for custom `.prompty` evaluators. New reference material documents which evaluators work under each backend.
- default lifecycle to wiqd core

### Fixes

- When `wiqd update` fails, it now reports the real cause — a permission problem, a network failure, or an npm error — instead of generic installer boilerplate, and keeps the actionable recovery steps alongside it. The sanitized root cause appears in both the readable output and the `--json` envelope.
- `wiqd agent add auth --auth-type` now accepts an explicit set of values — `bearer-token` (the default), `api-key`, `oauth`, and the new `microsoft-entra` — and rejects anything else up front instead of failing partway through. `microsoft-entra` needs only `--scope`; it does not ask for authorization or token URLs.
- A command whose write already succeeded no longer reports failure when an optional display-only transform fails afterwards, so a formatting error can no longer make completed work look like it needs retrying.
- Commands are listed alphabetically in `wiqd --help` and in the command list shown after a parse error, so a command is easier to find.
- `wiqd auth login --interactive` now fails immediately with a clear message when it is not attached to a real terminal, instead of hanging with no visible prompt. It exits 2 with the stable JSON error code `AUTH_INTERACTIVE_REQUIRES_TTY`. The default non-interactive `wiqd auth login` is unchanged and still works headlessly in CI.
- Mocked runs of the plugin lifecycle now mirror what the real commands do, so offline previews and demos reflect actual behavior.
- report measured versions during CLI updates

### Performance

- Running `wiqd` with no arguments now lists the same commands as `wiqd --help`, and help renders about four times faster.

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
