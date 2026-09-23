# DevUI Start

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Start (or reuse) the local **Work IQ DevUI** web app and open it in the browser. DevUI is a fully local, Fluent UI experience for interactively testing and debugging declarative agents — with rendered answers, citations, matched/selected plugins, retrieval, traces, and raw JSON.

## When to Use

- User wants to **open the agent debugger / DevUI**
- User wants to **iterate on prompts visually** with rendered answers and developer signal
- User says "open devui", "launch the debugger", "debug my agent visually"
- **NOT** for a one-shot terminal answer → read `references/workiq/ask.md`

## Command

```bash
wiqd devui start
wiqd devui start --agent "<id|name>"
wiqd devui start --agent "<id>" --transport direct --no-open --json
```

## Options

| Flag          | Description                                               | Default           |
| ------------- | --------------------------------------------------------- | ----------------- |
| `--agent`     | Agent id or name to preselect (deep-link)                 | _(auto-detected)_ |
| `--transport` | Connection transport: direct \| a2a \| cli                | `direct`          |
| `--port`      | Loopback port to serve DevUI on                           | `7317`            |
| `-q, --query` | Prompt to prefill in the GUI                              | —                 |
| `--no-send`   | With `--query`, prefill the composer without auto-sending | `false`           |
| `--no-open`   | Do not open a browser; print the URL instead              | `false`           |

## Behavior

- **Fire-and-forget:** starts the server detached in the background, opens the browser, and returns immediately. The server outlives the command (logs to a file under the OS temp dir).
- **Reuse:** if a DevUI instance is already healthy on the port, it is reused — no second server is started.

## Critical Rules

- Gated behind the `devui` preview flag — if unavailable, run `wiqd config flags set devui true --skill wiqd`.
- Local-only (binds `127.0.0.1`); connects to M365 Copilot only via `workiq`.
- Auth errors → tell the user to run `wiqd auth login`.

**Exit codes:** 0 = success, 1 = launch error, 2 = infra error (workiq unresolved / port busy).
