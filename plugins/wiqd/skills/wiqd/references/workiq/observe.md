# Agent Observe

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Observe, test, and monitor deployed agents — covers all observe scenarios through three complementary commands.

## Command Routing

| User Intent                                    | Command              | Reference                      |
| ---------------------------------------------- | -------------------- | ------------------------------ |
| "Send a message to my agent" / "test my agent" | `wiqd agent ask`     | `references/workiq/ask.md`     |
| "How is my agent doing?" / "show me analytics" | `wiqd agent monitor` | `references/workiq/monitor.md` |
| "List all deployed agents"                     | `wiqd agent list`    | `references/workiq/list.md`    |

## Agent Ask — Send Test Messages

Send a message to any deployed agent and display its response from the terminal.

```bash
# Project mode (auto-resolves agent from manifest + env)
wiqd agent ask --json --skill wiqd -q "<message>"

# Standalone mode (explicit target)
wiqd agent ask --json --skill wiqd --agent-id "<full-id>" -q "<message>"
wiqd agent ask --json --skill wiqd --agent-name "Sales Bot" -q "<message>"
```

| Flag           | Description                                   | Default      |
| -------------- | --------------------------------------------- | ------------ |
| `-q, --query`  | Message to send (required)                    | _(required)_ |
| `--agent-id`   | Full agent ID. Auto-resolved in project mode. | _(auto)_     |
| `--agent-name` | Human-readable name (fuzzy-matched)           | —            |
| `--env`        | Environment for project auto-resolution       | `local`      |
| `--json`       | Emit JSON output                              | `false`      |

**Modes:**

- **Project mode** (inside ATK project, no explicit target): CLI reads `M365_TITLE_ID` + DA ID and composes agent ID automatically.
- **Standalone mode** (`--agent-id` or `--agent-name`): explicit target, works from any directory.

## Agent Monitor — Usage Insights & Analytics

Query the Insights Agent for usage metrics, performance data, and trends about a specific agent.

```bash
# Project mode (query computed from resolved agent name)
wiqd agent monitor --json --skill wiqd

# With explicit query
wiqd agent monitor --json --skill wiqd -q "<question about agent>"

# With environment
wiqd agent monitor --json --skill wiqd --env prod
```

| Flag          | Description                                            | Default  |
| ------------- | ------------------------------------------------------ | -------- |
| `-q, --query` | Question to send (optional — smart default if omitted) | _(auto)_ |
| `--env`       | Target environment                                     | `local`  |
| `--json`      | Emit JSON output                                       | `false`  |

**Important:** The CLI routes queries to the Insights Agent internally. Do NOT pass `--agent-id` to monitor — the CLI handles this routing. The `-q` query should be about the user's agent (usage, insights, trends), not a message to the agent itself.

## Agent List — Deployed Agent Inventory

```bash
wiqd agent list [--name <filter>] [--id <filter>] [--top <n>] [--json] --skill wiqd
```

Lists agents deployed in the tenant. Works from any directory — no project context needed.

| Flag     | Description                            | Default |
| -------- | -------------------------------------- | ------- |
| `--name` | Filter by agent name (substring match) | —       |
| `--id`   | Filter by agent ID                     | —       |
| `--top`  | Maximum number of results              | `10`    |
| `--json` | Emit JSON output                       | `false` |

## Error Recovery

| Error                         | Action                                         |
| ----------------------------- | ---------------------------------------------- |
| Agent not provisioned         | Run `wiqd agent provision` first               |
| Auth error                    | Run `wiqd auth login`                          |
| Agent not found (ask/monitor) | Verify agent ID/name, check provisioning state |
| workiq CLI not found          | Install wiqd with extensions                   |
| No M365_TITLE_ID in env       | Re-provision the agent                         |

## Safety Rules

- **MUST NOT** modify any project files — all observe commands are read-only
- **MUST** prefer auto-resolution when in a project (let the CLI compose the agent ID)
- **MUST** resolve `${{VAR}}` placeholders in agent names before displaying
- **MUST** scope monitor queries to a single specific agent

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
