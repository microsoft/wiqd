# 3P Agent Lifecycle — Golden Path

The end-to-end journey for third-party (3P) developers building and publishing M365 Copilot declarative agents.

## Lifecycle Stages

| Stage            | What Happens                                                       | Reference                                                                      |
| ---------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| **1. Ideation**  | Understand requirements, identify data sources, plan capabilities  | `references/orientation.md`                                                    |
| **2. Scaffold**  | Create a plugin container, then compose its embedded agent         | Active core workflow → scaffolding reference                                   |
| **3. Build**     | Add capabilities, API plugins, instructions, conversation starters | Active core workflow → editing reference                                       |
| **4. Validate**  | Check saved source; repair only when authorized                    | `workflows/validation.md`; Core source prechecks retain their lifecycle caller |
| **5. Provision** | Register agent in M365, generate test URL                          | Active core workflow → provision reference                                     |
| **6. Test**      | Send messages to the agent, verify behavior                        | `references/workiq/ask.md`                                                     |
| **7. Evaluate**  | Run scored eval suites to measure quality                          | `workflows/eval.md`                                                            |
| **8. Iterate**   | Edit → validate → provision → test cycle                           | Active core workflow → editing reference                                       |
| **9. Package**   | Build the app package (.zip) for distribution                      | Active core workflow → package and deployment references                       |
| **10. Share**    | Share with specific users or tenant for preview                    | Active core workflow → share reference                                         |
| **11. Publish**  | Submit to org admin catalog or Partner Center                      | Active core workflow → deployment reference; `references/publishing-paths.md`  |

## The Core Loop

Most development time is spent in the **Build → Validate → Provision → Test** loop:

An existing complete project created by the retired `wiqd agent create` can
enter this loop directly. Project-scoped plugin commands recognize its structural
lifecycle/root-manifest identity read-only and continue; do not recreate or
flatten the project. If the CLI refuses malformed, incomplete or unsafe
structural data, preserve the project and resolve that exact failure.

1. Edit `declarativeAgent.json` (capabilities, instructions, conversation starters)
2. Run `wiqd plugin validate --mode source --path "<project>" --env local` to check saved source
3. Run `wiqd plugin provision --env local` to deploy changes
4. Test via the M365 Copilot deep link or
   `wiqd plugin ask --component agent`
5. Repeat until satisfied

## Publishing Paths (3P)

| Method                | When to Use           | Steps                                              |
| --------------------- | --------------------- | -------------------------------------------------- |
| **Sideload**          | Personal testing      | `wiqd plugin package` → upload zip in Teams        |
| **Org Admin Catalog** | Org-wide distribution | `wiqd plugin publish --env <env>` → admin approval |
| **Partner Center**    | Public store listing  | `wiqd plugin package` → submit via Partner Center  |

## Prerequisites

- wiqd CLI installed (`wiqd --version` to verify)
- Authenticated (`wiqd auth login`)
- Node.js 18+ (`wiqd doctor` to check)

## Key Commands Quick Reference

```bash
wiqd plugin create --name my-plugin
cd my-plugin
wiqd plugin add agent --name my-agent
wiqd plugin validate --mode source --path . --env local
wiqd plugin provision --env local
wiqd plugin ask --component agent -q "test message" --json
wiqd agent eval --env local
wiqd plugin package --env dev
wiqd plugin validate --mode package --package-file "<built.zip>"
wiqd plugin share --scope users --email "user@org.com" --env dev
wiqd plugin publish --env prod
```
