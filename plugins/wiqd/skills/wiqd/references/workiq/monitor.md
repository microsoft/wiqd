# Agent Monitor

**Telemetry:** `--skill wiqd`

Monitor a single provisioned declarative agent — send queries, check responses,
and gather insights about **that specific agent** without leaving the terminal.

**Core principle**: Every monitor session is scoped to **one agent at a time**.
All queries, analytics, insights, and follow-ups are always about THE agent
being monitored. If the user wants to monitor a different agent, they switch
context explicitly.

## How It Works

`wiqd agent monitor` always queries the **Insights Agent** — a hardcoded backend
agent that knows about all agents in the tenant. The CLI handles this routing
internally — the skill does NOT need to pass `--agent-id`. Just call:

```bash
wiqd agent monitor --json --skill wiqd -q "<question about the user's agent>"
```

The backend target is:

```json
{
  "workiqAgentId": "P_23193c8d-0406-0253-ad63-c34c455b552d.declarativeAgent"
}
```

### Smart default query — `-q` is optional

`-q` is **optional**. When omitted, wiqd computes the query for you:

- **Inside a project** → sends `Show me '<resolved-agent-name>' key usage stats`,
  where `<resolved-agent-name>` is `appPackage/manifest.json` → `name.short` with
  all `${{VAR}}` placeholders substituted against `env/.env.<env>`.
- **Outside a project** → sends the generic `How is my agent performing?`
  fallback so the call still succeeds with no project context.

**When the skill SHOULD omit `-q`:** the user wants generic stats / "how is my
agent doing?" for the agent in the current project. Letting the CLI compute the
default keeps the resolved agent name in lock-step with what's actually
deployed.

**When the skill MUST pass `-q` explicitly:**

- The user asks a non-stats question (debugging a specific issue, asking what
  the agent does, asking "did anyone complain about X?", etc.).
- Standalone mode where the user named a specific other agent — pass that agent
  name in the query so the Insights Agent can identify it (e.g.,
  `-q "I want to learn about the usage of the 'Sales Bot' agent"`).
- Any time you want full control over the wording.

The `--query` is formulated by the skill based on the user's request and includes
context about the specific agent being monitored (name, ID, environment).

The CLI supports **two modes**:

### Project Mode (inside an agent project)

The CLI reads the local project (manifest + env files) to identify the agent
being monitored and displays that context in the output. The Insights Agent ID
is constant and handled internally by the CLI.

### Standalone Mode (outside an agent project)

When NOT inside an agent project, the CLI still works — it sends the query
directly to the Insights Agent without project context. The Insights Agent
resolves the agent from the query text itself.

**This means the skill can work from any directory** — the user just needs to
mention the agent name in their request (e.g., "monitor the Sales Bot agent").
The skill should include the agent name in the query so the Insights Agent knows
which agent to report on.

## Session Memory — Environment Persistence

This skill **remembers the environment across calls within the same session**.

### First Call — Environment

1. **Check which environments are provisioned** — scan `env/.env.*` files
   (excluding `.user` files) to discover available environments.
2. **If only one environment exists** (e.g., only `env/.env.local`) → use it
   automatically and tell the user.
3. **If multiple environments exist** (e.g., `local`, `dev`, `staging`) →
   ask which environment to use. Default suggestion: `dev`
   (for analytics/usage data, dev environments typically have real traffic).
4. **Remember the chosen environment** for subsequent calls in this session.

### Subsequent Calls

- Reuse the previously selected environment **without asking again**.
- If the user explicitly mentions a different environment, switch and
  remember the new selection going forward.

### Default

If no explicit choice is made and only one env exists, use that one.
If the user doesn't specify and multiple envs exist, default to `dev` (real
usage data lives in non-local environments).

## Commands

### Monitor (Send Queries)

The CLI handles Insights Agent routing internally. Just pass the query:

```bash
wiqd agent monitor --json --skill wiqd -q "<question about the user's agent>"
```

The `--query` is formulated by the skill based on the user's request and includes
context about the specific agent being monitored (name, ID, environment).

