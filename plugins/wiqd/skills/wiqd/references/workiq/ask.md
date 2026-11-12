# Plugin Ask — Agent component

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Send a message directly to any M365 Copilot declarative agent and display its response — from the terminal, without leaving the editor.

Uses workiq's A2A (Agent-to-Agent) protocol under the hood. The agent ID format is `{M365_TITLE_ID}.{declarativeAgentId}`.

## When to Use

- User wants to **send a message to their agent** during development
- User wants a quick **"poke it and see"** exploratory test
- User says "ask my agent", "test my agent", "send a question to my agent"
- User wants to **talk to a specific agent by name** (e.g., "ask the Prompt Coach about X")
- User wants to **ask Work IQ anything** — general questions, org data, or specific M365/Graph data points — to unblock or push their workflow further → see [Ask Work IQ Anything](#ask-work-iq-anything) below
- **NOT** for insights/analytics → use `references/workiq/monitor.md`
- **NOT** for formal scored testing → read `workflows/eval.md`

## Commands

**Project mode** — CLI auto-resolves agent ID from manifest + env files:

```bash
wiqd plugin ask --component agent --json --skill wiqd -q "<message>"
wiqd plugin ask --component agent --json --skill wiqd --env staging --path ../other-agent -q "<message>"
```

**Standalone mode** — explicit target (always wins over project auto-resolution):

```bash
wiqd plugin ask --component agent --json --skill wiqd --agent-id "<full-id>" -q "<message>"
wiqd plugin ask --component agent --json --skill wiqd --agent-name "Sales Bot" -q "<message>"
```

## Options

| Flag            | Description                                                                                          | Default      |
| --------------- | ---------------------------------------------------------------------------------------------------- | ------------ |
| `--component`   | Required routing choice. Use the exact value `agent`; no other value is supported.                   | _(required)_ |
| `-q, --query`   | Message to send (required)                                                                           | _(required)_ |
| `--agent-id`    | Full agent ID (`{TitleID}.{DA_ID}`). Auto-resolved in project mode.                                  | _(auto)_     |
| `--agent-name`  | Human-readable name (fuzzy-matched). If both targets are present, `--agent-id` wins.                 | —            |
| `--env`         | Environment for project auto-resolution                                                              | `local`      |
| `--path`        | Project directory for auto-resolution                                                                | `.`          |
| `--devui`       | Try the DevUI ask proxy; if unavailable, retain the direct Work IQ fallback.                         | `false`      |
| `-v, --verbose` | Show raw workiq output                                                                               | `false`      |
| `--json`        | Emit machine-readable JSON output (default: human-readable table)                                    | `false`      |
| `--developer`   | Include native Work IQ developer metadata for this request; may contain sensitive execution details. | `false`      |

## Modes

1. **Project mode** (inside a Microsoft 365 Agents project, no
   `--agent-id`/`--agent-name`): CLI reads `M365_TITLE_ID` from
   `env/.env.{env}` + DA ID from the app manifest and composes the agent ID.
   Call `wiqd plugin ask --component agent --json -q "<message>"`.
2. **Standalone mode** (outside project, or explicit target): User provides `--agent-id` or `--agent-name`. Explicit flags always win over project auto-resolution.

## Ask Work IQ Anything

`wiqd plugin ask --component agent` isn't limited to the developer's own agent
— it is a general-purpose way to **ask Work IQ anything**. Because Work IQ is
backed by M365 Copilot (bizchat), it can answer broad questions, reason over
context, and pull live tenant data (M365/Graph) the same way Copilot does in the
browser.

To ask Work IQ in this general mode, target the platform-wide M365 Copilot agent with the hardcoded agent ID **`bizchat-as-gpt-scenario`** — it has full bizchat/Graph access and isn't tied to any project:

```bash
wiqd plugin ask --component agent --json --skill wiqd --agent-id "bizchat-as-gpt-scenario" -q "<anything you want to ask>"
```

**Example — pulling specific data points to push a workflow further.** A common use is grabbing a precise org-data value mid-task (an email address, a group mailbox, a contact) so the developer doesn't have to leave the terminal to look it up:

```bash
wiqd plugin ask --component agent --json --skill wiqd --agent-id "bizchat-as-gpt-scenario" -q "What is the email address for the HR Benefits team group mailbox?"
wiqd plugin ask --component agent --json --skill wiqd --agent-id "bizchat-as-gpt-scenario" -q "Find the group mailbox for the IT Helpdesk team"
wiqd plugin ask --component agent --json --skill wiqd --agent-id "bizchat-as-gpt-scenario" -q "What is John Smith's email address?"
```

Suggest this whenever a developer needs an answer or a specific data point — _"find the email for…"_, _"what's the group mailbox for…"_, _"look this up for me"_, or any open-ended question — during their workflow. Answers depend on the caller's tenant permissions and what M365/Graph exposes to them.

## Session Memory

Remember agent and environment across calls within the same session. First call resolves the agent; subsequent calls reuse the resolved ID without re-asking.

## Error Recovery

| Error                                               | Action                                                  |
| --------------------------------------------------- | ------------------------------------------------------- |
| Not in a project and no `--agent-id`/`--agent-name` | Tell user to specify an agent or navigate to a project  |
| Agent not provisioned (no env files)                | Route to the active core workflow's provision reference |
| No `M365_TITLE_ID` in env file                      | Route to the active core workflow's provision reference |
| Auth error from workiq                              | Tell user: _"log me in"_                                |
| Agent not found / 404                               | Suggest verifying agent ID/name                         |

## Critical Rules

- **MUST** always include the required `--component agent`
- **MUST** prefer auto-resolution when in a project — let the CLI compose the agent ID
- **MUST** resolve all `${{VAR}}` placeholders in `name.short` before displaying
- **MUST** pass user's message through faithfully — do not alter intent
- **MUST NOT** modify any project files — ask is read-only
- **MUST NOT** require local plugin recognition when an explicit target is supplied
- **MUST NOT** confuse plugin ask with agent monitor

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
