# Agent Provision

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Provision a declarative agent to an environment (deploy to M365).

## Choose personal testing or shared deployment

Explain the standard scaffold defaults **before provisioning**: `local` is
personal testing (`AGENT_SCOPE=personal`); `dev` is shared deployment
(`AGENT_SCOPE=shared`). Resolve the project path and selected environment from
the user's intent, asking only if the intended outcome is unclear.
Inspect the effective lifecycle configuration and selected env file under the
configured `environmentFolderPath` (default `./env`). Custom projects can use
different names or scope settings; never infer scope from the name, silently
replace configuration, or invent a `--scope shared` provision option.

For a share request, first follow **Shared deployment readiness** in
`references/wiqd-core/share.md`: confirm additional cloud preparation when
needed and do not re-provision an already-ready shared deployment.
For standalone plugins, retain these environment/confirmation rules and
applicable version handling, but use `wiqd plugin validate` and
`wiqd plugin provision` throughout. Keep the same explicit `--path` and `--env`.

## Validation Gate — MANDATORY

Provisioning is **blocked** until the manifest validates clean. Complete any
authorized shared-version preparation below before this validation:

1. Run `wiqd agent validate --json --skill wiqd --env <environment> [--path <path>]` as a precondition, using the same environment and project path that will be provisioned.
2. **PASS** → proceed. **FAIL** → stop, surface diagnostics, do NOT provision.
3. On failure, report the diagnostics and stop this provisioning flow. Route
   repairs through agent-validate rather than editing or retrying here.

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

1. Check the effective deployment scope and provisioning IDs in the target env
   file under the configured environment folder. If **shared** and already
   provisioned, run the [Shared Agent Version Bump](#shared-agent-version-bump)
   flow before validation. Do not bump a new environment merely to share it.
2. Complete the validation gate above against the resulting files.
3. Run `wiqd agent provision --json --skill wiqd --env <env> [--path <path>]`
4. Read `M365_TITLE_ID` from `.env.<env>` under the project's configured
   environment folder (`env/.env.<env>` with the default `./env` folder).
5. Present the test link: `https://m365.cloud.microsoft/chat?titleId={M365_TITLE_ID}`

## Bundled Reference Preflight

Provision builds the app package that it uploads, so it applies the same extension-owned reference
check as `wiqd agent package` before the fx-core provision method starts:

- declarative-agent manifests come from
  `appPackage/manifest.json#copilotAgents.declarativeAgents[].file`, not a fixed filename;
- a hand-edited DA-only `agent_skills[].folder` requires
  `wiqd config flags set agent-skills true` unless the same folder is already included by a
  top-level Cowork `agentSkills[]` registration;
- local `worker_agents[].file` is rejected; use a canonical published `worker_agents[].id`;
- missing, malformed, absolute, traversing, and symlink-escaping references fail without mutating
  the project or invoking the lifecycle SDK.

DA Chat and top-level Cowork skill sets remain independent. Never add an unrelated duplicate
registration merely to bypass the flag check.

## Shared Agent Version Bump

When re-provisioning an already-provisioned **shared** agent
(`AGENT_SCOPE=shared` and a populated `M365_TITLE_ID`), prepare its version before
validation:

1. Check all env files for `TEAMS_APP_VERSION`. If missing:
   - Read current version from `appPackage/manifest.json`
   - Add `TEAMS_APP_VERSION=<version>` to every env file that lacks it
   - Update `manifest.json` to use `"version": "${{TEAMS_APP_VERSION}}"`
2. Bump the **patch** component in the target env file (e.g., `1.0.0` → `1.0.1`)
3. Only bump the target env file — others keep their current version

## Environment Strategy

| Environment | Purpose                   |
| ----------- | ------------------------- |
| `local`     | Personal testing (default) |
| `dev`       | Shared deployment (default) |
| `staging`   | Pre-production validation |

## Critical Rules

- **NEVER** provision when validation returned FAIL
- Only the explicitly authorized shared-version preparation above may edit
  version fields here; route validation fixes through agent-validate.
- **NEVER** create missing config files (`m365agents.yml`) without explicit consent
- **ALWAYS** show the test link after successful provisioning
- When returning to an explicitly requested or confirmed provisioning flow after
  files in `appPackage/` changed, revalidate before provisioning. This rule does
  not authorize provisioning after an ordinary edit.
- Apply shared-version preparation when re-provisioning an existing shared
  deployment, then validate the resulting files before provisioning.
- **NEVER** set placeholder values for environment variables — leave empty, provisioning fills them

**Preflight:** Requires `appPackage/manifest.json` and `m365agents.yml` or `teamsApp.yml`;
declarative-agent files are discovered through the app manifest.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
