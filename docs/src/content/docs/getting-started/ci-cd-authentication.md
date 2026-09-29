---
title: CI/CD Authentication
---

# CI/CD Authentication

Username/password and refresh-token authentication are for **trusted CI/CD pipeline
runs using the core/fx-core backend**, not general WIQD sign-in. For local development,
use [interactive authentication](/getting-started/authentication/). The local refresh-token
bootstrap command is an exception only in where it runs: it prepares a pipeline
secret and does not sign you into your normal WIQD developer session.

These modes support core-backed `wiqd agent provision`, `wiqd agent publish`, and
`wiqd agent share`, and corresponding plugin lifecycle operations. They do not
authenticate Work IQ, eval, other extensions, or arbitrary Azure/SPFx drivers. Those require their
own credentials.

## Configure a Trusted Pipeline

Use a configured agent project, and grant the
pipeline's user the permissions required by the operation. Supply credentials as
environment variables from your pipeline secret store, never literal values in
committed YAML, command arguments, or job logs. Never expose them to untrusted
pull-request jobs.

Both modes require `CI_ENABLED=true` exactly, with lowercase `true`.
Generic `CI=true` alone does not enable them. Select only one credential mode:

| Mode | Environment inputs |
| --- | --- |
| Username/password | `M365_ACCOUNT_NAME`, `M365_ACCOUNT_PASSWORD`; optional `M365_TENANT_ID` |
| Refresh token | `M365_REFRESH_TOKEN`, required tenant GUID in `M365_TENANT_ID` |

Invoke the lifecycle command directly once the secret store has injected the inputs:

```powershell
$env:CI_ENABLED = "true"
wiqd agent provision --env dev
```

**Do not run `wiqd auth login` in CI.** It requires a real terminal, regardless of
these environment inputs. Token acquisition occurs on demand through the core
provider. `wiqd auth status` is not TTY-gated and can acquire/renew tokens silently,
but its result does not prove access to every lifecycle resource.

## Username/Password Mode

Inject nonempty `M365_ACCOUNT_NAME` and `M365_ACCOUNT_PASSWORD`; leave
`M365_REFRESH_TOKEN` entirely absent. A partial password pair fails before token
acquisition. With no refresh-token input and neither password value populated,
legacy developer selection remains unchanged; pipelines should not rely on it.

`M365_TENANT_ID` may be a tenant ID or domain. If omitted, password acquisition uses
`organizations`; `common` and `consumers` are rejected. This optional/default tenant
behavior differs from refresh-token mode's required GUID.

The provider does not persist a password-derived account/token session. Removing
the password inputs or disabling `CI_ENABLED` stops selecting this mode. Logout
does not remove caller-owned environment variables. The existing interactive
override remains available for developer compatibility, not as pipeline recovery.

This is not a blanket recommendation to use passwords. If MFA or Conditional
Access prevents the password grant, resolve the authentication approach with your
tenant administrator; WIQD does not bypass those controls.

## Refresh-Token Mode

:::caution[Implementation in progress: release validation pending]
The development implementation has automated coverage, but is not released or
declared fully validated. Security/configuration acceptance, live app-registration
and consent checks, and Windows/macOS/Linux validation remain pending.
:::

### Obtain a Token Locally

Run from a private, non-recorded interactive terminal outside CI:

```text
wiqd auth token get --tenant <tenant-id> --show-token
```

| Option | Description |
| --- | --- |
| `--tenant <tenant-id>` | Required Entra tenant GUID, not a domain, URL, or `common`. |
| `--show-token` | Request a single terminal disclosure after human confirmation. |
| `--json` | Rejected with exit `2` before authentication; not an export format. |
| `--verbose` | Sanitized diagnostics only, never tokens or the serialized cache. |

Both stdin and stdout must be TTYs, with a usable browser and reachable loopback
callback. Neither `CI_ENABLED` nor `CI` may be exactly `true`. No project, ATK
binary, or prior `wiqd auth login` is needed. Headless bootstrap is not supported.

Before opening the browser, the command warns about disclosure and requires `y`
or `yes`; `--show-token` is not consent, and `--yes` cannot bypass confirmation.
It uses a fresh non-broker browser/PKCE flow and memory-only MSAL cache, never your
existing developer or Windows broker cache. Success reveals the token once;
ordinary output contains only tenant/revealed metadata, not tokens or cache data.

