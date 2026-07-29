---
title: Exit codes & output
description: The contract scripts and CI pipelines can rely on
---

# Exit codes & output

Every Work IQ Dev Tools command — host or extension-contributed — uses the same exit code contract and the same output envelope. This is what makes Work IQ Dev Tools safe to script.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success. |
| `1` | User error or upstream failure. The thing you asked for didn't work. Re-running with the same inputs will fail the same way. |
| `2` | Infrastructure error. Work IQ Dev Tools couldn't even attempt the operation — a prerequisite tool is missing, you're not in a project, a config file is malformed, an extension didn't load. Fix the environment, then retry. |
| `130` | Cancelled. You pressed Ctrl+C. Work IQ Dev Tools terminated any child processes they spawned. |

Scripts should treat `0` as success, any non-zero as failure, and check for `130` if they need to distinguish "user-aborted" from "tool failed".

### Exit code 2: Missing prerequisite tools

When a command requires an upstream tool (ATK for `wiqd agent` commands, eval for `wiqd agent eval`, or workiq for `wiqd agent monitor`/`ask`) and that tool is not installed, wiqd exits with code `2` in preflight — before attempting any work. The error message shows the exact install command (`npm install -g @microsoft/wiqd`). In an interactive terminal, you are offered to run the install with explicit consent (`y`/`yes`); in CI or non-interactive mode, the message prints and the command exits immediately without prompting.

## Output formats

Every command supports two output modes:

```bash
wiqd <cmd>                  # default: aligned, human-friendly table
wiqd <cmd> --json           # structured JSON envelope
```

### Table mode

Designed for humans. Aligned columns, colors when stdout is a TTY, plain text otherwise. Don't parse it — it's allowed to change between releases.

### JSON mode

This is the contract for scripts and CI pipelines. The envelope is the same shape for every command:

```json
{
  "status": "success",
  "command": "agent.create",
  "data": { /* command-specific payload */ }
}
```

On failure:

```json
{
  "status": "error",
  "command": "agent.create",
  "exitCode": 1,
  "error": { "code": "TEMPLATE_NOT_FOUND", "message": "Template foo does not exist" }
}
```

The top-level keys (`status`, `command`, `data` or `exitCode`/`error`) are stable across commands and releases. The shape of `data` is documented per command in the [CLI Reference](/cli/reference/).

## Verbose mode

```bash
wiqd <cmd> --verbose
```

Forwards raw upstream tool output (stderr from `atk`, `workiq`, etc.) to your stderr. Stdout stays clean — JSON mode still produces valid JSON when combined with `--verbose`, because the diagnostics go to a different stream. Use this when something fails and you want to see the underlying error before opening a bug.

## Banners and pagers

The ASCII banner only shows for bare `wiqd` and the version flag (`wiqd --version` / `wiqd -v`). Every subcommand suppresses it. In CI, with piped stdout, or when `--no-banner` is set, no banner ever prints.

Work IQ Dev Tools never page output. There's no `less`-style pager that captures your terminal — every command runs to completion, prints its result, and exits.

## Go deeper

- [Host vs extensions](/concepts/host-vs-extensions/) — why this contract is uniform across commands
- [`wiqd --help`](/cli/reference/) — global flags including `--json`, `--verbose`, `--no-banner`, `--log-level`
- [`wiqd doctor`](/cli/reference/) — exits non-zero when your environment is broken