### Options (Monitor)

| Flag            | Description                                                       | Default                                                                                                                    |
| --------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `--skill`       | Set explicitly to `wiqd` for telemetry                            | _none_                                                                                                                     |
| `-q, --query`   | The question to send (formulated by the skill)                    | _smart default_ — `Show me '<resolved-agent-name>' key usage stats` in a project, `How is my agent performing?` standalone |
| `--env`         | Target environment (must be provisioned)                          | `local`                                                                                                                    |
| `--path`        | Agent project directory (for project mode)                        | `./`                                                                                                                       |
| `-v, --verbose` | Show raw workiq output for debugging                              | `false`                                                                                                                    |
| `--json`        | Emit machine-readable JSON output (default: human-readable table) | `false`                                                                                                                    |

## Workflow

### Step 1: Discover the Agent

#### Project Mode (inside an agent project)

1. Read `appPackage/manifest.json` → extract `name.short`.
2. Read `env/.env.{env}` (and `env/.env.{env}.user` if it exists) → load all env vars.
3. **Resolve** any `${{VAR}}` placeholders in `name.short` using the env vars from
   the targeted environment. For example, if `name.short` is
   `"Contoso Helper${{APP_NAME_SUFFIX}}"` and `env/.env.local` has
   `APP_NAME_SUFFIX=-local`, the resolved name is `"Contoso Helper-local"`.
   Always display the **fully resolved name**, never the raw placeholder.
4. Read `copilotAgents.declarativeAgents[0].id` for agent ID derivation.
5. Extract `M365_TITLE_ID` from the loaded env vars.
6. Construct the full agent ID: `<M365_TITLE_ID>.<DA_ID>`.

Present the agent info to the user using the **resolved short name**:

```
🔭 Monitoring "Contoso Helper-local" (env: local)
   Agent ID: T_f09fddbc-297c-880b-7d16-89d321a98a52.declarativeAgent
```

**IMPORTANT**: Always resolve env var placeholders in the name using the
targeted environment's `.env` file. Never display raw `${{VAR}}` placeholders.

#### Standalone Mode (NOT inside an agent project)

1. Extract the agent name from the user's request (e.g., "monitor the Sales Bot"
   → agent name is "Sales Bot").
2. If the user didn't provide a name (just "monitor my agent"), ask which
   agent they want to monitor.
3. **Include the agent name EXACTLY in the query** — use it verbatim as provided/confirmed
   (preserving exact capitalization and any parenthetical suffixes such as `(Prod)`),
   wrapped in single quotes. Use a query like:
   `--query "I want to learn about the usage of the 'Sales Bot' agent"`
4. No env files, no manifest — skip all project-based resolution.

Present:

```
🔭 Monitoring "Sales Bot" (standalone — no project context)
```

### Step 2: Form the Query

Every query MUST be about THE agent being monitored. Never form queries that
compare multiple agents or ask about agents generically.

The user's request may be:

- **A direct question** — pass it through as-is to `--query`.
- **A vague request** ("how is my agent doing?", "get me analytics") — help
  the user form a specific query scoped to this agent. Suggest concrete questions:
  - "What are the current insights about your performance?"
  - "What are the latest trends in how you're being used?"
  - "How many queries have you processed recently?"
  - "What is the user satisfaction rate for your responses?"
  - "Summarize your recent interactions and common topics."
- **A detail request** ("show me agent details", "what can it do?") — use
  `wiqd agent show` instead of monitor. Show capabilities, version, etc.

**Be generous with query interpretation.** If the user says "check metrics",
form: `--query "What are your current usage metrics and performance insights?"`.
If they say "test if it works", form: `--query "Hello, what can you help me with?"`.

The goal is to translate the user's **intent** into a well-formed, agent-scoped
query that gets the best response from this specific agent.

### Step 3: Execute

```bash
# For queries / analytics / usage — just pass the query, CLI routes to Insights Agent
wiqd agent monitor --json --skill wiqd -q "<formed query>"

# For agent metadata / capabilities / details
wiqd agent show --json --skill wiqd --id "<user's agent ID>"
```

