---
title: Agent development pipeline setup
description: Prepare WIQD authentication and lifecycle commands for an existing CI/CD system.
---

# Set up agent development CI/CD

The installed **wiqd skill** helps prepare WIQD's part of your pipeline:
authentication, project/environment inputs, lifecycle commands and result handling.
It includes focused GitHub Actions and Azure Pipelines snippets for those WIQD
steps. Use a related platform skill for broader pipeline setup, runners,
secret-store administration and release controls, not for WIQD's auth contract.

For example, ask:

> Prepare WIQD CI/CD for `agents/helpdesk` in environment `staging`. Explain
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

Retain real project build/tests. Declarative projects have no universal compile
command; `wiqd agent package` produces their distributable ZIP.

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

Static validation is not deep validation, eval, certification or permission to
publish. Org-catalog submission is not public Marketplace publication.

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
`--path ./agents/helpdesk --env staging`. No additional pipeline variables are
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
expected package output. Resolve EULA consent outside CI. Inspect existing
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
- [Agent package](/cli/agent/agent-package/)
