# Agent Show

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Show agent project details locally or look up a deployed agent remotely.

## Local mode (default — reads project files, no network)

```bash
wiqd agent show [--path <dir>] [--env <name>] [--verbose] [--json] --skill wiqd
```

## Remote mode (queries platform by name or ID)

```bash
wiqd agent show --json --name "<name>" --skill wiqd
wiqd agent show --json --id "<id>" --skill wiqd
```

## Options

| Flag            | Description                                                   |
| --------------- | ------------------------------------------------------------- |
| `--path`        | Path to agent project root (local mode)                       |
| `--env`         | Show details for a specific environment only (local mode)     |
| `--name`        | Agent display name for remote lookup                          |
| `--id`          | Agent ID for remote lookup (takes precedence over `--name`)   |
| `-v, --verbose` | Extended details (full instructions local, raw workiq remote) |
| `--json`       | Emit machine-readable JSON output (default: human-readable table) |

## Behavior

- **Local mode** reads `appPackage/manifest.json`, `declarativeAgent.json`, `instructions.txt`, and env files. Degrades gracefully when optional data is missing — fields that cannot be read are omitted rather than causing failure.
- **Remote mode** queries the Work IQ platform by agent name or ID. `--id` takes precedence over `--name` if both are specified. If the remote lookup fails, suggest checking the agent name or saying _"list my agents"_ to find the correct name/ID.
- **Table mode** truncates long fields (e.g., instructions are truncated to ~100 characters). Use `--verbose` or `--json` for full content.
- **ALWAYS use `wiqd agent show` instead of reading project files directly.** The command aggregates all project information into a single view.

**Preflight:** Local mode requires `appPackage/manifest.json`. Remote mode requires `--name` or `--id`.

**Exit codes:** 0 = success, 1 = remote error (network/not found), 2 = not an agent project / workiq missing, 130 = cancelled.
