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
| `2` | Configuration or infrastructure error (binary missing, version mismatch, not a project, or a required provider definitively reports signed out) |
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
| `--account <email>` | Global account hint; provider-specific account selection is not implemented |
| `--log-level <level>` | Set logging level (choices: "trace", "debug", "info", "warning", "error", "critical", "none") |
| `--log-format <format>` | Set log output format (choices: "json", "text") |
| `-h, --help` | display help for command |

## Command index

**wiqd agent**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd agent`](#wiqd-agent) | wiqd (core) | Build, validate, provision, publish, and monitor declarative agents |
| [`wiqd agent add`](#wiqd-agent-add) | Agents Toolkit / wiqd Core | Augment an existing declarative agent with an action, capability, skill, or auth config. |
| [`wiqd agent add action`](#wiqd-agent-add-action) | Agents Toolkit / wiqd Core | Add an OpenAPI or remote MCP action to a declarative agent. |
| [`wiqd agent add auth`](#wiqd-agent-add-auth) | Agents Toolkit / wiqd Core | Add an auth configuration to a plugin manifest. |
| [`wiqd agent add capability`](#wiqd-agent-add-capability) | wiqd Core | Add a knowledge capability to a declarative agent. |
| [`wiqd agent add skill`](#wiqd-agent-add-skill) | Agents Toolkit / wiqd Core | Add a skill to a declarative agent. |
| [`wiqd agent ask`](#wiqd-agent-ask) | Work IQ | Send a message directly to a declarative agent. |
| [`wiqd agent create`](#wiqd-agent-create) | wiqd Core | Scaffold a new declarative agent project. |
| [`wiqd agent create list`](#wiqd-agent-create-list) | wiqd Core | List available declarative agent templates. |
| [`wiqd agent delete`](#wiqd-agent-delete) | wiqd Core | Delete an agent's cloud resources. Either by env (project-based) or by --title-id (works for any agent you can administer, no local project required). Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`. |
| [`wiqd agent env`](#wiqd-agent-env) | wiqd Core | env |
| [`wiqd agent env add`](#wiqd-agent-env-add) | wiqd Core | Add a new environment, copying from an existing one. |
| [`wiqd agent env list`](#wiqd-agent-env-list) | wiqd Core | List the project's environments. |
| [`wiqd agent env reset`](#wiqd-agent-env-reset) | wiqd Core | Reset (clear) an existing environment file. |
| [`wiqd agent eval`](#wiqd-agent-eval) | Copilot Eval | Run quality evaluations against a deployed declarative agent. |
| [`wiqd agent eval init`](#wiqd-agent-eval-init) | Copilot Eval | Initialize an evaluation prompts.json for a project (drops a fixed seven-item bootstrap for the default declarative-agent template, plus env/.env.<env>.user from your Azure OpenAI / tenant env vars). This is not manifest-aware count-based generation. |
| [`wiqd agent info`](#wiqd-agent-info) | wiqd Core | Show MOS3 launch / acquisition info for a deployed agent. Accepts --agent-id (e.g. P_xxx.declarativeAgent), --title-id, or --manifest-id; emits the raw launch-info JSON. Used by the DevUI portal. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`. |
| [`wiqd agent list`](#wiqd-agent-list) | Work IQ | List declarative agents deployed in the tenant. |
| [`wiqd agent monitor`](#wiqd-agent-monitor) | Work IQ | Query the Insights Agent about a provisioned agent's performance and usage. |
| [`wiqd agent package`](#wiqd-agent-package) | wiqd Core | Package the agent into a deployable .zip. |
| [`wiqd agent provision`](#wiqd-agent-provision) | wiqd Core | Provision a declarative agent to an environment. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`. |
| [`wiqd agent publish`](#wiqd-agent-publish) | wiqd Core | Publish an agent to the org catalog. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`. |
| [`wiqd agent share`](#wiqd-agent-share) | wiqd Core | Share an agent with users or the entire tenant. Requires Microsoft 365 sign-in; use `wiqd auth login`. |
| [`wiqd agent share collaborator`](#wiqd-agent-share-collaborator) | wiqd Core | collaborator |
| [`wiqd agent share collaborator add`](#wiqd-agent-share-collaborator-add) | wiqd Core | Grant a user collaborator access (Entra app + TDP agent). Requires Microsoft 365 sign-in; use `wiqd auth login`. |
| [`wiqd agent share collaborator list`](#wiqd-agent-share-collaborator-list) | wiqd Core | List collaborators. `--all` is currently a compatibility flag with the same behavior as default. Requires Microsoft 365 sign-in; use `wiqd auth login`. |
| [`wiqd agent share remove`](#wiqd-agent-share-remove) | wiqd Core | Remove user or owner access from an agent. Requires Microsoft 365 sign-in; use `wiqd auth login`. |
| [`wiqd agent show`](#wiqd-agent-show) | wiqd (core) | Show a local summary of the agent project (manifest, capabilities, environments). |
| [`wiqd agent validate`](#wiqd-agent-validate) | Manifest Validation & LSP | Validate agent manifests (static or deep). |

**wiqd auth**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd auth`](#wiqd-auth) | wiqd (core) | Manage authentication for wiqd and its extensions |
| [`wiqd auth login`](#wiqd-auth-login) | wiqd (core) | Sign in to wiqd services |
| [`wiqd auth logout`](#wiqd-auth-logout) | wiqd (core) | Sign out of wiqd services |
| [`wiqd auth status`](#wiqd-auth-status) | wiqd (core) | Show authentication status |

**wiqd changelog**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd changelog`](#wiqd-changelog) | wiqd (core) | Show wiqd release changelog |

**wiqd completion**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd completion`](#wiqd-completion) | wiqd (core) | Output a shell tab-completion script (bash, zsh, powershell, fish) |

**wiqd component**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd component`](#wiqd-component) | wiqd (core) | Manage wiqd host integrations (Copilot/Claude plugin, VS Code extension) |
| [`wiqd component plugin`](#wiqd-component-plugin) | wiqd (core) | Manage the wiqd plugin for Copilot CLI or Claude Code |
| [`wiqd component plugin info`](#wiqd-component-plugin-info) | wiqd (core) | Report where the wiqd plugin is installed for the selected CLI |
| [`wiqd component plugin install`](#wiqd-component-plugin-install) | wiqd (core) | Install the wiqd plugin into Copilot CLI or Claude Code |
| [`wiqd component plugin uninstall`](#wiqd-component-plugin-uninstall) | wiqd (core) | Uninstall the wiqd plugin from Copilot CLI or Claude Code |
| [`wiqd component vscode`](#wiqd-component-vscode) | wiqd (core) | Manage the Work IQ VS Code extension |
| [`wiqd component vscode info`](#wiqd-component-vscode-info) | wiqd (core) | Report the VS Code extension install location (stable + insiders) |
| [`wiqd component vscode install`](#wiqd-component-vscode-install) | wiqd (core) | Install the VS Code extension |
| [`wiqd component vscode uninstall`](#wiqd-component-vscode-uninstall) | wiqd (core) | Uninstall the VS Code extension |

**wiqd config**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd config`](#wiqd-config) | wiqd (core) | Manage wiqd configuration settings |
| [`wiqd config flags`](#wiqd-config-flags) | wiqd (core) | Manage wiqd feature flags |
| [`wiqd config flags list`](#wiqd-config-flags-list) | wiqd (core) | List all registered feature flags and their resolved values |
| [`wiqd config flags reset`](#wiqd-config-flags-reset) | wiqd (core) | Clear a persisted feature flag value |
| [`wiqd config flags set`](#wiqd-config-flags-set) | wiqd (core) | Persist a feature flag value |
| [`wiqd config flags show`](#wiqd-config-flags-show) | wiqd (core) | Show definition and resolved value for a single feature flag |
| [`wiqd config reset`](#wiqd-config-reset) | wiqd (core) | Reset all configuration to defaults |
| [`wiqd config set`](#wiqd-config-set) | wiqd (core) | Set configuration values |

**wiqd devui**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd devui`](#wiqd-devui) | wiqd (core) | Launch the local Work IQ DevUI web experience |
| [`wiqd devui ask`](#wiqd-devui-ask) | Work IQ DevUI | Ask an agent and watch the turn run live in the local Work IQ DevUI (deep-linked + auto-sent). |
| [`wiqd devui config`](#wiqd-devui-config) | Work IQ DevUI | Configure DevUI to mint access tokens with your own Entra app registration (skip the workiq CLI). Running start afterwards forces an initial sign-in. |
| [`wiqd devui start`](#wiqd-devui-start) | Work IQ DevUI | Start (or reuse) the local Work IQ DevUI and open it in the browser. |
| [`wiqd devui stop`](#wiqd-devui-stop) | Work IQ DevUI | Stop the running local Work IQ DevUI (release its server and the install-directory lock). |

**wiqd doctor**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd doctor`](#wiqd-doctor) | wiqd (core) | Check environment health (Node.js, extensions, auth) |

**wiqd eula**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd eula`](#wiqd-eula) | wiqd (core) | Accept or report downstream-tool End User License Agreements (EULAs) |
| [`wiqd eula accept`](#wiqd-eula-accept) | wiqd (core) | Accept one tool’s EULA through the human-confirmed acceptance path |
| [`wiqd eula status`](#wiqd-eula-status) | wiqd (core) | Report EULA-acceptance state for all EULA-gated tools |

**wiqd exec**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd exec`](#wiqd-exec) | wiqd (core) | Run an extension-managed CLI (e.g. workiq) with args forwarded verbatim (use `-- <flags>` to forward flags that collide with wiqd globals) |

**wiqd ext**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd ext`](#wiqd-ext) | wiqd (core) | Manage installed wiqd extensions |
| [`wiqd ext add`](#wiqd-ext-add) | wiqd (core) | Activate an installed extension (registers it in ~/.wiqd/extensions.json) |
| [`wiqd ext list`](#wiqd-ext-list) | wiqd (core) | List discovered and registered extensions |
| [`wiqd ext remove`](#wiqd-ext-remove) | wiqd (core) | Deactivate an extension (removes it from ~/.wiqd/extensions.json) |
| [`wiqd ext show`](#wiqd-ext-show) | wiqd (core) | Show extension details |

**wiqd feedback**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd feedback`](#wiqd-feedback) | wiqd (core) | List and submit feedback about wiqd |
| [`wiqd feedback list`](#wiqd-feedback-list) | GitHub | List feedback you submitted through wiqd. |
| [`wiqd feedback submit`](#wiqd-feedback-submit) | GitHub | Submit feedback about wiqd as a GitHub issue. |

**wiqd plugin**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd plugin`](#wiqd-plugin) | wiqd (core) | Build, validate, package, and publish standalone plugins (agent + skills + connector) |
| [`wiqd plugin add`](#wiqd-plugin-add) | wiqd Core | add |
| [`wiqd plugin add agent`](#wiqd-plugin-add-agent) | wiqd Core | Add a declarative agent component to a plugin. |
| [`wiqd plugin add connector`](#wiqd-plugin-add-connector) | wiqd Core | Add a remote MCP agent connector to the plugin manifest. |
| [`wiqd plugin add skill`](#wiqd-plugin-add-skill) | wiqd Core | Scaffold a SKILL.md skill folder and register it in the plugin manifest. |
| [`wiqd plugin create`](#wiqd-plugin-create) | wiqd Core | Scaffold a new, empty standalone plugin project from the built-in blank app template. |
| [`wiqd plugin delete`](#wiqd-plugin-delete) | wiqd Core | Delete a plugin's provisioned cloud resources. Either by env (project-based) or by --title-id (works for any plugin you can administer, no local project required). Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`. |
| [`wiqd plugin export`](#wiqd-plugin-export) | wiqd Core | Export a plugin project to Open Plugin (or Claude/Cursor) format. |
| [`wiqd plugin import`](#wiqd-plugin-import) | wiqd Core | Import an Open Plugin (or Claude/Cursor plugin) as a new plugin project. |
| [`wiqd plugin list`](#wiqd-plugin-list) | wiqd Core | List standalone plugin projects under a directory. |
| [`wiqd plugin package`](#wiqd-plugin-package) | wiqd Core | Package the plugin into a deployable .zip. |
| [`wiqd plugin provision`](#wiqd-plugin-provision) | wiqd Core | Provision a plugin to an environment. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`. |
| [`wiqd plugin share`](#wiqd-plugin-share) | wiqd Core | Share a plugin with users or the entire tenant. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`. |
| [`wiqd plugin show`](#wiqd-plugin-show) | wiqd Core | Show a summary of a standalone plugin project. |
| [`wiqd plugin validate`](#wiqd-plugin-validate) | Manifest Validation & LSP | Validate a standalone plugin project (static MVL; --mode deep validates the built package via fx-core). |

**wiqd update**

| Command | Extension | Description |
| --- | --- | --- |
| [`wiqd update`](#wiqd-update) | wiqd (core) | Update wiqd to the latest version |

## wiqd agent

Build, validate, provision, publish, and monitor declarative agents

**Extension:** wiqd (core)

```bash
wiqd agent <command>
```

**Examples**

```bash
wiqd agent
wiqd agent add
wiqd agent --help
```

### wiqd agent add

Augment an existing declarative agent with an action, capability, skill, or auth config.

**Extension:** Agents Toolkit / wiqd Core

```bash
wiqd agent add <command>
```

**Examples**

```bash
wiqd agent add action
wiqd agent add capability
wiqd agent add skill
wiqd agent add auth
wiqd agent add --help
```

### wiqd agent add action

Add an OpenAPI or remote MCP action to a declarative agent.

**Extension:** Agents Toolkit / wiqd Core

```bash
wiqd agent add action [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--openapi-spec <value>` | OpenAPI spec path or URL |
| `--mcp-server-url <value>` | Remote MCP server HTTPS URL |
| `--mcp-auth-type <value>` | MCP authentication type (choices: "none", "oauth", "oauth-dynamic", "entra-sso", default: "none") |
| `--mcp-client-id <value>` | Static OAuth or Entra SSO client ID |
| `--mcp-client-secret <value>` | Static OAuth client secret |
| `--mcp-scopes <value>` | Space-separated static OAuth scopes |
| `--operations <value>` | OpenAPI operation selectors as METHOD /path (comma-separated; required with --openapi-spec) |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent add action --openapi-spec <path-or-url> --operations <selectors>
wiqd agent add action --mcp-server-url <https-url>   # fx-core only
wiqd agent add action --mcp-server-url <https-url> --mcp-auth-type oauth --mcp-client-id <id> --mcp-client-secret <secret> [--mcp-scopes <scopes>]   # fx-core only
wiqd agent add action --openapi-spec <path-or-url> --operations <selectors> --json
```

### wiqd agent add auth

Add an auth configuration to a plugin manifest.

**Extension:** Agents Toolkit / wiqd Core

```bash
wiqd agent add auth [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--plugin-manifest <value>` | Plugin manifest path |
| `--auth-name <value>` | Auth configuration name |
| `--operations <value>` | Plugin function IDs to secure (comma-separated; inferred when only one is available) |
| `--auth-type <value>` | Authentication type (choices: "bearer-token", "api-key", "oauth", "microsoft-entra", default: "bearer-token") |
| `--api-key-in <value>` | API-key location (used only with --auth-type api-key) (choices: "header", "query", default: "header") |
| `--api-key-name <value>` | API-key header or query parameter name (required for api-key auth) |
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

### wiqd agent add capability

Add a knowledge capability to a declarative agent.

**Extension:** wiqd Core

```bash
wiqd agent add capability [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--knowledge-source <value>` | Capability source (choices: "graph-connector") |
| `--connection-id <value>` | Comma-separated existing Copilot connector connection IDs |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent add capability --knowledge-source graph-connector --connection-id <value>
wiqd agent add capability --knowledge-source graph-connector --connection-id <value> --folder <path>
wiqd agent add capability --knowledge-source graph-connector --connection-id <value> --json
```

### wiqd agent add skill

Add a skill to a declarative agent.

**Extension:** Agents Toolkit / wiqd Core

```bash
wiqd agent add skill [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--name <value>` | Skill name (required unless --from is used) |
| `--description <value>` | Skill description |
| `--from <value>` | Register a skill directory under appPackage, or import an external .zip |
| `--expose-to-copilot` | Expose to mainline M365 Copilot (default: false) |
| `-f, --folder <value>` | Project folder |

**Examples**

```bash
wiqd agent add skill
wiqd agent add skill --name <value> --description <value>
wiqd agent add skill --json
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

### wiqd agent create

Scaffold a new declarative agent project.

**Extension:** wiqd Core

```bash
wiqd agent create [options] <command>
```

**Options**

| Option | Description |
| --- | --- |
| `-t, --template <value>` | Agent template (default: declarative-agent — the only family wiqd supports) (default: "declarative-agent") |
| `-n, --name <value>` | Project name |
| `-o, --output <value>` | Output directory |
| `--mcp-server-url <value>` | Remote MCP server URL; enables MCP scaffold mode |
| `--mcp-auth-type <value>` | MCP authentication mode (choices: "none", "oauth", "entra-sso", default: "none") |
| `--mcp-client-id <value>` | OAuth or Microsoft Entra application client ID |
| `--mcp-client-secret <value>` | Custom OAuth client secret |
| `--mcp-scopes <value>` | Space-separated custom OAuth scopes |

**Examples**

```bash
wiqd agent create
wiqd agent create --template <value> --name <value>
wiqd agent create --help
```

### wiqd agent create list

List available declarative agent templates.

**Extension:** wiqd Core

```bash
wiqd agent create list
```

**Examples**

```bash
wiqd agent create list
wiqd agent create list --json
```

### wiqd agent delete

Delete an agent's cloud resources. Either by env (project-based) or by --title-id (works for any agent you can administer, no local project required). Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`.

**Extension:** wiqd Core

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

### wiqd agent env

env

**Extension:** wiqd Core

```bash
wiqd agent env <command>
```

**Examples**

```bash
wiqd agent env
wiqd agent env add
wiqd agent env list
wiqd agent env reset
wiqd agent env --help
```

### wiqd agent env add

Add a new environment, copying from an existing one.

**Extension:** wiqd Core

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

### wiqd agent env list

List the project's environments.

**Extension:** wiqd Core

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

### wiqd agent env reset

Reset (clear) an existing environment file.

**Extension:** wiqd Core

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
| `-o, --output <value>` | Result file path relative to --path. The eval skill uses a timestamped .html path to produce a scorecard; .json remains available for automation. (default: ".evals/results.json") |
| `--concurrency <value>` | Optional concurrent scenario override (1-5). When omitted, runevals uses its own default. |
| `--threshold <value>` | Minimum pass-rate (0-1) to succeed |
| `--agent-id <value>` | Title ID of a deployed agent to evaluate directly (e.g. T_xxx). When set, the title ID is sourced from this option instead of env/.env.<env>. |
| `--account <value>` | Optional email/UPN forwarded to runevals to select the intended cached MSAL account or prefill interactive sign-in. |
| `--judge-backend <value>` | LLM-as-judge backend forwarded to runevals. 'github-copilot' authenticates via 'gh auth login' (or GITHUB_TOKEN), uses model 'auto' unless GITHUB_COPILOT_JUDGE_MODEL is set, and never activates Foundry routing. Select 'azure'—including when explicitly requesting Azure LLMs as judge—to use local Azure OpenAI or, when AZURE_AI_PROJECT_ENDPOINT + AZURE_AI_MODEL_NAME are set, Microsoft Foundry cloud evaluation. Custom .prompty evaluators always require the Azure path. (choices: "github-copilot", "azure", default: "github-copilot") |
| `--eval-log-level <value>` | runevals log verbosity. Kept distinct from wiqd's global --log-level option and defaults to 'debug' so failures carry enough detail to diagnose without re-running. (choices: "debug", "info", "warning", "error", default: "debug") |

**Examples**

```bash
wiqd agent eval
wiqd agent eval --env <value> --path <value>
wiqd agent eval --help
```

### wiqd agent eval init

Initialize an evaluation prompts.json for a project (drops a fixed seven-item bootstrap for the default declarative-agent template, plus env/.env.<env>.user from your Azure OpenAI / tenant env vars). This is not manifest-aware count-based generation.

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

### wiqd agent info

Show MOS3 launch / acquisition info for a deployed agent. Accepts --agent-id (e.g. P_xxx.declarativeAgent), --title-id, or --manifest-id; emits the raw launch-info JSON. Used by the DevUI portal. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`.

**Extension:** wiqd Core

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

### wiqd agent package

Package the agent into a deployable .zip.

**Extension:** wiqd Core

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

### wiqd agent provision

Provision a declarative agent to an environment. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`.

**Extension:** wiqd Core

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

### wiqd agent publish

Publish an agent to the org catalog. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`.

**Extension:** wiqd Core

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

### wiqd agent share

Share an agent with users or the entire tenant. Requires Microsoft 365 sign-in; use `wiqd auth login`.

**Extension:** wiqd Core

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

### wiqd agent share collaborator

collaborator

**Extension:** wiqd Core

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

Grant a user collaborator access (Entra app + TDP agent). Requires Microsoft 365 sign-in; use `wiqd auth login`.

**Extension:** wiqd Core

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

List collaborators. `--all` is currently a compatibility flag with the same behavior as default. Requires Microsoft 365 sign-in; use `wiqd auth login`.

**Extension:** wiqd Core

```bash
wiqd agent share collaborator list [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--all` | Compatibility flag; currently same behavior as default |
| `--env <value>` | (default: "local") |
| `--path <value>` |  |

**Examples**

```bash
wiqd agent share collaborator list
wiqd agent share collaborator list --env <value> --path <value>
wiqd agent share collaborator list --json
```

### wiqd agent share remove

Remove user or owner access from an agent. Requires Microsoft 365 sign-in; use `wiqd auth login`.

**Extension:** wiqd Core

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
| `--env <env>` | Target environment |
| `--verbose` | Show verbose output |

**Examples**

```bash
wiqd agent show
wiqd agent show --path <path> --env <env>
wiqd agent show --json
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
| `--mode <value>` | Validation mode: static or deep (choices: "static", "deep", default: "static") |
| `--package-file <value>` | Path to a built .zip (deep mode only) |

**Examples**

```bash
wiqd agent validate
wiqd agent validate --path <value> --env <value>
wiqd agent validate --json
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

## wiqd changelog

Show wiqd release changelog

**Extension:** wiqd (core)

```bash
wiqd changelog [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--version <version>` | Show changelog for a specific version (not with --from/--to) |
| `--from <version>` | Range start, exclusive — releases AFTER this one (not with --version) |
| `--to <version>` | Range end, inclusive (not with --version); defaults to latest |
| `--markdown` | Emit canonical markdown (paste-ready; never ANSI-rendered) |
| `--no-markdown-render` | Disable inline markdown rendering in text output (always raw markdown) |

**Examples**

```bash
wiqd changelog                          # the latest release
wiqd changelog --version <version>      # one specific release
wiqd changelog --from <version>         # everything AFTER that release
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
wiqd component plugin info
wiqd component plugin install
wiqd component plugin uninstall
wiqd component plugin --help
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

### wiqd component vscode

Manage the Work IQ VS Code extension

**Extension:** wiqd (core)

```bash
wiqd component vscode <command>
```

**Examples**

```bash
wiqd component vscode
wiqd component vscode info
wiqd component vscode install
wiqd component vscode uninstall
wiqd component vscode --help
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

## wiqd config

Manage wiqd configuration settings

**Extension:** wiqd (core)

```bash
wiqd config <command>
```

**Examples**

```bash
wiqd config
wiqd config flags
wiqd config reset
wiqd config set
wiqd config --help
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

## wiqd devui

Launch the local Work IQ DevUI web experience

**Extension:** wiqd (core)

```bash
wiqd devui <command>
```

**Examples**

```bash
wiqd devui
wiqd devui ask
wiqd devui --help
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
| `--no-window` | Never open a separate console window (Windows); run the server headless |

**Examples**

```bash
wiqd devui start
wiqd devui start --agent <value> --transport direct
wiqd devui start --json
```

### wiqd devui stop

Stop the running local Work IQ DevUI (release its server and the install-directory lock).

**Extension:** Work IQ DevUI

```bash
wiqd devui stop [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--port <value>` | Loopback port the DevUI is served on (default: 7317) |

**Examples**

```bash
wiqd devui stop
wiqd devui stop --port <value>
wiqd devui stop --json
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

## wiqd eula

Accept or report downstream-tool End User License Agreements (EULAs)

**Extension:** wiqd (core)

```bash
wiqd eula <command>
```

**Examples**

```bash
wiqd eula
wiqd eula accept
wiqd eula status
wiqd eula --help
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

## wiqd ext

Manage installed wiqd extensions

**Extension:** wiqd (core)

```bash
wiqd ext <command>
```

**Examples**

```bash
wiqd ext
wiqd ext add
wiqd ext --help
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

## wiqd plugin

Build, validate, package, and publish standalone plugins (agent + skills + connector)

**Extension:** wiqd (core)

```bash
wiqd plugin <command>
```

**Examples**

```bash
wiqd plugin
wiqd plugin add
wiqd plugin --help
```

### wiqd plugin add

add

**Extension:** wiqd Core

```bash
wiqd plugin add <command>
```

**Examples**

```bash
wiqd plugin add
wiqd plugin add agent
wiqd plugin add connector
wiqd plugin add skill
wiqd plugin add --help
```

### wiqd plugin add agent

Add a declarative agent component to a plugin.

**Extension:** wiqd Core

```bash
wiqd plugin add agent [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-f, --folder <value>` | Plugin project folder (defaults to CWD) |

**Examples**

```bash
wiqd plugin add agent
wiqd plugin add agent --folder <value>
wiqd plugin add agent --json
```

### wiqd plugin add connector

Add a remote MCP agent connector to the plugin manifest.

**Extension:** wiqd Core

```bash
wiqd plugin add connector [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-n, --name <value>` | Connector display name |
| `--description <value>` | Connector description |
| `--url <value>` | Remote MCP server https:// URL |
| `--tool-description <value>` | Existing tool-description file, relative to appPackage/ |
| `--auth-type <value>` | Connector authorization type (dcr omits the block, which is how the host enables it) (choices: "none", "oauth", "api-key", "dcr", default: "none") |
| `--auth-reference-id <value>` | Vault reference id for the credential (required for oauth and api-key; not accepted for none or dcr) |
| `-f, --folder <value>` | Plugin project folder (defaults to CWD) |

**Examples**

```bash
wiqd plugin add connector
wiqd plugin add connector --name <value> --description <value>
wiqd plugin add connector --json
```

### wiqd plugin add skill

Scaffold a SKILL.md skill folder and register it in the plugin manifest.

**Extension:** wiqd Core

```bash
wiqd plugin add skill [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-n, --name <value>` | Skill display name |
| `-f, --folder <value>` | Plugin project folder (defaults to CWD) |

**Examples**

```bash
wiqd plugin add skill
wiqd plugin add skill --name <value> --folder <value>
wiqd plugin add skill --json
```

### wiqd plugin create

Scaffold a new, empty standalone plugin project from the built-in blank app template.

**Extension:** wiqd Core

```bash
wiqd plugin create [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-n, --name <value>` | Plugin project name |
| `-o, --output <value>` | Output directory (defaults to CWD) |
| `--force` | Re-scaffold over a non-empty destination, discarding what is there now |

**Examples**

```bash
wiqd plugin create
wiqd plugin create --name <value> --output <value>
wiqd plugin create --json
```

### wiqd plugin delete

Delete a plugin's provisioned cloud resources. Either by env (project-based) or by --title-id (works for any plugin you can administer, no local project required). Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`.

**Extension:** wiqd Core

**Aliases:** `uninstall`

```bash
wiqd plugin delete [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-e, --env <value>` | Environment to delete (ignored when --title-id is set) (default: "local") |
| `--path <value>` | Plugin project path (ignored when --title-id is set) |
| `--title-id <value>` | Title ID of the plugin to delete (e.g. T_xxx or T_xxx.declarativeAgent). When set, deletes via title-id mode and skips project/env checks. |
| `--keep-env-file` | Keep the local env file after deletion (project mode only) |
| `--yes` | Skip confirmation prompt |

**Examples**

```bash
wiqd plugin delete
wiqd plugin delete --env <value> --path <value>
wiqd plugin delete --json
```

### wiqd plugin export

Export a plugin project to Open Plugin (or Claude/Cursor) format.

**Extension:** wiqd Core

```bash
wiqd plugin export [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-p, --path <value>` | Plugin project path (defaults to CWD) |
| `-o, --output <value>` | Output Open Plugin directory (defaults to <path>/export/<format>) |
| `--format <value>` | Target manifest kind (choices: "open-plugin", "claude-plugin", "cursor-plugin", default: "open-plugin") |

**Examples**

```bash
wiqd plugin export
wiqd plugin export --path <value> --output <value>
wiqd plugin export --json
```

### wiqd plugin import

Import an Open Plugin (or Claude/Cursor plugin) as a new plugin project.

**Extension:** wiqd Core

```bash
wiqd plugin import [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-p, --path <value>` | Source Open Plugin directory |
| `-o, --output <value>` | Destination project directory (defaults to ./<plugin-name>) |
| `--privacy-url <value>` | Privacy statement URL (required unless the source carries the round-trip block) |
| `--terms-url <value>` | Terms-of-use URL (required unless the source carries the round-trip block) |
| `--website-url <value>` | Website URL (falls back to plugin.json homepage/author URL) |
| `--app-id <value>` | Teams/M365 app id (UUID) to stamp |
| `--default-auth-type <value>` | Default plugin auth type (default: Auto) (choices: "Auto", "None", "OAuthPluginVault", "ApiKeyPluginVault") |
| `--package-name <value>` | Reverse-DNS package name |

**Examples**

```bash
wiqd plugin import
wiqd plugin import --path <value> --output <value>
wiqd plugin import --json
```

### wiqd plugin list

List standalone plugin projects under a directory.

**Extension:** wiqd Core

```bash
wiqd plugin list [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-n, --name <value>` | Filter by plugin name substring |
| `--top <value>` | Limit the number of results |
| `--root <value>` | Root directory to scan (defaults to CWD) |

**Examples**

```bash
wiqd plugin list
wiqd plugin list --name <value> --top <value>
wiqd plugin list --json
```

### wiqd plugin package

Package the plugin into a deployable .zip.

**Extension:** wiqd Core

```bash
wiqd plugin package [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--env <value>` | Environment to resolve variables from (default: "local") |
| `--output <value>` | Output path for the zip package |
| `--path <value>` | Plugin project path (defaults to CWD) |

**Examples**

```bash
wiqd plugin package
wiqd plugin package --env <value> --output <value>
wiqd plugin package --json
```

### wiqd plugin provision

Provision a plugin to an environment. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`.

**Extension:** wiqd Core

```bash
wiqd plugin provision [options]
```

**Options**

| Option | Description |
| --- | --- |
| `-e, --env <value>` | Target environment (default: "local") |
| `--path <value>` | Plugin project path (defaults to CWD) |

**Examples**

```bash
wiqd plugin provision
wiqd plugin provision --env <value> --path <value>
wiqd plugin provision --json
```

### wiqd plugin share

Share a plugin with users or the entire tenant. Requires Microsoft 365 sign-in; use `wiqd auth login --interactive`.

**Extension:** wiqd Core

```bash
wiqd plugin share [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--scope <value>` | Share scope: 'users' or 'tenant' (choices: "users", "tenant", default: "users") |
| `--email <value>` | Comma-separated email addresses |
| `--env <value>` | Target environment (default: "local") |
| `--path <value>` | Plugin project path (defaults to CWD) |

**Examples**

```bash
wiqd plugin share
wiqd plugin share --scope users --email <value>
wiqd plugin share --json
```

### wiqd plugin show

Show a summary of a standalone plugin project.

**Extension:** wiqd Core

```bash
wiqd plugin show [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--path <value>` | Plugin project path (defaults to CWD) |
| `-n, --name <value>` | Plugin name to locate under CWD (exact match) |

**Examples**

```bash
wiqd plugin show
wiqd plugin show --path <value> --name <value>
wiqd plugin show --json
```

### wiqd plugin validate

Validate a standalone plugin project (static MVL; --mode deep validates the built package via fx-core).

**Extension:** Manifest Validation & LSP

```bash
wiqd plugin validate [options]
```

**Options**

| Option | Description |
| --- | --- |
| `--path <value>` | Plugin project directory (defaults to CWD) |
| `--env <value>` | Target environment (default: "local") |
| `--mode <value>` | Validation mode: static or deep (choices: "static", "deep", default: "static") |
| `--package-file <value>` | Path to a built .zip (deep mode only) |

**Examples**

```bash
wiqd plugin validate
wiqd plugin validate --path <value> --env <value>
wiqd plugin validate --json
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
| `--skip-plugin` | Skip Copilot CLI plugin refresh |

**Examples**

```bash
wiqd update
wiqd update --version <version> --channel <channel>
wiqd update --json
```

<!-- END: command-reference -->

## Feature flags

Feature flags are typed toggles that gate experimental or environment-specific CLI behavior; the host
registry ships empty and flags are contributed by active extensions (for example `devui` from the DevUI
extension). They resolve with strict precedence — **env var > persisted > registry default** — where the
env var name is `WIQD_FLAG_<UPPER_SNAKE_CASE_NAME>` (so `workiq-monitor` is overridden by
`WIQD_FLAG_WORKIQ_MONITOR`). Persisted values live under the `"flags"` key in `~/.wiqd/.wiqd.json` and are
never sent in telemetry. Manage flags with [`wiqd config flags`](#wiqd-config-flags) `list|show|set|reset`.

After successfully setting or clearing `plugin-core-engine`, wiqd silently refreshes an already-installed
plugin so its composed workflow and references match the selected backend. Other flag changes do not
trigger a plugin reinstall. The backend refresh is a no-op when the plugin is not installed. If it fails,
the flag change remains successful and wiqd prints a recovery hint; rerun `wiqd install plugin` manually.

<!-- BEGIN: generated-flag-table -->
| Flag | Type | Default | Stage | Owner | Since | Description |
|---|---|---|---|---|---|---|
| `plugin-core-engine` | `string-enum` | `fxcore` | `internal` | wiqd-core | 0.9.0 | Selects the backend that services the agent lifecycle commands: the ATK subprocess (atk) or the in-process fx-core engine (fxcore). |
| `devui` | `boolean` | `false` | `beta` | microsoft.devui | 0.5.0 | Enables the `wiqd devui` commands (the local Work IQ DevUI web experience). Opt-in while the experience is in preview. |
| `workiq-monitor` | `boolean` | `true` | `beta` | microsoft.workiq | 0.2.2 | Enables the `wiqd agent monitor` command (Insights Agent query) inside the Work IQ extension. On by default; can be set to false to hide the command. `agent ask` and `agent list` are always available. |
<!-- END: generated-flag-table -->

Every registered flag has a corresponding env var of the form `WIQD_FLAG_<UPPER_SNAKE_CASE_NAME>`:

<!-- BEGIN: generated-env-table -->
| Flag | Env var |
|---|---|
| `plugin-core-engine` | `WIQD_FLAG_PLUGIN_CORE_ENGINE` |
| `devui` | `WIQD_FLAG_DEVUI` |
| `workiq-monitor` | `WIQD_FLAG_WORKIQ_MONITOR` |
<!-- END: generated-env-table -->
