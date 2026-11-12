---
title: Work IQ · CLI commands
description: Every command contributed by Work IQ Dev Tools' Work IQ extension
---

# Work IQ · CLI commands

The Work IQ extension contributes commands across the retained Agent surface
and the plugin ask surface. Every one requires Work IQ authentication.

| Command | What it does |
|---------|--------------|
| [`wiqd agent monitor`](/cli/reference/#wiqd-agent-monitor) | Ask the Insights Agent about a provisioned agent's performance and usage. |
| [`wiqd plugin ask --component agent`](/cli/reference/#wiqd-plugin-ask) | Send a message directly to a declarative agent by ID or name. |
| [`wiqd agent list`](/cli/reference/#wiqd-agent-list) | List declarative agents deployed in the tenant. |

`plugin ask` always requires `--component agent`; no other component value is
supported. `--agent-id` and `--agent-name` work from any directory without a
local plugin project. If neither is supplied, `--path` and `--env` select the
existing project-context target resolver. The command also retains
`--developer` and the feature-gated `--devui` proxy option.

## Policy publication

The core extension provides `wiqd policy publish` for an existing MOS title
without requiring the original source, app package or project. See
[Policy publication](/cli/policy/) for required inputs,
authentication, publication outcomes and mock behavior.

## Monitor request scope

`wiqd agent monitor` always asks the **Insights Agent**, not the project's agent
directly. It has no `--agent-id` option. Select a project with `--path` (or run
from its directory) and select an environment with `--env` (default `local`).

The CLI tries Insights Agent v2 first. If v2 is unavailable, it can ask v1 once
with the identical question and title scope. Authentication and throttling do
not trigger fallback. JSON `insightsAgent`, `fallbackUsed`, and `fallbackReason`
explain which responder answered; they do not identify an analyzed title.

When `env/.env.<env>` supplies a valid `M365_TITLE_ID`, WIQD sends:

```text
For agent {title}: {question}
```

The title is normalized to lowercase. The question remains your `--query` text,
or the existing default: `Show me '<resolved-agent-name>' key usage stats` when
the project name resolves, otherwise `How is my agent performing?`.
Without a valid single title, WIQD sends that question without the prefix.
It does not guess an ID from the question or response, use a Teams app ID, or
pick another environment.

The displayed **Query** and JSON `data.query` show the outgoing question,
including the prefix when present. IDs returned by Work IQ can identify the
responding Insights Agent; they are not confirmation of the analyzed title.
The prefix records what WIQD asked about, not a guarantee of what Insights
analyzed. An `InputRequired` or no-data reply is not a completed analytics result
even if the CLI exits successfully. A failed v2 task triggers the bounded v1
fallback; if that also fails, the command reports failure rather than metrics.
