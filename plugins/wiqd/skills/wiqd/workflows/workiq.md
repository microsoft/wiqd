---
name: workiq
description: >
  Monitor agent behavior, ask agents directly, list deployed agents, and retrieve remote cards
  via the Work IQ platform.
trigger-summary: 'monitor M365 agent, observe M365 agent, M365 agent usage and analytics, M365 agent feedback, ask M365 agent, list M365 agents, ask Work IQ, organization context, people information'
triggers: >
  monitor my agent, observe my agent, how is my agent doing, how's my agent doing,
  how is my agent performing, is anyone using my agent, how many people use my agent,
  show my agent usage, agent usage stats, agent analytics, agent insights,
  what are users saying about my agent, user feedback on my agent, user ratings for my agent,
  check agent health,
  invoke my agent, talk to my agent, send a message, ask my agent,
  list my agents, show deployed agents, find agent by name, show deployed agent card,
  ask work iq, organization context, people information, who is,
  find a person, team information, contact information, group mailbox, org data
routing-label: 'WorkIQ tasks'
routing-intent: 'Monitoring, asking, listing deployed agents, and remote card lookup'
routing-order: 4
contract-version: 1
routing-requires: [agent monitor, plugin ask, agent list, agent show]
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

Monitor, ask, list, and inspect deployed declarative agents via the Work IQ platform.

> **Convention:** When calling wiqd commands from a skill context, always use `--json` for commands that produce output the model needs to parse. This gives the orchestrator structured, machine-readable output instead of lossy table text.

## Routing

Monitoring and health here mean deployed M365 Copilot agents, not infrastructure
processes, Kubernetes pods, or generic software agents. "Monitor" or "observe"
alone is not evidence of Work IQ intent. Route unrelated infrastructure work to
its own tools without WIQD discovery or commands; retain Work IQ for explicit
Work IQ and M365 agent requests.

| User intent                                                                                                                                | Action                              |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------- |
| How is my agent doing, usage, adoption, analytics, insights, performance, health, trends, user feedback, ratings, satisfaction, complaints | Read `references/workiq/monitor.md` |
| Invoke, talk to, send message, ask agent                                                                                                   | Read `references/workiq/ask.md`     |
| Ask Work IQ, organization context, people information, team/contact data                                                                   | Read `references/workiq/ask.md`     |
| List agents, find agent, show deployed                                                                                                     | Read `references/workiq/list.md`    |
| Show the full deployed-agent card by ID or name                                                                                            | Read `references/workiq/show.md`    |

### Disambiguation

"My agent" questions are monitor requests when they are about **real-world use**: how many people use it, how it performs, what users think. Every phrasing, with or without the words "monitor" or "insights", goes to monitor. Do not ask the user to rephrase and do not ask which command to run.

| The user wants to know...                                                                | Route to                              |
| ---------------------------------------------------------------------------------------- | ------------------------------------- |
| Usage, adoption, performance, trends, what users say or rate (production data)           | `monitor`                             |
| Whether the agent answers correctly against test cases ("is it correct", "run my tests") | the eval workflow                     |
| What the agent says to a prompt right now ("test it", "does it know about X")            | `plugin ask --component agent`        |
| Feedback the user filed about **wiqd** itself ("report a bug", "list my feedback")       | the feedback workflow                 |
| What the deployed agent card reports (capabilities, version)                             | remote `wiqd agent show --id\|--name` |
| What a local plugin project contains                                                     | `wiqd plugin show`                    |

## References

- **[Agent Monitor](../references/workiq/monitor.md)** — Observe agent behavior and gather insights
- **[Agent Ask](../references/workiq/ask.md)** — Send messages to agents from the terminal
- **[Agent List](../references/workiq/list.md)** — List deployed agents from the Work IQ platform
- **[Agent Show](../references/workiq/show.md)** — Retrieve the real deployed-agent card by ID or name
