---
title: Agent component pipeline setup
description: Prepare WIQD authentication and lifecycle commands for an existing CI/CD system.
---

# Set up agent-component development CI/CD

The plugin is the app package you ship; a declarative agent is an optional
component. This page documents the shipped **agent-project** `agent-ci-cd`
workflow and its agent-specific command body, not a plugin-aware pipeline
generator. Do not apply that executable body unchanged to a `wiqd plugin`
project. For plugin commands and their validation, environment, and publishing
requirements, see [Build a Plugin](/getting-started/build-a-plugin/).

The installed **wiqd skill** helps prepare WIQD's part of your pipeline:
authentication, project/environment inputs, lifecycle commands and result handling.
It includes focused GitHub Actions and Azure Pipelines snippets for those WIQD
steps. Use a related platform skill for broader pipeline setup, runners,
secret-store administration and release controls, not for WIQD's auth contract.

For example, ask:

> Prepare WIQD CI/CD for `agents/helpdesk` in environment `dev`. Explain
> the supported authentication choices and commands to validate, provision,
> package and submit to our org catalog. Include GitHub Actions step snippets
> using username/password authentication.

The workflow adapts the WIQD snippets to your selected platform and auth mode.
Use the platform's related skill for the surrounding pipeline. Setup does not
create remote pipelines, store secrets, grant permissions,
deploy or publish on your behalf.

The `agent-ci-cd` workflow ships in the marketplace plugin. CLI installation or
extension activation does not refresh an installed host plugin; use your host's
[marketplace installation flow](/getting-started/installation/).

## Prepare WIQD and the project

Use an existing agent project with its lifecycle files and non-secret environment
configuration. Choose an exact approved WIQD release, Node.js 24.15.0 or later,
the project path, lifecycle environment and intended operations. Check the
installed version with `wiqd --version`.