:::caution[Bearer secret]
Terminal scrollback, transcripts, recordings and screenshots can retain the token.
Manually store it in an approved CI secret store. Do not paste it into chat,
command arguments, committed files, or job logs. WIQD tenant checks constrain its
requests; they do not restrict a stolen token intrinsically to one tenant or operation.
:::

### Inject the Refresh Token

Supply `CI_ENABLED=true`, a tenant GUID in `M365_TENANT_ID`, and a nonempty
`M365_REFRESH_TOKEN` from the secret store. Remove `M365_ACCOUNT_NAME` and
`M365_ACCOUNT_PASSWORD` entirely: either variable's presence conflicts, even if
empty. A present empty/whitespace RT, disabled CI, or invalid tenant fails closed.
There is no password, browser, broker, developer-cache or interactive-override fallback.

### Renewal and Replacement

Each process imports the original secret once and silently acquires access tokens
with the same memory-only account/cache. Replacement RTs remain in that process.
WIQD does not update the environment or secret store, persist CI tokens, or share
caches between jobs. Every later process starts from the original managed secret.

Lifetime is not guaranteed. When human sign-in or consent is required, resolve
policy/consent issues, rerun local bootstrap, and manually replace the CI secret.
Replacing a token alone may not fix an authorization denial. Check operation state
before rerunning a deployment; authentication does not replay mutations.

Core RT logout clears memory and closes that provider instance, without changing
developer caches, environment inputs, or pipeline secrets. It does not revoke the
token server-side; a new process can use the configured secret again. Other
providers participating in logout keep their own cleanup behavior.

## Consent and Resource Limits

Refresh bootstrap requests only AuthSvc `Region.ReadWrite`. Successful export does
not prove access to all audiences. Both pipeline modes remain subject to delegated
consent, user permissions, MFA, Conditional Access and service policy; neither is
an app-only/workload identity. Further resources need the client's existing
delegated consent/preconsent and the user's applicable permissions and roles.

| Core resource | Delegated scope/use |
| --- | --- |
| AuthSvc | `https://api.spaces.skype.com/Region.ReadWrite` for status/region discovery and RT bootstrap. |
| Teams Developer Portal | `https://dev.teams.microsoft.com/AppDefinitions.ReadWrite` for basic declarative-agent create/update and package validation. |
| MOS | `https://titles.prod.mos.microsoft.com/.default` for basic DA extension and sharing. |
| Graph publishing | `AppCatalog.ReadWrite.All` for tenant app-catalog publish. |
| Graph sharing lookup | `Application.ReadWrite.All`, `TeamsAppInstallation.ReadForUser`; `GroupMember.Read.All` for groups. |

Tokens are requested separately per resource. Graph consent does not establish
TDP or MOS consent. This matrix describes the pinned dependency, not live acceptance.
Bootstrap does not request every permission at once.

## Failures and Cancellation

Password-mode failures retain the existing lifecycle command's error handling;
the refresh-specific codes below do not redefine that behavior.

- **RT bootstrap:** configuration/terminal/JSON errors return `2`;
  authentication/export/disclosure failure returns `1`; declined confirmation,
  cancelled consent, Ctrl+C or the five-minute timeout returns `130`.
- **RT lifecycle:** malformed inputs return `2` / `RefreshTokenConfiguration`;
  invalid grant, interaction/consent required, account/tenant mismatch or closed
  session returns `2` / `AUTH_REQUIRED`. Authorization/generic auth failure returns
  `1`; cancellation returns `130`.

Transient status failures may remain inconclusive until the authoritative operation
runs; they are not automatically token expiry. RT cancellation prevents late usable
state or disclosure and closes the bootstrap listener, but does not guarantee an
already-started MSAL network request is aborted. Server-side revocation belongs to
the identity provider/administrator.

## See Also

- [Interactive authentication](/getting-started/authentication/)
- [Refresh-token bootstrap reference](/cli/reference/#wiqd-auth-token-get)
- [Provision](/cli/reference/#wiqd-agent-provision)
- [Publish](/cli/reference/#wiqd-agent-publish)
- [Share](/cli/reference/#wiqd-agent-share)