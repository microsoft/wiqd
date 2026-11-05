# Agent Monitor

**Telemetry:** `--skill wiqd`

Ask the Insights Agent about a project's usage and performance without leaving
the terminal. When the selected environment has a valid title, WIQD explicitly
includes that requested title in the question.

**Core principle**: Select the intended project and environment explicitly.
The request scope is not proof that the responder analyzed that title or found
data. If no valid single title resolves, the CLI still sends the question,
without a title prefix or title attribution.

## How It Works

`wiqd agent monitor` queries the **Insights Agent**, a declarative
responder whose available data depends on its capabilities and the caller's
access. It tries Insights Agent **v2** first and falls back to v1 on its own
(see below). The CLI handles this routing internally and has no `--agent-id`
option. Just call:

```bash
wiqd agent monitor --json --skill wiqd -q "<question about the user's agent>"
```

The responder target is:

```json
{
  "workiqAgentId": "P_1b8d02cb-774a-2469-9a82-06e6bad00aa7.declarativeAgent",
  "fallbackWorkiqAgentId": "P_23193c8d-0406-0253-ad63-c34c455b552d.declarativeAgent"
}
```

The CLI reads `M365_TITLE_ID` from the selected `--path` (or CWD) and
`--env` (default `local`). A valid title produces exactly:

```text
For agent {title}: {question}
```

The title is normalized to lowercase; the question body is unchanged.
**Do not add this prefix yourself or replace it with a more elaborate prompt.**
Missing, malformed, or multiple-ID candidates leave the question unprefixed.
No Teams app ID, response property, citation, or title mentioned in prose is a
fallback. A manifest DA suffix is not required for a valid env title.

### v2 first, v1 fallback

v2 is only available to tenants whose admin has provisioned it and that are in the
Frontier program. When v2 cannot answer, the CLI asks the same question of v1
automatically. The skill does not retry, does not pick an agent, and does not
ask the user anything.
Both requests use the exact same title-prefixed question when a valid title
resolved; the fallback never reads a different title or builds a different prompt.

In `--json` output, `insightsAgent` is `v2` or `v1` and `fallbackUsed` says whether
the fallback ran. When `fallbackUsed` is `true`, add one short line after the
answer: this tenant is using the earlier Insights Agent because v2 is not
available for it (the admin may not have provisioned it, or the tenant may not be
in the Frontier program). v1 may not report user feedback or ratings, so if the
user asked for those and the answer lacks them, say that and suggest asking the
tenant admin about Insights Agent v2. Authentication and throttling errors are
not retried against v1; handle them as usual.

### Smart default query — `-q` is optional

`-q` is **optional**. When omitted or empty, wiqd computes the question body
before applying the title prefix:

- **Inside a project** → sends `Show me '<resolved-agent-name>' key usage stats`,
  where `<resolved-agent-name>` is `appPackage/manifest.json` → `name.short` with
  all `${{VAR}}` placeholders substituted against `env/.env.<env>`.
- **Outside a project**, or when the name cannot resolve fully → uses the generic
  `How is my agent performing?` fallback. Missing context does not block the call,
  but the upstream operation can still fail.

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

## Natural-Language Requests — Run It, Don't Ask

Any question about how the user's agent is **used or received** is a monitor
request, whether or not the user says "monitor" or "insights". Examples:

- "How's my agent doing?" / "How is it performing?"
- "Is anyone using my agent?" / "How many people used it this week?"
- "What are users saying about it?" / "Any complaints?" / "What's the rating?"
- "Any trends?" / "Is usage going up?" / "What do people ask it most?"

**Run the command immediately.** Do not ask the user to rephrase, pick a
command, or confirm the query. Only ask when the agent or environment cannot be
determined (see the table below), and ask one short question at a time.

| Situation                                                       | What to do                                                                                                                                          |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Inside a provisioned agent project                              | Run `wiqd agent monitor --json --skill wiqd --env <env>`. Omit `-q` for a general "how is it doing" question; pass `-q` for anything more specific. |
| Inside a project that is not provisioned                        | Explain that no resolved title means an unscoped request; monitoring can still run. Provision only if the user requests it.                         |
| Outside a project, user named the agent                         | Standalone mode. Put the exact name in the query, in single quotes.                                                                                 |
| Outside a project, user did not name the agent                  | Run `wiqd agent list --json --skill wiqd`. One result: use it and say so. Several: ask which one. None: say no deployed agents were found.          |
| Folder holds several agent projects                             | Find the folders that contain `appPackage/manifest.json`. One: pass it as `--path`. Several: ask which one.                                         |
| "All my agents" / "compare my agents"                           | Monitor covers one agent at a time. Say so, list the agents, and ask which one to start with.                                                       |
| Follow-up ("why?", "what about last week?", "show the details") | Reuse the same agent and environment. Send a new query that names the agent and carries the follow-up. Do not re-ask for the agent or environment.  |
| The user wants configuration, not usage ("what can it do?")     | Use `wiqd agent show` instead.                                                                                                                      |
| The user wants to try the agent ("test it", "does it know X?")  | Use `wiqd agent ask` instead. Monitor talks to the Insights Agent, never to the user's agent.                                                       |

