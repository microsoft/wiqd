# Agent Information & Management

**Telemetry:** `--skill wiqd` on every ordinary `wiqd` command.

Inspect agents, manage environments, open test URLs, and delete provisioned agents.

## Agent Show

```bash
wiqd agent show [--path <dir>] [--env <name>] [--verbose] [--json] --skill wiqd
```

Display agent configuration from the local project: name, description, capabilities, environments, and provisioning state. Does NOT modify any project files.

| Flag            | Description                                                       | Default |
| --------------- | ----------------------------------------------------------------- | ------- |
| `--path`        | Agent project directory                                           | `./`    |
| `--env`         | Target environment                                                | —       |
| `-v, --verbose` | Show extended details                                             | `false` |
| `--json`        | Emit machine-readable JSON output (default: human-readable table) | `false` |

## Environment Management

### List Environments

```bash
wiqd agent env list [--json] --skill wiqd
```

Lists all configured environments by reading `env/.env.*` files. Shows which environments have been provisioned (have `M365_TITLE_ID`). Does NOT modify any env files.

### Add Environment

```bash
wiqd agent env add --env <name> [--from <source>] --skill wiqd
```

Creates a new environment file `env/.env.<name>` from a template. Does NOT overwrite existing env files.

### Reset Environment

```bash
wiqd agent env reset --env <name> --skill wiqd
```

Resets an environment file to the template defaults.

**After add/reset:** suggest running `wiqd agent provision --env <name>`.

## Open Test URL

```bash
wiqd agent open [--env <name>] [--path <dir>] [--print] --skill wiqd
```

Opens the M365 Copilot deep link for the provisioned agent in the default browser.

| Flag      | Description                                   | Default |
| --------- | --------------------------------------------- | ------- |
| `--env`   | Target environment                            | `local` |
| `--path`  | Agent project directory                       | `./`    |
| `--print` | Print the URL to stdout instead of opening it | `false` |

Use `--print` for CI / headless contexts where no browser is available.

**If not provisioned** (no env file or no `M365_TITLE_ID`): reports that the agent is not provisioned and suggests running `wiqd agent provision` first.

## Delete / Uninstall Agent

```bash
# Preferred name (uninstall); `delete` is an equivalent, non-breaking alias
wiqd agent uninstall [--env <name>] [--path <dir>] [--title-id <T_xxx>] [--yes] [--keep-env-file] [--interactive] [--json] --skill wiqd
```

**⚠️ Destructive and irreversible.** Destroys cloud resources (Entra app, Teams app, bot framework). Does NOT delete local source files.

| Flag              | Description                                                                                  | Default |
| ----------------- | -------------------------------------------------------------------------------------------- | ------- |
| `--title-id`      | Title ID of the agent to delete (`T_xxx` or `T_xxx.declarativeAgent`); enables title-id mode | —       |
| `--env`           | Target environment (ignored when `--title-id` is set)                                        | `local` |
| `--path`          | Agent project directory (ignored when `--title-id` is set)                                   | `./`    |
| `--yes`           | Skip confirmation                                                                            | `false` |
| `--keep-env-file` | Preserve `env/.env.<name>` for reference (env/project mode only)                             | `false` |
| `--interactive`   | Run in interactive mode                                                                      | `false` |

- `uninstall` and `delete` are the same command. Prefer `uninstall` when speaking to the user; `delete` keeps working for back-compat.
- Always warn the user and ask for confirmation for the exact target before deleting.
  Agent command execution is non-interactive, so only after the user confirms,
  run the same command with `--yes`. Never include `--yes` before confirmation.
- `--keep-env-file` preserves the env file with app IDs for future re-provisioning (env/project mode only).
- Deleting one environment does not affect other environments.

**Title-ID mode — project-less teardown.** With `--title-id`, the command deletes the agent **by its Title ID alone**: it skips the project/env preflight, works **WITHOUT a project folder** (run it from any directory), and removes no local files. Both `T_xxx` and `T_xxx.declarativeAgent` are accepted. This is the canonical way to clean up orphaned agents that have no checked-out project:

```bash
wiqd agent list --id T_ --skill wiqd            # find the Title ID
wiqd agent uninstall --title-id T_xxxxxxxx --skill wiqd
```

**🚫 Never bypass wiqd.** To tear down an agent, you MUST use `wiqd agent uninstall --title-id <id>` (or `wiqd agent delete --title-id <id>`). Do NOT shell out to `atk uninstall` or the Teams Admin Center / Azure portal — wiqd owns the confirmation prompt, mode selection, error mapping, and env-file cleanup.

## List Deployed Agents

```bash
wiqd agent list [--name <filter>] [--id <filter>] [--top <n>] [--json] --skill wiqd
```

Lists agents deployed in the tenant. Does NOT require an ATK project folder — works from any directory.

| Flag     | Description                            | Default |
| -------- | -------------------------------------- | ------- |
| `--name` | Filter by agent name (substring match) | —       |
| `--id`   | Filter by agent ID                     | —       |
| `--top`  | Maximum number of results              | `10`    |
| `--json` | Emit JSON output                       | `false` |

`--name` and `--id` combine with AND logic. After listing, mention the filtering options so users know they can narrow results.

`--json` is wiqd's **own** output flag — it controls whether wiqd prints a human-readable table or a structured JSON envelope; `wiqd agent list --json` always produces structured output. Always use `wiqd agent list` rather than any underlying platform CLI: wiqd is the only command that yields the parsed, filterable, structured result.

## Diagnostic Commands

### Version

```bash
wiqd --version
wiqd -v
```

Prints the installed wiqd version string (semver). The ASCII banner is shown on stderr.

### Doctor

```bash
wiqd doctor [--json] --skill wiqd
```

Comprehensive environment health check. Verifies host dependencies, auth states, extensions, and runs extension-declared health checks. Purely diagnostic — never modifies state.

Reports: wiqd version, Node.js, auth (MSAL), plugin, extensions, and per-extension health checks. Each failing check includes an actionable remediation hint.

**Exit codes:** 0 = all critical checks pass, 1 = any critical check fails.

### Extensions

For extension inventory and capabilities, see `references/extensions.md`. Quick commands:

```bash
wiqd ext list [--json] --skill wiqd       # List all extensions
wiqd ext show <id> [--json] --skill wiqd  # Show extension details + capabilities
```

## Preflight

All env/open/delete commands require a lifecycle file (`m365agents.yml`,
`m365agents.local.yml`, `teamsapp.yml`, or `teamsapp.local.yml`, matched
case-insensitively) + `appPackage/manifest.json`.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
