# DevUI Ask

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Ask an agent and **watch the turn run live** in the local Work IQ DevUI — the prompt is deep-linked and auto-sent, so the developer sees it execute in the browser with full developer detail (matched/selected plugins, retrieval, citations, request/conversation/task IDs, latency, raw JSON).

## When to Use

- User wants to ask an agent and **see it run in the UI**, not just a terminal answer
- User says "ask in devui", "run this in the web ui", "watch my agent answer"
- For a one-shot terminal answer instead → use `Skill(workiq)` `wiqd agent ask`

## Command

```bash
wiqd devui ask -q "<message>"
wiqd devui ask -q "<message>" --agent "<id|name>" --transport direct
```

## Options

| Flag          | Description                                  | Default      |
| ------------- | -------------------------------------------- | ------------ |
| `-q, --query` | Prompt to send to the agent (required)       | _(required)_ |
| `--agent`     | Agent id or name to target (deep-link)       | —            |
| `--transport` | Connection transport: direct \| a2a \| cli   | `direct`     |
| `--port`      | Loopback port to serve DevUI on              | `7317`       |
| `--no-open`   | Do not open a browser; print the URL instead | `false`      |

## Behavior

- Starts (or reuses) DevUI in the background, deep-links to the agent, **auto-sends** the prompt, and opens the browser so the developer watches the turn run live with full developer detail.

## Critical Rules

- Gated behind the `devui` preview flag — if unavailable, run `wiqd config flags set devui true`.
- Local-only; connects to M365 Copilot only via `workiq`. Auth errors → `wiqd auth login`.

**Exit codes:** 0 = success, 1 = launch error, 2 = infra error.
