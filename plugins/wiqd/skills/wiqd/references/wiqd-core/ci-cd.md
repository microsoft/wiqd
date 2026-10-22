# WIQD agent lifecycle in CI/CD

Read `workflows/agent-ci-cd.md` first. This reference owns only WIQD's process
inputs, authentication and commands, including focused GitHub Actions and Azure
Pipelines integration snippets. Use a related platform skill for broader pipeline
setup rather than expanding these snippets into a platform tutorial.

## Prerequisites and inputs

Install the exact approved WIQD release on Node.js 24.15.0 or later and check
`wiqd --version --skill wiqd --workflow agent-ci-cd`. Use the existing agent
project and its lifecycle/environment files. Private feed access, if needed,
is installation authentication, not delegated lifecycle authentication.

| Input | Meaning |
| --- | --- |
| `CI_ENABLED` | Native auth input: exactly `true`, not generic `CI=true` |
| `M365_ACCOUNT_NAME`, `M365_ACCOUNT_PASSWORD` | Username/password mode: both nonempty protected inputs; `M365_REFRESH_TOKEN` absent |
| `M365_REFRESH_TOKEN` | Refresh-token mode: nonempty protected input; both password variables absent, including empty definitions |
| `M365_TENANT_ID` | Refresh token: required tenant GUID. Password: optional ID/domain, defaults to `organizations`, rejects `common`/`consumers` |

**Both username/password and refresh-token authentication are supported.**
Password mode requires no refresh-token bootstrap. For refresh-token mode only,
the human runs `wiqd auth token get --tenant <tenant-guid> --show-token` locally
in a private terminal and puts the disclosed result directly in their secret store.
Neither bootstrap nor `wiqd auth login` belongs in CI.

Use the snippets below to map the chosen credential names from the owner's secret
store to the authenticated process environment. Never pass secrets as arguments,
commit them, include them in handoff text or expose them to untrusted code.
Do not mix modes, rely on a developer session, bypass tenant policy or switch
identities after rejection. Live runner/account/service qualification is separate
from example validation.

## WIQD command sequence

Preserve any real project build/tests before the sequence. Declarative projects
have no universal compilation step. The following PowerShell 7 example is a
WIQD command body, not a complete pipeline.
Run WIQD commands directly in GitHub Actions `run:` or Azure Pipelines `pwsh:`
steps, or use optional project-owned scripts for reuse. Neither a separate file
nor skill-assisted script generation is required.
The snippets below demonstrate the optional-script approach: save the body as
`.ci/wiqd-agent.ps1`. For inline execution, replace that script invocation with
the body below, retaining the step's `env` bindings, Azure macro checks and final
`exit $LASTEXITCODE`.
It assumes the runner and selected
authentication inputs are already prepared; it does not install or configure them.
Running it mutates the selected environment and submits to the **org admin catalog**,
so execute only after explicit release authorization.
Replace `./agents/helpdesk` and `staging` below with your existing project path
and lifecycle environment. These are ordinary `--path`/`--env` values; no
additional pipeline environment variables are needed.

```powershell
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
function Invoke-WiqdJson([string]$Name, [string[]]$Arguments) {
  $text = & wiqd @Arguments
  $code = $LASTEXITCODE
  $text | Set-Content -LiteralPath "$Name.json" -Encoding utf8
  if ($code -ne 0) {
    [Console]::Error.WriteLine(($text -join "`n"))
    exit $code
  }
  $result = ($text -join "`n") | ConvertFrom-Json -NoEnumerate
  if ($result -isnot [pscustomobject] -or $result.status -cne 'success') { throw "WIQD $Name did not return a success envelope." }
  return $result
}
if ($env:CI_ENABLED -cne 'true') { throw 'CI_ENABLED must be exactly true.' }
$project = './agents/helpdesk'
$environment = 'staging'
if (-not (Test-Path -LiteralPath $project -PathType Container)) { throw 'Project directory is missing.' }
if ($environment -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw 'Set a valid lifecycle environment name.' }
if (Test-Path Env:M365_REFRESH_TOKEN) {
  $tenant = [guid]::Empty
  if (-not [guid]::TryParse($env:M365_TENANT_ID, [ref]$tenant)) { throw 'Set the intended tenant GUID for refresh-token mode.' }
  if ([string]::IsNullOrWhiteSpace($env:M365_REFRESH_TOKEN)) { throw 'Configure the protected refresh-token secret.' }
  if (Test-Path Env:M365_ACCOUNT_NAME) { throw 'Remove M365_ACCOUNT_NAME for refresh-token mode.' }
  if (Test-Path Env:M365_ACCOUNT_PASSWORD) { throw 'Remove M365_ACCOUNT_PASSWORD for refresh-token mode.' }
} else {
  foreach ($name in @('M365_ACCOUNT_NAME', 'M365_ACCOUNT_PASSWORD')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { throw "Configure the protected $name secret for username/password mode." }
  }
}
$common = @('--path', $project, '--env', $environment, '--json', '--skill', 'wiqd', '--workflow', 'agent-ci-cd')
Invoke-WiqdJson 'validate' (@('agent', 'validate') + $common) | Out-Null
Invoke-WiqdJson 'provision' (@('agent', 'provision') + $common) | Out-Null
Invoke-WiqdJson 'validate-provisioned' (@('agent', 'validate') + $common) | Out-Null
Invoke-WiqdJson 'package' (@('agent', 'package', '--output', "$PWD/agent.zip") + $common) | Out-Null
if (-not (Test-Path -LiteralPath agent.zip -PathType Leaf)) { throw 'Package output is missing.' }
Invoke-WiqdJson 'publish' (@('agent', 'publish') + $common) | Out-Null
```

For secret-free static checks, run only `agent validate` with the explicit project,
environment and `--json` flags, without deployment credentials. Static validation
is not deep validation, eval or permission to publish.

The selected lifecycle credential also serves supported core-backed share and
corresponding plugin provision/publish/share operations. Add only explicitly
requested operations and approved audiences, following their own command references.
It does not authenticate arbitrary Azure/SPFx drivers, Work IQ, eval or other
extensions. Do not add destructive cleanup as a default stage.

## GitHub Actions snippets

Choose **one** authentication mode. Insert its step into an existing approved
release job, after checkout and installation of the approved WIQD version.
Use PowerShell 7 on the runner and run from the checkout root. Set the project
and lifecycle environment directly in the script above, and store the selected
mode's credentials as secrets. These are step snippets, not complete workflow files.
Do not place credentials at job/workflow scope or inherit the other mode's
variables; remove unused credential keys rather than defining them as empty.

### Refresh-token mode

Set the non-secret `M365_TENANT_ID` variable to the intended tenant GUID and
store the locally bootstrapped token as secret `M365_REFRESH_TOKEN`.

```yaml
- name: WIQD agent lifecycle with refresh-token authentication
  shell: pwsh
  run: |
    & ./.ci/wiqd-agent.ps1
    exit $LASTEXITCODE
  env:
    CI_ENABLED: 'true'
    M365_TENANT_ID: ${{ vars.M365_TENANT_ID }}
    M365_REFRESH_TOKEN: ${{ secrets.M365_REFRESH_TOKEN }}
