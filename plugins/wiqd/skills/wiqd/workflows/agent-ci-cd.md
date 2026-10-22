---
name: agent-ci-cd
description: >
  Prepare WIQD authentication, inputs and lifecycle commands for unattended agent
  development and org-catalog deployment in any CI/CD system.
trigger-summary: 'CI/CD, pipeline authentication, automate agent deployment'
triggers: >
  set up agent CI/CD, create an agent pipeline, GitHub Actions for my agent,
  Azure Pipelines for my agent, automate agent deployment, unattended agent deployment
routing-label: 'Agent development CI/CD setup'
routing-intent: 'Configure agent development and org-catalog deployment pipelines with WIQD authentication and lifecycle commands'
routing-order: 11
contract-version: 1
routing-requires: [agent validate, agent provision, agent package, agent publish]
---

# Agent development CI/CD setup

Prepare **WIQD's part** of a pipeline: prerequisites, authentication, commands,
state and results. Read `references/wiqd-core/ci-cd.md`. Use
`--skill wiqd --workflow agent-ci-cd` on ordinary wiqd calls.

Include the reference's WIQD-specific snippets for the chosen platform and
credential mode: secret-to-process bindings and lifecycle commands.
Explain differences between GitHub expressions and Azure variable macros.
Use an available related platform skill for broader pipeline configuration,
not as a substitute for these WIQD examples. Do not invent an installed skill name.

## 1. Resolve the intended WIQD operations

Inspect the existing project, manifests, lifecycle YAML and non-secret environment
configuration, without reading secrets. Confirm project path, exact approved
WIQD version, lifecycle environment and desired operations. Follow the
existing-project gate in `workflows/wiqd-core.md`; never replace/scaffold a project
silently. Retain real project builds/tests; declarative projects have no universal
compile command, and `agent package` produces the app ZIP.

This example targets the **org admin catalog**, not public Marketplace submission.
Resolve the destination before preparing commands. Setup does not authorize a
deployment, secret-store write, remote pipeline creation or permissions change.

## 2. Configure the owning authentication mode

**Both username/password and refresh-token authentication are supported** for
core-backed provision, publish and share, including corresponding plugin
lifecycle commands. Confirm the owner's choice; do not mix modes.

| Mode | Process-environment inputs |
| --- | --- |
| Both | `CI_ENABLED=true` exactly; generic `CI=true` is insufficient |
| Username/password | Nonempty protected `M365_ACCOUNT_NAME` and `M365_ACCOUNT_PASSWORD`; `M365_REFRESH_TOKEN` entirely absent. Optional `M365_TENANT_ID` accepts a tenant ID/domain, defaults to `organizations` and rejects `common`/`consumers`. No refresh-token bootstrap. |
| Refresh token | Nonempty protected `M365_REFRESH_TOKEN` and required tenant GUID in `M365_TENANT_ID`; both password inputs entirely absent, including empty definitions. |

For refresh-token mode only, the human bootstraps **locally in a private terminal**:

```text
wiqd auth token get --tenant <tenant-guid> --show-token
```

The human confirms disclosure and saves the result directly in their approved
secret store. Never run bootstrap in CI, capture its output, ask for credentials
in chat, copy a developer cache or run `wiqd auth login` in the pipeline.
Inject the selected credentials only into the processes performing authenticated
lifecycle operations. Do not expose them to untrusted code.

These are delegated identities subject to consent, permissions, MFA and
Conditional Access, not app-only/service-principal/managed-identity authentication.
They do not authenticate Work IQ, eval or arbitrary Azure/SPFx drivers.
Qualify the chosen release, intended runner and a non-production operation with
the tenant owner; content tests or successful token bootstrap do not prove access.

## 3. Prepare the lifecycle sequence

Use the reference's provider-neutral example:
static validate -> provision -> revalidate -> package -> org-catalog publish.
Adapt only the operations the user needs. Share uses the same lifecycle
credential but needs an explicitly approved audience; do not add destructive
cleanup or perform all mutations merely because their authentication is supported.

Use explicit project/environment flags and the same working state across related
operations. Preserve stable resource IDs and define secure state ownership
between runs; a clean checkout does not make provisioning idempotent. Do not
upload env/user-secret files, token caches or the entire workspace.

Require native exit success, a valid JSON success envelope and package
postconditions before continuing. Preserve native error codes and diagnostics;
never infer success from prose. EULA consent remains outside CI.

## 4. Adapt the WIQD pipeline snippets

Run WIQD commands directly in GitHub Actions `run:` or Azure Pipelines `pwsh:`
steps, or use optional project-owned scripts for reuse. A script file is not a
prerequisite. The reference's snippets illustrate the optional-script approach;
for inline commands, replace the script invocation with its command body,
retaining credential bindings, Azure macro checks and exit propagation.
Insert the adapted steps into the existing trusted release job.
Choose either username/password or refresh-token
bindings, never both; unused credential keys must be absent, not empty.
Keep secrets in `env`, not executable script interpolation. Preserve native-exit
propagation and Azure unresolved-macro checks. Script paths are examples, not
new CLI settings or files installed by WIQD.
Set the project path and lifecycle environment directly in the commands' existing
`--path`/`--env` arguments; do not add pipeline environment-variable prerequisites
for these values. The example `env` bindings are only native authentication inputs.

Provide the user and any related platform skill with:

- Required WIQD/Node version and extensions, project path and lifecycle environment.
- Chosen credential mode, exact environment-variable names and owning operations;
  secret values are never part of the handoff.
- WIQD command order, expected package/receipt outputs and native-exit/JSON gates.
- Environment-state ownership, no automatic mutation retry and remaining live qualification.

General triggers, runner setup, secret-store administration, approvals,
serialization and artifact publication belong to that skill, not this guidance.
Do not overwrite existing pipeline behavior or execute a release during setup.

On invalid inputs or rejected credentials, stop and resolve the selected mode's
configuration/policy; do not fall back to another identity. Refresh-token
rebootstrap is local when appropriate; WIQD does not rotate the secret store.
For an uncertain mutation, inspect the target before any manually approved rerun.

Report WIQD commands/configuration prepared, changed paths and qualification gaps.
An updated marketplace plugin delivers this workflow; CLI installation or
extension activation does not refresh the installed host skill.