Insights Agent v2 reports usage analytics and user feedback for agents the user
owns. Feedback results can be a sample; if the user wants everything, ask the
Insights Agent for all verbatim feedback. Report only what it returns, and say
so when it has no data for the agent (for example, a brand-new agent).

The CLI supports **two modes**:

### Project Mode (inside an agent project)

The CLI reads the selected project and env file, prefixes the valid requested
title, and displays the actual outgoing Query. The v2/v1 responder selection
does not change that title. JSON `data.query` includes the prefix when present; upstream agent IDs
can identify the responder and must not be presented as verified analyzed titles.

### Standalone Mode (outside an agent project)

When NOT inside an agent project, the CLI still works — it sends the query
directly to the Insights Agent without project context. The responder may
interpret names in the question, but WIQD does not derive title attribution from
that interpretation or claim a verified target.

**This means the skill can work from any directory** — the user just needs to
mention the agent name in their request (e.g., "monitor the Sales Bot agent").
The skill should include the agent name in the query so the Insights Agent knows
which agent to report on.

## Session Memory — Environment Persistence

This skill **remembers the environment across calls within the same session**.

### First Call — Environment

1. **Check which environments are provisioned** — scan `env/.env.*` files
   (excluding `.user` files) to discover available environments.
2. **If the user named an environment** ("how is it doing in prod?") → use it.
3. **If only one environment exists** (e.g., only `env/.env.local`) → use it
   automatically and tell the user.
4. **If multiple environments exist** (e.g., `local`, `dev`, `staging`) and the
   user did not say which → use `dev` when it exists (usage data lives in
   non-local environments), and tell the user which environment you used. If
   there is no `dev`, ask which one to use.
5. **Remember the chosen environment** for subsequent calls in this session.

### Subsequent Calls

- Reuse the previously selected environment **without asking again**.
- Pass the selected `--env` on every project-mode call; the CLI's own default is
  `local`, not the skill's remembered environment.
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
| `--env`         | Selected environment; a missing title leaves the request unscoped | `local`                                                                                                                    |
| `--path`        | Agent project directory (for project mode)                        | `./`                                                                                                                       |
| `-v, --verbose` | Show raw workiq output for debugging                              | `false`                                                                                                                    |
| `--json`        | Emit machine-readable JSON output (default: human-readable table) | `false`                                                                                                                    |

## Workflow

### Step 1: Discover the Agent

#### Project Mode (inside an agent project)

1. Read `appPackage/manifest.json` → extract `name.short`.
2. Read the required context from `env/.env.{env}`. Do not substitute a `.user`
   overlay or another environment for the CLI's selected title source.
3. **Resolve** any `${{VAR}}` placeholders in `name.short` using the env vars from
   the targeted environment. For example, if `name.short` is
   `"Contoso Helper${{APP_NAME_SUFFIX}}"` and `env/.env.local` has
   `APP_NAME_SUFFIX=-local`, the resolved name is `"Contoso Helper-local"`.
   Always display the **fully resolved name**, never the raw placeholder.
4. Read `copilotAgents.declarativeAgents[0].id` for agent ID derivation.
5. Read `M365_TITLE_ID` when available; missing context does not block monitoring.
6. A full display agent ID can be constructed when both parts exist:
   `<M365_TITLE_ID>.<DA_ID>`. Let the CLI validate and prefix the bare title;
   never pass the composite ID as monitor's target option.

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
- **A vague request** ("how is my agent doing?", "get me analytics") — form
  the query yourself and run it. In a project, omit `-q` and let the CLI use its
  smart default. Otherwise use the matching row of the Query Formulation Guide
  below. Do not ask the user to pick a question first.
- **A detail request** ("show me agent details", "what can it do?") — use
  `wiqd agent show` instead of monitor. Show capabilities, version, etc.
- **A request to try the agent** ("test it", "does it know about X?") — use
  `wiqd agent ask`. The Insights Agent answers about usage, not about the
  agent's own knowledge.

**Be generous with query interpretation.** If the user says "check metrics",
form: `--query "What are your current usage metrics and performance insights?"`.

The goal is to translate the user's **intent** into a well-formed, agent-scoped
usage question for the Insights Agent.

### Step 3: Execute

