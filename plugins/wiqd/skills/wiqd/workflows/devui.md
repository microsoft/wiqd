---
name: devui
description: >
  Launch the local Work IQ DevUI — a fully local web app for interactively
  testing and debugging declarative agents — and ask an agent and watch the
  turn run live in the browser with full developer detail.
trigger-summary: 'open devui, debug agent, test agent visually, watch agent run, ask in devui, agent debugger'
triggers: >
  open devui, launch devui, start devui, open the agent debugger, debug my agent,
  test my agent visually, watch my agent run live, see it run in the browser,
  ask in devui, run this in the web ui, debug ui, inspect plugins and citations,
  watch the agent respond, open the debugger
routing-label: 'DevUI'
routing-intent: 'Launch the local DevUI web app, and ask an agent while watching the turn run live with full developer detail'
routing-order: 9
contract-version: 1
routing-requires: [devui start, devui ask]
---

# Work IQ DevUI

Launch the **local Work IQ DevUI** web app to interactively test and debug
Microsoft 365 Copilot declarative agents — pick an agent, send prompts, and
inspect deep developer signal (matched/selected plugins, retrieval, citations,
request/conversation/task IDs, latency, raw JSON, and the exact command run).

> **Convention:** DevUI is fully local and connects to M365 Copilot only through
> the `workiq` CLI. It runs in the background (fire-and-forget) and reuses an
> already-running instance, so launching it is safe to repeat.

## When to Use

- User wants to **open the agent debugger / DevUI** ("open devui", "launch the debugger")
- User wants to **iterate on prompts visually** and read rendered answers + citations
- User wants to **watch an agent answer live** with full developer detail
- User wants to **ask an agent and see it run in the browser** → `wiqd devui ask`
- **NOT** for a one-shot terminal answer → use `Skill(workiq)` `wiqd agent ask`
- **NOT** for scored evaluation → route to `Skill(eval)`

## Routing

| User intent                                               | Action                           |
| --------------------------------------------------------- | -------------------------------- |
| Open / launch DevUI, debug agent, open the agent debugger | Read `references/devui/start.md` |
| Ask an agent and watch it run live in the UI              | Read `references/devui/ask.md`   |

## References

- **[DevUI Start](../references/devui/start.md)** — Start (or reuse) the local DevUI and open it in the browser
- **[DevUI Ask](../references/devui/ask.md)** — Ask an agent and watch the turn run live in DevUI

## Critical Rules

- DevUI is gated behind the `devui` preview flag — if the command is unavailable, tell the user to run `wiqd config flags set devui true`.
- DevUI is **read-only** with respect to the project; it observes the agent only through `workiq` calls the developer initiates.
- Starting DevUI is **fire-and-forget** — it runs in the background and reuses a running instance; do not block waiting on it.
- Auth errors surface from `workiq` — tell the user to run `wiqd auth login`.
