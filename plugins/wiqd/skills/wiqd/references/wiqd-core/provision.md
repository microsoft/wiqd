# Agent Provision

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Provision a declarative agent to an environment (deploy to M365).

## Validation Gate — MANDATORY

Provisioning is **blocked** until the manifest validates clean. Before running the provision command:

1. Run `wiqd agent validate --json --skill wiqd` as a precondition.
2. **PASS** → proceed. **FAIL** → stop, surface diagnostics, do NOT provision.
3. Do not re-run validation or interpret diagnostics from this context.

## Command

```bash
wiqd agent provision --json --skill wiqd --env <environment> [--path <path>]
```

## Options

| Flag                | Description                              | Default |
| ------------------- | ---------------------------------------- | ------- |
| `--env`             | Target environment (local, dev, staging) | `local` |
| `--path`            | Agent project directory                  | `./`    |
| `-v, --verbose`     | Show raw output for debugging            | `false` |

## Workflow

1. Check if the agent has `AGENT_SCOPE=shared` in the target env file (`env/.env.<env>`).
   If **shared**, run the [Shared Agent Version Bump](#shared-agent-version-bump) flow first.
2. Run `wiqd agent provision --json --skill wiqd --env local`
3. Read `M365_TITLE_ID` from `env/.env.local`
4. Present the test link: `https://m365.cloud.microsoft/chat?titleId={M365_TITLE_ID}`

## Shared Agent Version Bump

When provisioning a **shared** agent (`AGENT_SCOPE=shared`), bump the manifest version:

1. Check all env files for `TEAMS_APP_VERSION`. If missing:
   - Read current version from `appPackage/manifest.json`
   - Add `TEAMS_APP_VERSION=<version>` to every env file that lacks it
   - Update `manifest.json` to use `"version": "${{TEAMS_APP_VERSION}}"`
2. Bump the **patch** component in the target env file (e.g., `1.0.0` → `1.0.1`)
3. Only bump the target env file — others keep their current version

## Environment Strategy

| Environment | Purpose                   |
| ----------- | ------------------------- |
| `local`     | Development and testing   |
| `dev`       | Shared development        |
| `staging`   | Pre-production validation |

## Critical Rules

- **NEVER** provision when validation returned FAIL
- **NEVER** edit project files from this context — routing fixes is agent-validate's responsibility
- **NEVER** create missing config files (`m365agents.yml`) without explicit consent
- **ALWAYS** show the test link after successful provisioning
- **ALWAYS** provision after ANY change to files in `appPackage/`
- **ALWAYS** run shared agent version bump when `AGENT_SCOPE=shared`
- **NEVER** set placeholder values for environment variables — leave empty, provisioning fills them

**Preflight:** Requires `appPackage/declarativeAgent.json` and `m365agents.yml` or `teamsApp.yml`.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