On a fresh runner, use the [direct-npm-first bootstrap](/getting-started/installation/#fresh-ci-runners-explicit-wiqd-terms-acceptance).
After reviewing the current terms, the job owner may explicitly configure
`wiqd eula accept wiqd --yes --json`. This host-only opt-in is not installation
consent, authentication, or downstream Work IQ/Eval acceptance. Do not start
with the web installer's fresh unattended consent prompt.

Retain real project build/tests. Declarative projects have no universal compile
command; `wiqd plugin package` produces their distributable ZIP.

## Deploy WIQD's own plugin from this repository

The manually queued repository pipeline
`.azuredevops/pipelines/wiqd-plugin-m365.yml` builds the checked-out CLI and
composes WIQD's complete `3p/public-stable` plugin, then imports, validates and
provisions it for an experimental M365 deployment. The provision lifecycle
packages and deploys; afterward the pipeline retains that generated ZIP without
running `wiqd plugin package` again. It consumes
the public `wiqd eula accept wiqd --yes --json` command above; it does not
provide a separate EULA implementation or require delegated credentials for
host acceptance. The job owner must review the terms and authorize both
acceptance and deployment before queuing.

This repository pipeline supports **refresh-token authentication only**; there is
no `authMode` selector or password fallback. Configure `M365_REFRESH_TOKEN` as a
protected secret pipeline variable and `M365_TENANT_ID` as the target tenant GUID.
Follow the refresh-token setup guidance below, including using a token issued
for the supported public client. Do not configure `M365_ACCOUNT_NAME` or
`M365_ACCOUNT_PASSWORD` for this pipeline. Missing, blank or unresolved required
inputs, a non-GUID tenant or any password input stop cloud lookup/provisioning.
Set `appName`, `appVersion` and approved
HTTPS `privacyUrl`, `termsUrl` and `websiteUrl` values. Increment `appVersion`
when updating an existing app; the pipeline does not increment it automatically.
The composed plugin version comes from the checked-out repository's `VERSION`.

Leave `existingAppId` as `none` for unique, exact case-sensitive name discovery,
or supply an independently verified Teams app GUID to bypass discovery.
Name-based reuse requires app details to confirm the deployment tenant.
Missing, invalid or conflicting tenant evidence stops discovery; it does not
mean the app is absent. Zero accessible matches permits creation, not proof
that no such app exists anywhere in the tenant. For a new target, the pipeline
first creates only its Teams app identity using the pinned SDK and binds the
returned GUID before import and provision. This does not yet upload WIQD's
payload or install its M365 title. Existing targets are not recreated.
An uncertain identity-creation result stops the run and is not retried.

Local validation explicitly uses `wiqd plugin validate --mode source --env dev`
with the project path. The default `package` mode requires an existing ZIP and
uploads it; source checks do not certify the ZIP or prove runtime readiness.
Only cloud identity lookup/creation, provision and a read-only version-conflict diagnostic receive
delegated credentials.

If provisioning reports that the new title needs a higher version, the error
includes the submitted `appVersion` and attempts one read-only M365 lookup for the
current deployed version. It reports `unavailable` if the version cannot be
verified; it does not substitute the Developer Portal draft version or expose
the raw response. Inspect the target, then queue a new run with a version higher
than the deployed version. The pipeline neither increments the version nor
retries provision automatically.

After successful provision, the pipeline copies the lifecycle's app-package ZIP
and publishes it with an integrity receipt, not the project, environment files,
credentials or acceptance records. It verifies the package output matches the
deployment input and does not build a second ZIP for retention. The receipt
records package provenance and `deploymentStatus: not-verified`, not independent
runtime or exact HTTP-upload verification. This flow does not submit the app
to the organization catalog.

Changed source inputs or identity stop the applicable phase; missing, empty or
changed ZIP bytes prevent retention. Failed provision stops artifact publication,
so a downloadable package is not guaranteed for failed deployments. If retention
or artifact publication fails afterward, deployment may already have succeeded;
that failure does not roll it back. Inspect the target before starting another
run after any uncertain mutation; the pipeline does not replay it automatically.

## Configure lifecycle authentication

Core-backed provision, publish and share operations, including corresponding
plugin lifecycle commands, support **both username/password and refresh-token
authentication**. Choose one with your tenant owner.

| Mode | Process-environment inputs |
| --- | --- |
| Both | `CI_ENABLED=true` exactly; generic `CI=true` is insufficient |
| Username/password | Nonempty protected `M365_ACCOUNT_NAME` and `M365_ACCOUNT_PASSWORD`; `M365_REFRESH_TOKEN` entirely absent. Optional `M365_TENANT_ID` accepts a tenant ID/domain; omission uses `organizations`, and `common`/`consumers` are rejected. |
| Refresh token | Nonempty protected `M365_REFRESH_TOKEN` and a required tenant GUID in `M365_TENANT_ID`; both password inputs entirely absent, including empty definitions. |

Password mode requires no refresh-token bootstrap. For refresh-token mode only,
obtain the token locally in a private terminal and store it directly in your
approved secret store. Follow [Pipeline authentication](/getting-started/ci-cd-authentication/)
for bootstrap, renewal, policy limits and troubleshooting.

Use the snippets below to inject the selected credential names into the
authenticated process environment. Never commit or paste secret values, pass
them in command arguments, publish them as artifacts or expose them to untrusted
code. Run lifecycle commands directly, not `wiqd auth login` in CI. Missing,
mixed or rejected credentials must stop, not trigger another identity.

These delegated credentials do not bypass MFA, Conditional Access, consent or
permissions. They do not authenticate Work IQ, eval, other extensions or arbitrary Azure/SPFx
drivers. Qualify the intended release, runner and a non-production operation
before production; successful bootstrap alone is not proof of downstream access.

## Choose the WIQD operations

The generic org-catalog sequence is:

| Order | WIQD operation |
| --- | --- |
| Validate | Static manifest validation, without deployment credentials for untrusted checks |
| Provision | Deploy using the explicit project path and lifecycle environment |
| Revalidate and package | Check the provisioned workspace and produce the app ZIP |
| Publish | Submit to the **org admin catalog**, subject to administrator approval |

Use explicit `--path`, `--env` and `--json` flags. The installed workflow includes
a WIQD-only command-body example with native-exit, JSON and package-output
checks, plus provider-specific steps that invoke it. Select only the
operations needed. Sharing requires explicit audience authorization; destructive
cleanup is not an automatic stage.

Offline source validation is not final-package validation, eval, certification or permission to
publish. Org-catalog submission is not public Marketplace publication.

### Partner Center is a separate authentication path

`wiqd publish pc` uses the Marketplace provider, not the core pipeline credentials
above. `--authorize-submit` is submission consent, not a clean-runner sign-in
mechanism. This build requires a previously established Marketplace session and
accessible protected OS storage under the runner's user. Core username/password
and refresh-token inputs do not establish it. Ephemeral runners can validate and
package, then hand publishing to an authenticated operator. See
[Marketplace authentication in automation](/getting-started/publish-to-partner-center/#marketplace-authentication-in-automation)
for the supported boundary and setup.

## Wire authentication and commands into the pipeline

Run WIQD commands directly in GitHub Actions `run:` or Azure Pipelines `pwsh:`
steps, or use optional project-owned scripts for reuse. Neither creating a
separate script nor asking the installed skill to generate one is required.

The snippets below illustrate the optional-script approach with
`.ci/wiqd-agent.ps1`. Its example command body validates, provisions, revalidates,
packages and publishes, stopping on native/JSON errors or missing package output.
To inline it instead, replace the script invocation with that command body,
retaining the `env` bindings, Azure macro checks and final `exit $LASTEXITCODE`.
The file is a project-owned example, not a script installed by the CLI.

Insert one of these **step snippets** into an existing trusted release job after
checkout, approved WIQD installation and required project build/tests. Use
PowerShell 7 from the checkout root. Set the project path and lifecycle environment
directly in the commands using existing `--path` and `--env` options, for example
`--path ./agents/helpdesk --env dev`. No additional pipeline variables are
needed for these values. Store credentials as secrets. Do not inherit
the other auth mode's keys at job/pipeline scope, even as empty values.

### GitHub Actions: username/password

```yaml
- name: Run WIQD agent lifecycle
  shell: pwsh
  run: |
    & ./.ci/wiqd-agent.ps1
    exit $LASTEXITCODE
  env:
    CI_ENABLED: 'true'
    M365_ACCOUNT_NAME: ${{ secrets.M365_ACCOUNT_NAME }}
    M365_ACCOUNT_PASSWORD: ${{ secrets.M365_ACCOUNT_PASSWORD }}
```

### Azure Pipelines: username/password

Azure secret variables require explicit `env` mapping. The check refuses
unresolved variable macros before executing the WIQD script.

```yaml
- pwsh: |
    foreach ($name in @('M365_ACCOUNT_NAME', 'M365_ACCOUNT_PASSWORD')) {
      if ([Environment]::GetEnvironmentVariable($name) -match '^\$\([^)]+\)$') { throw "Define Azure pipeline variable $name before running WIQD." }
    }
    & ./.ci/wiqd-agent.ps1
    exit $LASTEXITCODE
  displayName: Run WIQD agent lifecycle
  env:
    CI_ENABLED: 'true'
    M365_ACCOUNT_NAME: $(M365_ACCOUNT_NAME)
    M365_ACCOUNT_PASSWORD: $(M365_ACCOUNT_PASSWORD)
```

### Refresh-token alternative

Use the same lifecycle command body, inline or scripted, but **remove both password keys** and add these
bindings instead. In the Azure step, replace the two password names in the
macro-check list with `M365_TENANT_ID` and `M365_REFRESH_TOKEN` too.
The installed workflow supplies complete step snippets for both modes/providers.

| Process input | GitHub Actions `env` value | Azure Pipelines `env` value |
| --- | --- | --- |
| `M365_TENANT_ID` | `${{ vars.M365_TENANT_ID }}` | `$(M365_TENANT_ID)` |
| `M365_REFRESH_TOKEN` | `${{ secrets.M365_REFRESH_TOKEN }}` | `$(M365_REFRESH_TOKEN)` |

Keep `CI_ENABLED: 'true'` and the script's project/environment values. Use a tenant GUID
and a locally obtained refresh token. Missing GitHub secrets become empty inputs;
the WIQD script refuses them. Secrets belong in `env`, not interpolated into
`run`/`pwsh` text. These examples do not create platform release controls or
authorize a deployment.

## Preserve state and handle failures

Keep related commands on the same project/environment state and securely retain
stable resource IDs between runs. A fresh checkout does not make provisioning
idempotent. Never preserve state by publishing env/user-secret files, auth caches
or the entire project.

Continue only after native exit success, a valid JSON success envelope and
expected package output. Configure WIQD host `--yes` only with explicit job-owner
authorization; downstream EULA consent remains outside CI. Inspect existing
resources after timeout or uncertainty before any manually approved rerun;
do not automatically retry mutations. WIQD does not rotate your secret store.

The platform integration handoff contains the WIQD release/extensions, commands,
working directory, credential names/scope, state ownership, expected package/
receipt outputs and remaining qualification. Your platform skill owns the
broader setup surrounding these WIQD steps. Local example checks are not
evidence that a live pipeline succeeded.

## See also

- [Pipeline authentication](/getting-started/ci-cd-authentication/)
- [Environments](/concepts/environments/)
- [Exit codes and output](/concepts/exit-codes-output/)
- [Agent package](/cli/plugin-package/)