### Step 4: Present Results

Display the agent's response clearly:

```
─── Agent Response ───────────────────────────────────
<agent response text>
──────────────────────────────────────────────────────
```

For `wiqd agent show` results, present as a structured summary:

```
🔍 Sales Bot
  Name          Sales Bot
  Description   A sales pipeline assistant
  Agent ID      T_f09fddbc-297c-880b-7d16-89d321a98a52.declarativeAgent
  Version       1.0
  Endpoint      https://copilot.microsoft.com/api/v1/agents/...
  Streaming     Yes
  Push Notif.   No
  State History Yes
```

## Query Formulation Guide

All queries MUST be framed about **the specific agent being monitored** — never
generic or multi-agent. Help users get the best results by forming clear,
agent-scoped queries:

| User says...             | Form this query                                                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| "check metrics"          | "What are your current usage metrics and analytics?"                                                                      |
| "how is it doing?"       | "Provide a summary of your performance, including query volume, response quality, and user satisfaction."                 |
| "what are the insights?" | "What are the current insights about your usage, response patterns, and effectiveness?"                                   |
| "any trends?"            | "What are the latest trends in how you're being used? Are queries increasing or decreasing? What topics are most common?" |
| "test it"                | "Hello, what can you help me with?"                                                                                       |
| "does it know about X?"  | "What do you know about X? Provide details and sources."                                                                  |
| "ask about [topic]"      | Pass topic through directly with added context for clarity                                                                |
| "get usage data"         | "What are your total queries processed, average response time, and user satisfaction metrics?"                            |
| "what's working well?"   | "What aspects of your responses are performing well? Where are users most satisfied?"                                     |
| "any issues?"            | "Are there any recurring issues, errors, or areas where your responses are falling short?"                                |

## Error Recovery

| Error                                           | Action                                                                                                                                                           |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| workiq CLI not found                            | Route to `/wiqd-install` — wiqd + workiq both needed                                                                                                             |
| Not an agent project (no declarativeAgent.json) | Switch to **standalone mode**. Ask the user for the agent name if not provided, then include it in the query.                                                    |
| Agent not provisioned (no env files)            | In project mode: **Stop.** Tell user: "This agent is not provisioned yet." Suggest _"provision my agent"_. Route to `/agent-provision`. In standalone mode: N/A. |
| Missing m365agents.yml                          | Warn but continue — the CLI handles this gracefully.                                                                                                             |
| Auth error from workiq                          | Tell user: _"log me in"_                                                                                                                                         |
| Timeout                                         | Suggest `--verbose` to debug; the query may be too complex                                                                                                       |
| No title ID in env                              | Re-provision with `/agent-provision` (project mode only)                                                                                                         |

## Safety Rules

- **MUST** resolve all `${{VAR}}` placeholders in the agent's `name.short` using the targeted environment's env vars before displaying — never show raw placeholders (project mode only)
- **MUST** scope every query to THE specific agent being monitored — never compare multiple agents
- **MUST** verify agent is provisioned before monitoring (project mode only)
- **MUST** remember the environment across calls in the same session
- **MUST** help users form clear, agent-scoped queries — don't just pass vague text
- **MUST** frame all insights, analytics, and trend queries about THIS agent specifically
- **MUST** include the agent name EXACTLY as provided/confirmed (preserving original capitalization and any parenthetical suffixes such as `(Prod)`), wrapped in single quotes, in the query when running in standalone mode — e.g., `"I want to learn about the usage of the 'Contoso Sales Agent' agent"`
- **MUST NOT** modify any project files — monitor is read-only
- **MUST NOT** invent analytics data — only display what the agent returns
- **MUST NOT** ask for the environment repeatedly within the same session
- **MUST NOT** query or compare multiple agents in a single monitor session
- **MUST NOT** pass `--agent-id` to `wiqd agent monitor` — the CLI handles Insights Agent routing internally
- **MUST NOT** require the user to be inside an agent project — standalone mode works from any directory
