# 3P Agent Lifecycle — Golden Path

The end-to-end journey for third-party (3P) developers building and publishing M365 Copilot declarative agents.

## Lifecycle Stages

| Stage            | What Happens                                                       | Reference                                                    |
| ---------------- | ------------------------------------------------------------------ | ------------------------------------------------------------ |
| **1. Ideation**  | Understand requirements, identify data sources, plan capabilities  | `references/orientation.md`                                  |
| **2. Scaffold**  | Create a new agent project with `wiqd agent create`                | `references/scaffolding-workflow.md`                         |
| **3. Build**     | Add capabilities, API plugins, instructions, conversation starters | `references/editing-workflow.md`                             |
| **4. Validate**  | Run manifest validation, fix diagnostics                           | `references/validate.md`                                     |
| **5. Provision** | Register agent in M365, generate test URL                          | `references/provision.md`                                    |
| **6. Test**      | Send messages to the agent, verify behavior                        | `references/ask.md`                                          |
| **7. Evaluate**  | Run scored eval suites to measure quality                          | `workflows/eval.md`                                          |
| **8. Iterate**   | Edit → validate → provision → test cycle                           | `references/editing-workflow.md`                             |
| **9. Package**   | Build the app package (.zip) for distribution                      | `references/package.md`, `references/deployment.md`          |
| **10. Share**    | Share with specific users or tenant for preview                    | `references/share.md`                                        |
| **11. Publish**  | Submit to org admin catalog or Partner Center                      | `references/deployment.md`, `references/publishing-paths.md` |

## The Core Loop

Most development time is spent in the **Build → Validate → Provision → Test** loop:

1. Edit `declarativeAgent.json` (capabilities, instructions, conversation starters)
2. Run `wiqd agent validate` to catch manifest issues
3. Run `wiqd agent provision --env local -i false` to deploy changes
4. Test via the M365 Copilot deep link or `wiqd agent ask`
5. Repeat until satisfied

## Publishing Paths (3P)

| Method                | When to Use           | Steps                                             |
| --------------------- | --------------------- | ------------------------------------------------- |
| **Sideload**          | Personal testing      | `wiqd agent package` → upload zip in Teams        |
| **Org Admin Catalog** | Org-wide distribution | `wiqd agent publish --env <env>` → admin approval |
| **Partner Center**    | Public store listing  | `wiqd agent package` → submit via Partner Center  |

## Prerequisites

- wiqd CLI installed (`wiqd --version` to verify)
- Authenticated (`wiqd auth login`)
- Node.js 18+ (`wiqd doctor` to check)

## Key Commands Quick Reference

```bash
wiqd agent create --template declarative-agent --name my-agent
wiqd agent validate --env local
wiqd agent provision --env local -i false
wiqd agent ask -q "test message" --json
wiqd agent eval --env local
wiqd agent package --env dev
wiqd agent share --scope users --email "user@org.com" --env dev
wiqd agent publish --env prod
```