```

### Username/password mode

Store `M365_ACCOUNT_NAME` and `M365_ACCOUNT_PASSWORD` as secrets. This step needs
no token bootstrap. It omits `M365_TENANT_ID` to use `organizations`; add that
non-secret variable only when selecting a tenant ID/domain explicitly.

```yaml
- name: WIQD agent lifecycle with username/password authentication
  shell: pwsh
  run: |
    & ./.ci/wiqd-agent.ps1
    exit $LASTEXITCODE
  env:
    CI_ENABLED: 'true'
    M365_ACCOUNT_NAME: ${{ secrets.M365_ACCOUNT_NAME }}
    M365_ACCOUNT_PASSWORD: ${{ secrets.M365_ACCOUNT_PASSWORD }}
```

## Azure Pipelines snippets

Choose **one** mode in an existing approved job with the same checkout, installed
WIQD and PowerShell 7. Use the same command body, inline or in the optional script.
Define the named pipeline variables; mark credential
values secret. Azure secret variables need explicit `env` mapping. Unlike GitHub
`${{ secrets.NAME }}` / `${{ vars.NAME }}`, these snippets use Azure `$(NAME)`
macros. Undefined Azure variables can remain literal macros, so the step refuses
them before invoking WIQD. Keep secrets out of the `pwsh` body.

### Refresh-token mode

```yaml
- pwsh: |
    foreach ($name in @('M365_TENANT_ID', 'M365_REFRESH_TOKEN')) {
      if ([Environment]::GetEnvironmentVariable($name) -match '^\$\([^)]+\)$') { throw "Define Azure pipeline variable $name before running WIQD." }
    }
    & ./.ci/wiqd-agent.ps1
    exit $LASTEXITCODE
  displayName: WIQD agent lifecycle with refresh-token authentication
  env:
    CI_ENABLED: 'true'
    M365_TENANT_ID: $(M365_TENANT_ID)
    M365_REFRESH_TOKEN: $(M365_REFRESH_TOKEN)
```

### Username/password mode

This uses the same credential inputs as GitHub's password example, with the
optional tenant omitted. Do not define `M365_REFRESH_TOKEN` at any inherited scope.

```yaml
- pwsh: |
    foreach ($name in @('M365_ACCOUNT_NAME', 'M365_ACCOUNT_PASSWORD')) {
      if ([Environment]::GetEnvironmentVariable($name) -match '^\$\([^)]+\)$') { throw "Define Azure pipeline variable $name before running WIQD." }
    }
    & ./.ci/wiqd-agent.ps1
    exit $LASTEXITCODE
  displayName: WIQD agent lifecycle with username/password authentication
  env:
    CI_ENABLED: 'true'
    M365_ACCOUNT_NAME: $(M365_ACCOUNT_NAME)
    M365_ACCOUNT_PASSWORD: $(M365_ACCOUNT_PASSWORD)
```

Both providers run the identical WIQD sequence and preserve its native exit.
Missing GitHub secrets become empty inputs and fail the script's preflight.
Use a related platform skill for triggers, runner setup, secret-store administration
and release controls. Neither snippet authorizes a deployment or makes the
project's existing state/build/readiness requirements optional.

## State, outputs and failure handling

Keep related operations on the same project/environment state. Across runs, retain
stable resource IDs and securely restore/update environment state; an empty runner
does not make provisioning idempotent. Org publish rebuilds from this workspace;
the exported ZIP is not a claim that publish uploads those exact bytes.

Only retain the approved package and non-secret command receipts. Never upload
env files, user-secret files, developer caches or the checkout to preserve state.
The platform skill owns artifact publication and access configuration.

Native exit codes and valid JSON success envelopes gate progression. Preserve
failures and diagnostics; an EULA-required result stops for human consent outside
CI. WIQD does not rotate the secret store. Resolve the chosen mode's credentials
or policy rather than falling back; inspect current state after an uncertain
deployment before any manually approved rerun. Never automatically retry mutations.