```bash
# Project mode: preserve the selected project and environment
wiqd agent monitor --json --skill wiqd --path "<project>" --env "<selected-env>" -q "<question>"

# Standalone: no project context or title attribution
wiqd agent monitor --json --skill wiqd -q "<question>"

# For agent metadata / capabilities / details
wiqd agent show --json --skill wiqd --id "<user's agent ID>"
```

### Step 4: Present Results

Display the agent's response clearly:

Do not infer analytics success from the CLI envelope alone. If the reply reports
`InputRequired`, a failed task, or no data, state that result plainly rather than
inventing metrics or claiming that the selected title was analyzed.

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
| "is anyone using it?"    | "How many people have used you recently, and is usage growing or shrinking?"                                              |
| "get usage data"         | "What are your total queries processed, average response time, and user satisfaction metrics?"                            |
| "what's working well?"   | "What aspects of your responses are performing well? Where are users most satisfied?"                                     |
| "any issues?"            | "Are there any recurring issues, errors, or areas where your responses are falling short?"                                |
| "what are users saying?" | "What feedback have users given about you? Include ratings and the most common themes."                                   |
| "any complaints?"        | "What negative feedback have users given about you, and what are the main themes?"                                        |
| "show all the feedback"  | "Show all verbatim user feedback about you, not a sample."                                                                |

Requests like "test it", "does it know about X?", or "ask it about [topic]" are
**not** monitor requests. Send them with `wiqd agent ask`.

## Error Recovery

| Error                                           | Action                                                                                                                                |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| workiq CLI not found                            | Route to `/wiqd-install` — wiqd + workiq both needed                                                                                  |
| Not an agent project (no declarativeAgent.json) | Switch to **standalone mode**. Ask the user for the agent name if not provided, then include it in the query.                         |
| Agent not provisioned (no env files)            | Explain that the question will be unscoped; monitoring can still run. Provision only if the user requests it.                         |
| Missing m365agents.yml                          | Warn but continue — the CLI handles this gracefully.                                                                                  |
| Auth error from workiq                          | Tell user: _"log me in"_                                                                                                              |
| `unknown command 'monitor'`                     | The `workiq-monitor` flag is off. Run `wiqd config flags set workiq-monitor true --skill wiqd`, then retry.                           |
| `MONITOR_INSIGHTS_UNAVAILABLE`                  | Both v2 and its v1 fallback failed. Report both errors, do not retry, and do not call `wiqd agent ask` as a substitute.               |
| Insights Agent has no data for the agent        | Say so plainly. A new, unpublished, or unshared agent may not have usage yet. Do not invent numbers or call `wiqd agent ask` instead. |
| Feedback asked for but not returned             | Report what Insights said. Feedback needs verified ownership and tenant-enabled sharing; do not guess which is missing.               |
| Timeout                                         | Suggest `--verbose` to debug; the query may be too complex                                                                            |
| No valid single title ID in selected env        | Continue without the prefix or title attribution. Do not guess, switch environments, or re-provision automatically.                   |

## Safety Rules

- **MUST** resolve all `${{VAR}}` placeholders in the agent's `name.short` using the targeted environment's env vars before displaying — never show raw placeholders (project mode only)
- **MUST** scope every query to THE specific agent being monitored — never compare multiple agents
- **MUST** use the selected project and environment; explain safe omission when no valid single title resolves
- **MUST** remember the environment across calls in the same session
- **MUST** run monitor straight away for any usage, performance, or feedback question about the user's agent, however it is phrased
- **MUST** turn vague requests into clear, agent-scoped queries yourself — don't pass vague text, and don't make the user write the query
- **MUST NOT** send "test it" or "does it know about X" requests to monitor — they go to `wiqd agent ask`
- **MUST** frame all insights, analytics, and trend queries about THIS agent specifically
- **MUST** include the agent name EXACTLY as provided/confirmed (preserving original capitalization and any parenthetical suffixes such as `(Prod)`), wrapped in single quotes, in the query when running in standalone mode — e.g., `"I want to learn about the usage of the 'Contoso Sales Agent' agent"`
- **MUST NOT** modify any project files — monitor is read-only
- **MUST NOT** invent analytics data — only display what the agent returns
- **MUST NOT** treat a scoped prompt or CLI success as proof of a completed analytics result
- **MUST NOT** add the title prefix manually; WIQD assembles it from the selected env
- **MUST NOT** ask for the environment repeatedly within the same session
- **MUST NOT** query or compare multiple agents in a single monitor session
- **MUST NOT** pass `--agent-id` to `wiqd agent monitor` — the CLI handles Insights Agent routing internally
- **MUST NOT** require the user to be inside an agent project — standalone mode works from any directory
