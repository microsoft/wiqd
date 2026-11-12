# Plugin Provision

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Provision a plugin, with or without a declarative agent, to an environment (deploy to M365).

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
For standalone plugins, default to shared `dev` without asking the user to
choose or confirm that default. Preserve an explicit personal/`local` or custom
environment and any environment already selected for the current workflow.
Retain the configuration checks, mutation-consent rules, and applicable version
handling, but use `wiqd plugin validate --mode source` and `wiqd plugin provision`
throughout. Keep the same explicit `--path` and `--env`; direct CLI defaults are
unchanged. Shared scope does not itself authorize sharing or publication.

## Validation Gate — MANDATORY

In this workflow, provisioning is **blocked** until saved source validates clean.
Complete any authorized shared-version preparation below before this validation:

1. Run `wiqd plugin validate --mode source --json --skill wiqd --env <environment> --path <path>` as a precondition, using the same environment and explicit project path that will be provisioned.
2. **PASS** → proceed. **FAIL** → stop, surface diagnostics, do NOT provision.
3. For authorized repairs, use `workflows/validation.md` and return only after same-mode source revalidation passes. Do not build a ZIP merely to run this gate.

This is a workflow gate, not a new mandatory backend gate on direct provision calls. Source
validation has no ZIP identity; provision builds its own upload and is not claimed to upload any
previously validated ZIP. Missing deployment IDs that provision creates are not pre-provision inputs.

## Command

```bash
wiqd plugin provision --json --skill wiqd --env <environment> [--path <path>]
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
3. Run `wiqd plugin provision --json --skill wiqd --env <env> [--path <path>]`
4. Read `M365_TITLE_ID` from `.env.<env>` under the project's configured
   environment folder (`env/.env.<env>` with the default `./env` folder).
5. For every plugin project, including a declarative-agent project, present the successful command's returned
   `data.deepLink` as **Cowork install/test**:
   `https://copilot.cloud.microsoft/plugins?pluginsTab=cowork&coworkPage=detail&coworkPluginId=<M365_TITLE_ID>`.
   Preserve the returned identifier, including any `T_` prefix.
   Also present the returned `data.chatLink` as **Chat install/test**:
   `https://copilot.cloud.microsoft/plugins?titleId=<M365_TITLE_ID>&pluginsTab=chat`.
   Both links use the same API-returned title ID without changing `T_` or `P_`.
   This includes personal/shared plugins and plugins containing a DA. Never
   substitute a Chat URL or `SHARE_LINK` for a plugin's Cowork link. If either
   returned link is missing or not its expected route, report it as unavailable or unexpected;
   never fabricate it from `TEAMS_APP_ID` or provision again just to get a link.

## Bundled Reference Preflight

Provision builds the app package that it uploads, so it applies the same extension-owned reference
check as `wiqd plugin package` before the fx-core provision method starts:

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
- **ALWAYS** show the appropriate test link after successful provisioning, or
  explicitly report that it is unavailable; never invent a missing link.
- When returning to an explicitly requested or confirmed provisioning flow after
  files in `appPackage/` changed, revalidate before provisioning. This rule does
  not authorize provisioning after an ordinary edit.
- Apply shared-version preparation when re-provisioning an existing shared
  deployment, then validate the resulting files before provisioning.
- **NEVER** set placeholder values for environment variables — leave empty, provisioning fills them

**Preflight:** Requires `appPackage/manifest.json` and `m365agents.yml`;
declarative-agent files are discovered through the app manifest.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
