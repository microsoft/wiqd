---
title: Command reference
description: Reference for every Work IQ Dev Tools CLI command — synopsis, options, and examples for the full command tree.
---

# Command reference

This page lists every `wiqd` command with its synopsis, options, and a few
example invocations. It mirrors the default `wiqd --help` surface — the host
commands plus the bundled extensions that are active out of the box. Each
command notes the extension that contributes it.

:::note
Commands contributed by extensions you add yourself (`wiqd ext add`) and
hidden or experimental commands are not listed here; run `wiqd --help` (or
`wiqd <command> --help`) to see the exact surface in your environment. The
examples show command syntax, not guaranteed-valid argument combinations —
some commands have requirements (such as mutually exclusive options) that are
described in each command's options table.
:::

## Exit codes

Exit codes are not repeated per command. Every `wiqd` command follows the
standard convention:

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | User or upstream error (bad input, tool failure, postcondition failure) |
| `2` | Configuration or infrastructure error (binary missing, version mismatch, not a project) |
| `130` | Cancelled (Ctrl+C) |

See [Exit codes & output](/concepts/exit-codes-output/) for the full
contract.

<!-- BEGIN: command-reference -->

## Global options

These options are accepted by every command and are omitted from the
per-command tables below.

| Option | Description |
| --- | --- |
| `-v, --version` | Output the version number and exit |
| `--json` | Emit machine-readable JSON output (default is a human-readable table) (default: false) |
| `--verbose` | Show verbose output (default: false) |
| `--no-banner` | Suppress the ASCII art banner |
| `--account <email>` | The account email to use for authentication |
| `--log-level <level>` | Set logging level (choices: "trace", "debug", "info", "warning", "error", "critical", "none", default: "warning") |
| `-h, --help` | display help for command |

## Command index

