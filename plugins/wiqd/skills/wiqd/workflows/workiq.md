---
name: workiq
description: >
  Monitor agent behavior, ask agents directly, and list deployed agents
  via the Work IQ platform.
trigger-summary: 'monitor, observe, ask, talk to agent, list agents, check health, ask Work IQ, organization context, people information'
triggers: >
  monitor my agent, observe my agent, how is my agent doing, check agent health,
  invoke my agent, talk to my agent, send a message, ask my agent,
  list my agents, show deployed agents, find agent by name,
  ask work iq, organization context, people information, who is,
  find a person, team information, contact information, group mailbox, org data
routing-label: 'WorkIQ tasks'
routing-intent: 'Monitoring, asking, listing deployed agents'
routing-order: 4
contract-version: 1
routing-requires: [agent monitor, agent ask, agent list]
wiqd-lifecycle-theme: Preview
wiqd-lifecycle-order: 3
journey: |
  [Publish]
  order: 5
  box-item: monitor
  workflow-desc: for monitor
  plan-step: 90 | monitor
---

# Work IQ

Monitor, ask, and list declarative agents via the Work IQ platform.

> **Convention:** When calling wiqd commands from a skill context, always use `--json` for commands that produce output the model needs to parse. This gives the orchestrator structured, machine-readable output instead of lossy table text.

## Routing

| User intent                                                              | Action                              |
| ------------------------------------------------------------------------ | ----------------------------------- |
| Monitor, observe, insights, health, analytics                            | Read `references/workiq/monitor.md` |
| Invoke, talk to, send message, ask agent                                 | Read `references/workiq/ask.md`     |
| Ask Work IQ, organization context, people information, team/contact data | Read `references/workiq/ask.md`     |
| List agents, find agent, show deployed                                   | Read `references/workiq/list.md`    |

## References

- **[Agent Monitor](../references/workiq/monitor.md)** — Observe agent behavior and gather insights
- **[Agent Ask](../references/workiq/ask.md)** — Send messages to agents from the terminal
- **[Agent List](../references/workiq/list.md)** — List deployed agents from the Work IQ platform