**wiqd config**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd config`](#wiqd-config) | wiqd (core) | Manage wiqd configuration settings |
| [`wiqd config set`](#wiqd-config-set) | wiqd (core) | Set configuration values |
| [`wiqd config reset`](#wiqd-config-reset) | wiqd (core) | Reset all configuration to defaults |
| [`wiqd config flags`](#wiqd-config-flags) | wiqd (core) | Manage wiqd feature flags |
| [`wiqd config flags list`](#wiqd-config-flags-list) | wiqd (core) | List all registered feature flags and their resolved values |
| [`wiqd config flags show`](#wiqd-config-flags-show) | wiqd (core) | Show definition and resolved value for a single feature flag |
| [`wiqd config flags set`](#wiqd-config-flags-set) | wiqd (core) | Persist a feature flag value |
| [`wiqd config flags reset`](#wiqd-config-flags-reset) | wiqd (core) | Clear a persisted feature flag value |

**wiqd auth**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd auth`](#wiqd-auth) | wiqd (core) | Manage authentication for wiqd and its extensions |
| [`wiqd auth login`](#wiqd-auth-login) | wiqd (core) | Sign in to wiqd services |
| [`wiqd auth logout`](#wiqd-auth-logout) | wiqd (core) | Sign out of wiqd services |
| [`wiqd auth status`](#wiqd-auth-status) | wiqd (core) | Show authentication status |

**wiqd update**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd update`](#wiqd-update) | wiqd (core) | Update wiqd to the latest version |

**wiqd changelog**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd changelog`](#wiqd-changelog) | wiqd (core) | Show wiqd release changelog |

**wiqd component**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd component`](#wiqd-component) | wiqd (core) | Manage wiqd host integrations (Copilot/Claude plugin, VS Code extension) |
| [`wiqd component plugin`](#wiqd-component-plugin) | wiqd (core) | Manage the wiqd plugin for Copilot CLI or Claude Code |
| [`wiqd component plugin install`](#wiqd-component-plugin-install) | wiqd (core) | Install the wiqd plugin into Copilot CLI or Claude Code |
| [`wiqd component plugin uninstall`](#wiqd-component-plugin-uninstall) | wiqd (core) | Uninstall the wiqd plugin from Copilot CLI or Claude Code |
| [`wiqd component plugin info`](#wiqd-component-plugin-info) | wiqd (core) | Report where the wiqd plugin is installed for the selected CLI |
| [`wiqd component vscode`](#wiqd-component-vscode) | wiqd (core) | Manage the Work IQ VS Code extension |
| [`wiqd component vscode install`](#wiqd-component-vscode-install) | wiqd (core) | Install the VS Code extension |
| [`wiqd component vscode uninstall`](#wiqd-component-vscode-uninstall) | wiqd (core) | Uninstall the VS Code extension |
| [`wiqd component vscode info`](#wiqd-component-vscode-info) | wiqd (core) | Report the VS Code extension install location (stable + insiders) |

**wiqd doctor**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd doctor`](#wiqd-doctor) | wiqd (core) | Check environment health (Node.js, extensions, auth) |

**wiqd exec**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd exec`](#wiqd-exec) | wiqd (core) | Run an extension-managed CLI (e.g. workiq) with args forwarded verbatim (use `-- <flags>` to forward flags that collide with wiqd globals) |

**wiqd eula**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd eula`](#wiqd-eula) | wiqd (core) | Accept or report downstream-tool End User License Agreements (EULAs) |
| [`wiqd eula status`](#wiqd-eula-status) | wiqd (core) | Report EULA-acceptance state for all EULA-gated tools |
| [`wiqd eula accept`](#wiqd-eula-accept) | wiqd (core) | Accept one tool’s EULA through the human-confirmed acceptance path |

**wiqd ext**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd ext`](#wiqd-ext) | wiqd (core) | Manage installed wiqd extensions |
| [`wiqd ext list`](#wiqd-ext-list) | wiqd (core) | List discovered and registered extensions |
| [`wiqd ext show`](#wiqd-ext-show) | wiqd (core) | Show extension details |
| [`wiqd ext add`](#wiqd-ext-add) | wiqd (core) | Activate an installed extension (registers it in ~/.wiqd/extensions.json) |
| [`wiqd ext remove`](#wiqd-ext-remove) | wiqd (core) | Deactivate an extension (removes it from ~/.wiqd/extensions.json) |

**wiqd completion**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd completion`](#wiqd-completion) | wiqd (core) | Output a shell tab-completion script (bash, zsh, powershell, fish) |

**wiqd agent**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd agent`](#wiqd-agent) | wiqd (core) | Build, validate, provision, publish, and monitor declarative agents |
| [`wiqd agent show`](#wiqd-agent-show) | wiqd (core) | Show a local summary of the agent project (manifest, capabilities, environments). |
| [`wiqd agent create`](#wiqd-agent-create) | Agents Toolkit | Scaffold a new declarative agent project. |
| [`wiqd agent create list`](#wiqd-agent-create-list) | Agents Toolkit | List available declarative agent templates. |
| [`wiqd agent add`](#wiqd-agent-add) | Agents Toolkit | Augment an existing declarative agent with an action, skill, or auth config. |
| [`wiqd agent add action`](#wiqd-agent-add-action) | Agents Toolkit | Add an OpenAPI-spec action to a declarative agent. |
| [`wiqd agent add skill`](#wiqd-agent-add-skill) | Agents Toolkit | Add a skill to a declarative agent. |
| [`wiqd agent add auth`](#wiqd-agent-add-auth) | Agents Toolkit | Add an auth configuration to a plugin manifest. |
| [`wiqd agent provision`](#wiqd-agent-provision) | Agents Toolkit | Provision a declarative agent to an environment. |
| [`wiqd agent package`](#wiqd-agent-package) | Agents Toolkit | Package the agent into a deployable .zip. |
| [`wiqd agent share`](#wiqd-agent-share) | Agents Toolkit | Share an agent with users or the entire tenant. |
| [`wiqd agent share remove`](#wiqd-agent-share-remove) | Agents Toolkit | Remove user or owner access from an agent. |
| [`wiqd agent share collaborator`](#wiqd-agent-share-collaborator) | Agents Toolkit | collaborator |
| [`wiqd agent share collaborator add`](#wiqd-agent-share-collaborator-add) | Agents Toolkit | Grant a user collaborator access (Entra app + TDP agent). |
| [`wiqd agent share collaborator list`](#wiqd-agent-share-collaborator-list) | Agents Toolkit | List the agent's collaborators. |
| [`wiqd agent env`](#wiqd-agent-env) | Agents Toolkit | env |
| [`wiqd agent env list`](#wiqd-agent-env-list) | Agents Toolkit | List the project's environments. |
| [`wiqd agent env add`](#wiqd-agent-env-add) | Agents Toolkit | Add a new environment, copying from an existing one. |
| [`wiqd agent env reset`](#wiqd-agent-env-reset) | Agents Toolkit | Reset (clear) an existing environment file. |
| [`wiqd agent info`](#wiqd-agent-info) | Agents Toolkit | Show MOS3 launch / acquisition info for a deployed agent (proxies `atk launchinfo`). Accepts --agent-id (e.g. P_xxx.declarativeAgent), --title-id, or --manifest-id; emits the raw launchinfo JSON. Used by the DevUI portal. |
| [`wiqd agent delete`](#wiqd-agent-delete) | Agents Toolkit | Delete an agent's cloud resources. Either by env (project-based) or by --title-id (works for any agent you can administer, no local project required). |
| [`wiqd agent publish`](#wiqd-agent-publish) | Agents Toolkit | Publish an agent to the org catalog. |
| [`wiqd agent validate`](#wiqd-agent-validate) | Manifest Validation & LSP | Validate agent manifests (static or deep). |
| [`wiqd agent monitor`](#wiqd-agent-monitor) | Work IQ | Query the Insights Agent about a provisioned agent's performance and usage. |
| [`wiqd agent ask`](#wiqd-agent-ask) | Work IQ | Send a message directly to a declarative agent. |
| [`wiqd agent list`](#wiqd-agent-list) | Work IQ | List declarative agents deployed in the tenant. |
| [`wiqd agent eval`](#wiqd-agent-eval) | Copilot Eval | Run quality evaluations against a deployed declarative agent. |
| [`wiqd agent eval init`](#wiqd-agent-eval-init) | Copilot Eval | Initialize an evaluation prompts.json for a project (drops a starter suite tailored to the default declarative-agent template, plus env/.env.<env>.user from your Azure OpenAI / tenant env vars). |

**wiqd feedback**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd feedback`](#wiqd-feedback) | wiqd (core) | List and submit feedback about wiqd |
| [`wiqd feedback list`](#wiqd-feedback-list) | GitHub | List feedback you submitted through wiqd. |
| [`wiqd feedback submit`](#wiqd-feedback-submit) | GitHub | Submit feedback about wiqd as a GitHub issue. |

**wiqd devui**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd devui`](#wiqd-devui) | wiqd (core) | Launch the local Work IQ DevUI web experience |
| [`wiqd devui start`](#wiqd-devui-start) | Work IQ DevUI | Start (or reuse) the local Work IQ DevUI and open it in the browser. |
| [`wiqd devui ask`](#wiqd-devui-ask) | Work IQ DevUI | Ask an agent and watch the turn run live in the local Work IQ DevUI (deep-linked + auto-sent). |
| [`wiqd devui config`](#wiqd-devui-config) | Work IQ DevUI | Configure DevUI to mint access tokens with your own Entra app registration (skip the workiq CLI). Running start afterwards forces an initial sign-in. |

## wiqd config

Manage wiqd configuration settings

**Extension:** wiqd (core)

```bash
wiqd config <command>
```

**Examples**

```bash
wiqd config
wiqd config set
wiqd config reset
wiqd config flags
wiqd config --help
```

### wiqd config set

Set configuration values

**Extension:** wiqd (core)

```bash
wiqd config set pairs
```

**Arguments**

| Argument | Description |
| --- | --- |
| `pairs` | Key=value pairs to set |

**Examples**

```bash
wiqd config set
wiqd config set [pairs...]
```

### wiqd config reset

Reset all configuration to defaults

**Extension:** wiqd (core)

```bash
wiqd config reset
```

**Examples**

```bash
wiqd config reset
wiqd config reset --json
```

### wiqd config flags

Manage wiqd feature flags

**Extension:** wiqd (core)

```bash
wiqd config flags <command>
```

**Examples**

```bash
wiqd config flags
wiqd config flags list
wiqd config flags --help
```

### wiqd config flags list

List all registered feature flags and their resolved values

**Extension:** wiqd (core)

```bash
wiqd config flags list [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--enabled-only` | Show only boolean flags currently evaluating true (default: false) |

**Examples**

```bash
wiqd config flags list
wiqd config flags list --enabled-only
wiqd config flags list --json
```

### wiqd config flags show

Show definition and resolved value for a single feature flag

**Extension:** wiqd (core)

```bash
wiqd config flags show name
```

**Arguments**

| Argument | Description |
| --- | --- |
| `name` | Flag name (e.g. my-flag) |

**Examples**

```bash
wiqd config flags show <name>
wiqd config flags show <name> --json
```

### wiqd config flags set

Persist a feature flag value

**Extension:** wiqd (core)

```bash
wiqd config flags set name value
```

**Arguments**

| Argument | Description |
| --- | --- |
| `name` | Flag name |
| `value` | Value to persist (validated against the flag type) |

**Examples**

```bash
wiqd config flags set <name> <value>
wiqd config flags set <name> <value> --json
```

### wiqd config flags reset

Clear a persisted feature flag value

**Extension:** wiqd (core)

```bash
wiqd config flags reset name [options]
```

**Arguments**

| Argument | Description |
| --- | --- |
| `name` | Flag name (mutually exclusive with --all) |

**Options**

| Option | Description |
| --- | --- |
| `--all` | Clear all persisted feature flag values (default: false) |

**Examples**

```bash
wiqd config flags reset
wiqd config flags reset --all
wiqd config flags reset [name]
```

## wiqd auth

Manage authentication for wiqd and its extensions

**Extension:** wiqd (core)

```bash
wiqd auth <command>
```

**Examples**

```bash
wiqd auth
wiqd auth login
wiqd auth logout
wiqd auth status
wiqd auth --help
```

### wiqd auth login

Sign in to wiqd services

**Extension:** wiqd (core)

```bash
wiqd auth login [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--interactive` | Force interactive login |

**Examples**

```bash
wiqd auth login
wiqd auth login --interactive
wiqd auth login --json
```

### wiqd auth logout

Sign out of wiqd services

**Extension:** wiqd (core)

```bash
wiqd auth logout
```

**Examples**

```bash
wiqd auth logout
wiqd auth logout --json
```

### wiqd auth status

Show authentication status

**Extension:** wiqd (core)

```bash
wiqd auth status
```

**Examples**

```bash
wiqd auth status
wiqd auth status --json
```

## wiqd update

Update wiqd to the latest version

**Extension:** wiqd (core)

```bash
wiqd update [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--version <version>` | Install specific version |
| `--check` | Check for updates without installing |
| `--channel <channel>` | npm dist-tag channel |
| `--force` | Deprecated: update always reinstalls; kept for compatibility |
| `--dry-run` | Show what would be done without doing it |
| `--skip-extension` | Skip VS Code extension update |

**Examples**

```bash
wiqd update
wiqd update --version <version> --channel <channel>
wiqd update --json
```

## wiqd changelog

Show wiqd release changelog

**Extension:** wiqd (core)

```bash
wiqd changelog [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--version <version>` | Show changelog for a specific version |
| `--from <version>` | Start version for range |
| `--to <version>` | End version for range |
| `--markdown` | Emit canonical markdown (paste-ready; never ANSI-rendered) |
| `--no-markdown-render` | Disable inline markdown rendering in text output (always raw markdown) |

**Examples**

```bash
wiqd changelog
wiqd changelog --version <version> --from <version>
wiqd changelog --json
```

## wiqd component

Manage wiqd host integrations (Copilot/Claude plugin, VS Code extension)

**Extension:** wiqd (core)

```bash
wiqd component <command>
```

**Examples**

```bash
wiqd component
wiqd component plugin
wiqd component vscode
wiqd component --help
```

### wiqd component plugin

Manage the wiqd plugin for Copilot CLI or Claude Code

**Extension:** wiqd (core)

```bash
wiqd component plugin <command>
```

**Examples**

```bash
wiqd component plugin
wiqd component plugin install
wiqd component plugin uninstall
wiqd component plugin info
wiqd component plugin --help
```

### wiqd component plugin install

Install the wiqd plugin into Copilot CLI or Claude Code

**Extension:** wiqd (core)

```bash
wiqd component plugin install [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--cli <cli>` | Which CLI to target (choices: "copilot", "claude", default: "copilot") |
| `--force` | Uninstall and re-install even if already present |

**Examples**

```bash
wiqd component plugin install
wiqd component plugin install --cli copilot --force
wiqd component plugin install --json
```

### wiqd component plugin uninstall

Uninstall the wiqd plugin from Copilot CLI or Claude Code

**Extension:** wiqd (core)

```bash
wiqd component plugin uninstall [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--cli <cli>` | Which CLI to target (choices: "copilot", "claude", default: "copilot") |

**Examples**

```bash
wiqd component plugin uninstall
wiqd component plugin uninstall --cli copilot
wiqd component plugin uninstall --json
```

### wiqd component plugin info

Report where the wiqd plugin is installed for the selected CLI

**Extension:** wiqd (core)

```bash
wiqd component plugin info [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--cli <cli>` | Which CLI to target (choices: "copilot", "claude", default: "copilot") |

**Examples**

```bash
wiqd component plugin info
wiqd component plugin info --cli copilot
wiqd component plugin info --json
```

### wiqd component vscode

Manage the Work IQ VS Code extension

**Extension:** wiqd (core)

```bash
wiqd component vscode <command>
```

**Examples**

```bash
wiqd component vscode
wiqd component vscode install
wiqd component vscode uninstall
wiqd component vscode info
wiqd component vscode --help
```

### wiqd component vscode install

Install the VS Code extension

**Extension:** wiqd (core)

```bash
wiqd component vscode install [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--insiders` | Target VS Code Insiders instead of stable |
| `--force` | Reinstall even if already present |

**Examples**

```bash
wiqd component vscode install
wiqd component vscode install --insiders --force
wiqd component vscode install --json
```

### wiqd component vscode uninstall

Uninstall the VS Code extension

**Extension:** wiqd (core)

```bash
wiqd component vscode uninstall [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--insiders` | Target VS Code Insiders instead of stable |

**Examples**

```bash
wiqd component vscode uninstall
wiqd component vscode uninstall --insiders
wiqd component vscode uninstall --json
```

### wiqd component vscode info

Report the VS Code extension install location (stable + insiders)

**Extension:** wiqd (core)

```bash
wiqd component vscode info
```

**Examples**

```bash
wiqd component vscode info
wiqd component vscode info --json
```

## wiqd doctor

Check environment health (Node.js, extensions, auth)

**Extension:** wiqd (core)

```bash
wiqd doctor
```

**Examples**

```bash
wiqd doctor
wiqd doctor --json
```

## wiqd exec

Run an extension-managed CLI (e.g. workiq) with args forwarded verbatim (use `-- <flags>` to forward flags that collide with wiqd globals)

**Extension:** wiqd (core)

```bash
wiqd exec cli args
```

**Arguments**

| Argument | Description |
| --- | --- |
| `cli` | Name of the managed CLI to run (e.g. workiq) |
| `args` | Arguments forwarded to the CLI unchanged |

**Examples**

```bash
wiqd exec <cli> --help
wiqd exec <cli> <subcommand> [args...]
wiqd exec <cli> <subcommand> -- --json   # forward a flag that collides with a wiqd global
```

## wiqd eula

Accept or report downstream-tool End User License Agreements (EULAs)

**Extension:** wiqd (core)

```bash
wiqd eula <command>
```

**Examples**

```bash
wiqd eula
wiqd eula status
wiqd eula accept
wiqd eula --help
```

### wiqd eula status

Report EULA-acceptance state for all EULA-gated tools

**Extension:** wiqd (core)

```bash
wiqd eula status
```

**Examples**

```bash
wiqd eula status
wiqd eula status --json
```

### wiqd eula accept

Accept one tool’s EULA through the human-confirmed acceptance path

**Extension:** wiqd (core)

```bash
wiqd eula accept tool [options]
```

**Arguments**

| Argument | Description |
| --- | --- |
| `tool` | The EULA-gated tool to accept (run `wiqd eula status` to list them) |

**Options**

| Option | Description |
| --- | --- |
| `--consent <phrase>` | A non-TTY phrase matching the complete affirmative template for the named EULA, exact URL, and current version when surfaced. No default or additional language; TTY use, CI, and --mock are refused. |

**Examples**

```bash
wiqd eula accept <tool>
wiqd eula accept <tool> --consent <phrase>
wiqd eula accept <tool> --json
```

## wiqd ext

Manage installed wiqd extensions

**Extension:** wiqd (core)

```bash
wiqd ext <command>
```

**Examples**

```bash
wiqd ext
wiqd ext list
wiqd ext --help
```

### wiqd ext list

List discovered and registered extensions

**Extension:** wiqd (core)

```bash
wiqd ext list
```

**Examples**

```bash
wiqd ext list
wiqd ext list --json
```

### wiqd ext show

Show extension details

**Extension:** wiqd (core)

```bash
wiqd ext show id
```

**Arguments**

| Argument | Description |
| --- | --- |
| `id` | Extension ID |

**Examples**

```bash
wiqd ext show <id>
wiqd ext show <id> --json
```

### wiqd ext add

Activate an installed extension (registers it in ~/.wiqd/extensions.json)

**Extension:** wiqd (core)

```bash
wiqd ext add id
```

**Arguments**

| Argument | Description |
| --- | --- |
| `id` | Extension manifest ID or npm package name |

**Examples**

```bash
wiqd ext add <id>
wiqd ext add <id> --json
```

### wiqd ext remove

Deactivate an extension (removes it from ~/.wiqd/extensions.json)

**Extension:** wiqd (core)

```bash
wiqd ext remove id
```

**Arguments**

| Argument | Description |
| --- | --- |
| `id` | Extension manifest ID or npm package name |

**Examples**

```bash
wiqd ext remove <id>
wiqd ext remove <id> --json
```

## wiqd completion

Output a shell tab-completion script (bash, zsh, powershell, fish)

**Extension:** wiqd (core)

```bash
wiqd completion shell
```

**Arguments**

| Argument | Description |
| --- | --- |
| `shell` | Target shell: bash, zsh, powershell, or fish |

**Examples**

```bash
wiqd completion <shell>
wiqd completion <shell> --json
```

## wiqd agent

Build, validate, provision, publish, and monitor declarative agents

**Extension:** wiqd (core)

```bash
wiqd agent <command>
```

**Examples**

```bash
wiqd agent
wiqd agent show
wiqd agent --help
```

### wiqd agent show

Show a local summary of the agent project (manifest, capabilities, environments).

**Extension:** wiqd (core)

```bash
wiqd agent show [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--path <path>` | Agent project directory |
| `--env <env>` | Target environment (default: "local") |
| `--name <name>` | Agent name filter |
| `--id <id>` | Agent ID filter |
| `--verbose` | Show verbose output |

**Examples**

```bash
wiqd agent show
wiqd agent show --path <path> --env <env>
wiqd agent show --json
```

### wiqd agent create

Scaffold a new declarative agent project.

**Extension:** Agents Toolkit

```bash
wiqd agent create [options] <command>
```

**Options**

| Option | Description |
| --- | --- |
| `-t, --template <value>` | Agent template (default: declarative-agent — the only family wiqd supports) (default: "declarative-agent") |
| `-n, --name <value>` | Project name |
| `-o, --output <value>` | Output directory |

**Examples**

```bash
wiqd agent create
wiqd agent create --template <value> --name <value>
wiqd agent create --help
```

### wiqd agent create list

List available declarative agent templates.

**Extension:** Agents Toolkit

```bash
wiqd agent create list
```

**Examples**

```bash
wiqd agent create list
wiqd agent create list --json
```

### wiqd agent add

Augment an existing declarative agent with an action, skill, or auth config.

**Extension:** Agents Toolkit

```bash
wiqd agent add <command>
```

**Examples**

```bash
wiqd agent add
wiqd agent add action
wiqd agent add skill
wiqd agent add auth
wiqd agent add --help
```

### wiqd agent add action

Add an OpenAPI-spec action to a declarative agent.

**Extension:** Agents Toolkit

```bash
wiqd agent add action [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--openapi-spec <value>` | OpenAPI spec path or URL |
| `--operations <value>` | Operation IDs (comma-separated) |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent add action
wiqd agent add action --openapi-spec <value> --operations <value>
wiqd agent add action --json
```

### wiqd agent add skill

Add a skill to a declarative agent.

**Extension:** Agents Toolkit

```bash
wiqd agent add skill [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--name <value>` | Skill name (required unless --from is used) |
| `--description <value>` | Skill description |
| `--from <value>` | Import from existing skill directory or .zip |
| `--expose-to-copilot` | Expose to mainline M365 Copilot (default: false) |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent add skill
wiqd agent add skill --name <value> --description <value>
wiqd agent add skill --json
```

### wiqd agent add auth

Add an auth configuration to a plugin manifest.

**Extension:** Agents Toolkit

```bash
wiqd agent add auth [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--plugin-manifest <value>` | Plugin manifest path |
| `--auth-name <value>` | Auth configuration name |
| `--auth-type <value>` | Auth type |
| `--authorization-url <value>` | OAuth authorization URL |
| `--token-url <value>` | OAuth token URL |
| `--scope <value>` | OAuth scope |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent add auth
wiqd agent add auth --plugin-manifest <value> --auth-name <value>
wiqd agent add auth --json
```

### wiqd agent provision

Provision a declarative agent to an environment.

**Extension:** Agents Toolkit

```bash
wiqd agent provision [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-e, --env <value>` | Target environment (default: "local") |
| `--path <value>` | Project path (defaults to CWD) |

**Examples**

```bash
wiqd agent provision
wiqd agent provision --env <value> --path <value>
wiqd agent provision --json
```

### wiqd agent package

Package the agent into a deployable .zip.

**Extension:** Agents Toolkit

```bash
wiqd agent package [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--env <value>` | Environment to resolve variables from (default: "local") |
| `--output <value>` | Output path for the zip package |
| `--path <value>` | Project path (defaults to CWD) |

**Examples**

```bash
wiqd agent package
wiqd agent package --env <value> --output <value>
wiqd agent package --json
```

### wiqd agent share

Share an agent with users or the entire tenant.

**Extension:** Agents Toolkit

```bash
wiqd agent share [options] <command>
```

**Options**

| Option | Description |
| --- | --- |
| `--scope <value>` | Share scope: 'users' or 'tenant' (default: "users") |
| `--email <value>` | Comma-separated email addresses |
| `--env <value>` | Target environment (default: "local") |
| `--path <value>` | Project path |

**Examples**

```bash
wiqd agent share
wiqd agent share --scope <value> --email <value>
wiqd agent share --help
```

### wiqd agent share remove

Remove user or owner access from an agent.

**Extension:** Agents Toolkit

```bash
wiqd agent share remove [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--users <value>` | Comma-separated emails to revoke user access |
| `--owners <value>` | Comma-separated emails to revoke owner access |
| `--env <value>` | (default: "local") |
| `--path <value>` |  |

**Examples**

```bash
wiqd agent share remove
wiqd agent share remove --users <value> --owners <value>
wiqd agent share remove --json
```

### wiqd agent share collaborator

collaborator

**Extension:** Agents Toolkit

```bash
wiqd agent share collaborator <command>
```

**Examples**

```bash
wiqd agent share collaborator
wiqd agent share collaborator add
wiqd agent share collaborator list
wiqd agent share collaborator --help
```

### wiqd agent share collaborator add

Grant a user collaborator access (Entra app + TDP agent).

**Extension:** Agents Toolkit

```bash
wiqd agent share collaborator add [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--email <value>` | Collaborator email |
| `--env <value>` | (default: "local") |
| `--path <value>` |  |

**Examples**

```bash
wiqd agent share collaborator add
wiqd agent share collaborator add --email <value> --env <value>
wiqd agent share collaborator add --json
```

### wiqd agent share collaborator list

List the agent's collaborators.

**Extension:** Agents Toolkit

```bash
wiqd agent share collaborator list [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--all` | Show all collaborators |
| `--env <value>` | (default: "local") |
| `--path <value>` |  |

**Examples**

```bash
wiqd agent share collaborator list
wiqd agent share collaborator list --env <value> --path <value>
wiqd agent share collaborator list --json
```

### wiqd agent env

env

**Extension:** Agents Toolkit

```bash
wiqd agent env <command>
```

**Examples**

```bash
wiqd agent env
wiqd agent env list
wiqd agent env add
wiqd agent env reset
wiqd agent env --help
```

### wiqd agent env list

List the project's environments.

**Extension:** Agents Toolkit

```bash
wiqd agent env list [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent env list
wiqd agent env list --folder <value>
wiqd agent env list --json
```

### wiqd agent env add

Add a new environment, copying from an existing one.

**Extension:** Agents Toolkit

```bash
wiqd agent env add [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--name <value>` | New environment name |
| `--from <value>` | Source environment to copy from (default: "local") |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent env add
wiqd agent env add --name <value> --from <value>
wiqd agent env add --json
```

### wiqd agent env reset

Reset (clear) an existing environment file.

**Extension:** Agents Toolkit

```bash
wiqd agent env reset [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--env <value>` | Environment to reset |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent env reset
wiqd agent env reset --env <value> --folder <value>
wiqd agent env reset --json
```

### wiqd agent info

Show MOS3 launch / acquisition info for a deployed agent (proxies `atk launchinfo`). Accepts --agent-id (e.g. P_xxx.declarativeAgent), --title-id, or --manifest-id; emits the raw launchinfo JSON. Used by the DevUI portal.

**Extension:** Agents Toolkit

```bash
wiqd agent info [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--agent-id <value>` | Full agent id (e.g. P_xxx.declarativeAgent); the title id is derived from it. |
| `--title-id <value>` | Title ID of the agent (e.g. P_xxx). |
| `--manifest-id <value>` | Manifest ID of the agent (GUID). |

**Examples**

```bash
wiqd agent info
wiqd agent info --agent-id <value> --title-id <value>
wiqd agent info --json
```

### wiqd agent delete

Delete an agent's cloud resources. Either by env (project-based) or by --title-id (works for any agent you can administer, no local project required).

**Extension:** Agents Toolkit

**Aliases:** `uninstall`

```bash
wiqd agent delete [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--env <value>` | Environment to delete (ignored when --title-id is set) (default: "local") |
| `--path <value>` | Project path (ignored when --title-id is set) |
| `--title-id <value>` | Title ID of the agent to delete (e.g. T_xxx or T_xxx.declarativeAgent). When set, deletes via title-id mode and skips project/env checks. |
| `--keep-env-file` | Keep the local env file after deletion (project mode only) |
| `--yes` | Skip confirmation prompt |

**Examples**

```bash
wiqd agent delete
wiqd agent delete --env <value> --path <value>
wiqd agent delete --json
```

### wiqd agent publish

Publish an agent to the org catalog.

**Extension:** Agents Toolkit

```bash
wiqd agent publish [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--env <value>` | Environment to publish (default: "local") |
| `--path <value>` | Project path |
| `--manifest <value>` | Manifest file path |
| `--dry-run` | Run the validation pipeline and report readiness without submitting (default: false) |
| `--no-runtime` | Skip Phase 3 (agent response sampling) and Phase 4 (browser) in dry-run mode |
| `--no-network` | Skip Phase 2 (URL reachability) in dry-run mode |
| `--browser` | Opt in to Phase 4 headless-browser checks (requires Playwright; bundled tabs only) (default: false) |
| `--prompts <value>` | Path to a YAML file overriding the 5 canonical Phase 3 prompts |
| `--artifacts <value>` | Restrict report artifacts (choices: "md", "html", "json", "all", default: "all") |

**Examples**

```bash
wiqd agent publish
wiqd agent publish --env <value> --path <value>
wiqd agent publish --json
```

### wiqd agent validate

Validate agent manifests (static or deep).

**Extension:** Manifest Validation & LSP

```bash
wiqd agent validate [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--path <value>` | Agent project directory |
| `--env <value>` | Target environment (default: "local") |
| `--mode <value>` | Validation mode: static or deep (default: "static") |
| `--package-file <value>` | Path to a built .zip (deep mode only) |

**Examples**

```bash
wiqd agent validate
wiqd agent validate --path <value> --env <value>
wiqd agent validate --json
```

### wiqd agent monitor

Query the Insights Agent about a provisioned agent's performance and usage.

**Extension:** Work IQ

```bash
wiqd agent monitor [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-q, --query <value>` | Natural language query |
| `--env <value>` | Target environment (default: "local") |
| `--path <value>` | Project path (or run standalone) |

**Examples**

```bash
wiqd agent monitor
wiqd agent monitor --query <value> --env <value>
wiqd agent monitor --json
```

### wiqd agent ask

Send a message directly to a declarative agent.

**Extension:** Work IQ

```bash
wiqd agent ask [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-q, --query <value>` | Message to send to the agent |
| `--agent-id <value>` | Agent ID |
| `--agent-name <value>` | Agent name |
| `--env <value>` | Target environment (default: "local") |
| `--path <value>` | Project path |
| `--devui` | Proxy the ask through the local Work IQ DevUI (A2A) so the call is captured and inspectable there; falls back to a direct ask if DevUI isn't running. |

**Examples**

```bash
wiqd agent ask
wiqd agent ask --query <value> --agent-id <value>
wiqd agent ask --json
```

### wiqd agent list

List declarative agents deployed in the tenant.

**Extension:** Work IQ

```bash
wiqd agent list [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--name <value>` | Filter by name (substring) |
| `--id <value>` | Filter by ID (substring) |
| `--top <value>` | Maximum number of results |

**Examples**

```bash
wiqd agent list
wiqd agent list --name <value> --id <value>
wiqd agent list --json
```

### wiqd agent eval

Run quality evaluations against a deployed declarative agent.

**Extension:** Copilot Eval

```bash
wiqd agent eval [options] <command>
```

**Options**

| Option | Description |
| --- | --- |
| `--env <value>` | Target environment (default: "local") |
| `--path <value>` | Project path (defaults to CWD) |
| `-c, --config <value>` | Path to eval prompts file (runevals format) (default: "evals/prompts.json") |
| `--concurrency <value>` | Concurrent scenario runs (1-5) (default: 5) |
| `--threshold <value>` | Minimum pass-rate (0-1) to succeed |
| `--agent-id <value>` | Title ID of a deployed agent to evaluate directly (e.g. T_xxx). When set, the title ID is sourced from this option instead of env/.env.<env>. |

**Examples**

```bash
wiqd agent eval
wiqd agent eval --env <value> --path <value>
wiqd agent eval --help
```

### wiqd agent eval init

Initialize an evaluation prompts.json for a project (drops a starter suite tailored to the default declarative-agent template, plus env/.env.<env>.user from your Azure OpenAI / tenant env vars).

**Extension:** Copilot Eval

```bash
wiqd agent eval init [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--path <value>` | Project path (defaults to CWD) |
| `--env <value>` | Target environment (controls env/.env.<env>.user filename) (default: "local") |
| `--output <value>` | Output prompts file (runevals auto-discovers evals/prompts.json) (default: "evals/prompts.json") |

**Examples**

```bash
wiqd agent eval init
wiqd agent eval init --path <value> --env <value>
wiqd agent eval init --json
```

## wiqd feedback

List and submit feedback about wiqd

**Extension:** wiqd (core)

```bash
wiqd feedback <command>
```

**Examples**

```bash
wiqd feedback
wiqd feedback list
wiqd feedback submit
wiqd feedback --help
```

### wiqd feedback list

List feedback you submitted through wiqd.

**Extension:** GitHub

```bash
wiqd feedback list [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-n, --top <value>` | Number of items to show |
| `--status <value>` | Filter by status (open, closed, all) |

**Examples**

```bash
wiqd feedback list
wiqd feedback list --top <value> --status <value>
wiqd feedback list --json
```

### wiqd feedback submit

Submit feedback about wiqd as a GitHub issue.

**Extension:** GitHub

```bash
wiqd feedback submit [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--type <value>` | Feedback type (bug, feature, improvement, question, docs, performance). Security issues: see SECURITY.md instead. |
| `--title <value>` | Feedback title |
| `--description <value>` | Feedback description |
| `--sentiment <value>` | Feedback sentiment (positive, negative) |
| `--no-context` | Omit auto-collected environment context |
| `--dry-run` | Show what would be submitted |

**Examples**

```bash
wiqd feedback submit
wiqd feedback submit --type <value> --title <value>
wiqd feedback submit --json
```

## wiqd devui

Launch the local Work IQ DevUI web experience

**Extension:** wiqd (core)

```bash
wiqd devui <command>
```

**Examples**

```bash
wiqd devui
wiqd devui start
wiqd devui ask
wiqd devui config
wiqd devui --help
```

### wiqd devui start

Start (or reuse) the local Work IQ DevUI and open it in the browser.

**Extension:** Work IQ DevUI

```bash
wiqd devui start [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--agent <value>` | Agent id or name to preselect (deep-link) |
| `--transport <value>` | Connection transport: direct (A2A cloud) \| cli (choices: "direct", "cli", default: "direct") |
| `--port <value>` | Loopback port to serve DevUI on (default: 7317) |
| `-q, --query <value>` | Prompt to prefill in the GUI |
| `--no-send` | With --query, prefill the composer without auto-sending |
| `--no-open` | Do not open a browser; print the URL instead |

**Examples**

```bash
wiqd devui start
wiqd devui start --agent <value> --transport direct
wiqd devui start --json
```

### wiqd devui ask

Ask an agent and watch the turn run live in the local Work IQ DevUI (deep-linked + auto-sent).

**Extension:** Work IQ DevUI

```bash
wiqd devui ask [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-q, --query <value>` | Prompt to send to the agent |
| `--agent <value>` | Agent id or name to target (deep-link) |
| `--transport <value>` | Connection transport: direct (A2A cloud) \| cli (choices: "direct", "cli", default: "direct") |
| `--port <value>` | Loopback port to serve DevUI on (default: 7317) |
| `--no-open` | Do not open a browser; print the URL instead |

**Examples**

```bash
wiqd devui ask
wiqd devui ask --query <value> --agent <value>
wiqd devui ask --json
```

### wiqd devui config

Configure DevUI to mint access tokens with your own Entra app registration (skip the workiq CLI). Running start afterwards forces an initial sign-in.

**Extension:** Work IQ DevUI

```bash
wiqd devui config [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--client-id <value>` | Your Entra public-client app id used to mint the WorkIQ access token |
| `--tenant <value>` | Tenant id or domain to sign in against (default: organizations) |
| `--clear` | Clear the client id and fall back to the workiq CLI |

**Examples**

```bash
wiqd devui config
wiqd devui config --client-id <value> --tenant <value>
wiqd devui config --json
```

<!-- END: command-reference -->

## Feature flags

Feature flags are typed toggles that gate experimental or environment-specific CLI behavior; the host
registry ships empty and flags are contributed by active extensions (for example `devui` from the DevUI
extension). They resolve with strict precedence — **env var > persisted > registry default** — where the
env var name is `WIQD_FLAG_<UPPER_SNAKE_CASE_NAME>` (so `workiq-monitor` is overridden by
`WIQD_FLAG_WORKIQ_MONITOR`). Persisted values live under the `"flags"` key in `~/.wiqd/.wiqd.json` and are
never sent in telemetry. Manage flags with [`wiqd config flags`](#wiqd-config-flags) `list|show|set|reset`.

<!-- BEGIN: generated-flag-table -->
| Flag | Type | Default | Stage | Owner | Since | Description |
|---|---|---|---|---|---|---|
| `devui` | `boolean` | `false` | `beta` | microsoft.devui | 0.5.0 | Enables the `wiqd devui` commands (the local Work IQ DevUI web experience). Opt-in while the experience is in preview. |
| `workiq-monitor` | `boolean` | `true` | `beta` | microsoft.workiq | 0.2.2 | Enables the `wiqd agent monitor` command (Insights Agent query) inside the Work IQ extension. On by default; can be set to false to hide the command. `agent ask` and `agent list` are always available. |
<!-- END: generated-flag-table -->

Every registered flag has a corresponding env var of the form `WIQD_FLAG_<UPPER_SNAKE_CASE_NAME>`:

<!-- BEGIN: generated-env-table -->
| Flag | Env var |
|---|---|
| `devui` | `WIQD_FLAG_DEVUI` |
| `workiq-monitor` | `WIQD_FLAG_WORKIQ_MONITOR` |
<!-- END: generated-env-table -->
