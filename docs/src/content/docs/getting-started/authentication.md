---
title: Authentication
---

# Authentication

Work IQ Dev Tools use extension-owned Microsoft identity providers for Microsoft 365 and Azure services. Commands that interact with your tenant need the appropriate provider's credentials. This guide covers normal developer sign-in. For pipeline-only username/password or refresh-token authentication, see [CI/CD Authentication](/getting-started/ci-cd-authentication/).

## How authentication works

The domain-neutral WIQD host delegates `auth login`, `auth logout`, and `auth status` to the actions declared by activated extension providers. Subprocess-backed providers run their own binaries; runtime-backed providers run in-process. Diagnostic-only providers such as the current Work IQ extension do not join login/logout. Each provider owns its identity client, token cache, and CI authentication backends. Those are extension responsibilities, not host-aggregator identity logic.

After a provider's login subprocess succeeds, Work IQ Dev Tools **verify** that an identity was actually acquired before showing a `✔` and the authenticated account — a successful exit code alone is never treated as proof of a session. Verification reads the identity out of the login output first and falls back to re-probing the provider's status only when the login output shows none; a broker-backed account can be process-local and vanish before a separate status subprocess starts, so preferring the login output avoids reporting a real sign-in as a failure.

Runtime-backed providers return a structured signed-in / signed-out / skipped / error state directly, so no separate status subprocess or output pattern is used for them. An optional project-scoped provider that has not been configured can skip ordinary aggregate login without making the other providers fail; WIQD shows that provider as skipped rather than signed in. The host reports the provider's result; it does not own that provider's client ID or token cache.

Commands that interact with your tenant—including agent and plugin provisioning and sharing, plus agent info, uninstall, and publish—check the provider's status first. When the provider definitively reports that you are signed out, the command exits with code `2` and instructions to run `wiqd auth login --interactive` instead of waiting on an invisible upstream sign-in prompt. An unavailable or inconclusive status check does not block the command.

### Provider accounts are independent

Each provider owns its own account selection, token cache, and signed-in state.
It is valid for one provider to use account A while another uses account B. It
is also valid for one row to be signed out while another is healthy. A command's
provider selection does not deactivate other activated providers, so the auth
aggregator continues to visit and report each one.

The rows from `wiqd auth status` are authoritative for the provider/account
pairing. Do not infer the provider from an application name shown by a broker or
consent dialog: providers can share client identity details. For example, this
state is internally consistent:

```text
  ✗ Provider A: not signed in — Run `wiqd auth login --interactive` to sign in.
  ✔ Provider B: signed in — account-b@contoso.com
```

The Provider A row is a truthful failure for that provider; it does not prove
that an operation using Provider B failed. Check the provider used by the
command and its corresponding status row before diagnosing the operation.

## Sign In

```bash
wiqd auth login --interactive
```

### Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--interactive` | `flag` | `false` | Allows each provider to use its interactive path and extends the per-provider timeout. It does not guarantee an account picker or a fresh account: a provider may reuse a usable cached session. Does not change the terminal requirement — see below. |
| `--tenant <tenant-id>` | `string` | omitted | Supplies one nonzero tenant GUID only to runtime providers whose manifest explicitly declares the tenant input. Other providers continue their ordinary login. This does not coordinate or synchronize tenants across providers. |

### Examples

Resolve sessions for all active providers using each provider's default mode:

```bash
wiqd auth login
```

An optional provider that requires project setup may be reported as skipped in
this default mode. The command still succeeds when at least one other provider
signs in and none fail. If every provider is skipped, login fails closed because
no usable session was established.

Allow each active provider to use its interactive path:

```bash
wiqd auth login --interactive
```

When Marketplace publishing is unconfigured, generic `--interactive` login
offers **Skip Marketplace setup** as the default choice. Skipping reports that
optional provider as not applicable and continues signing in to later
providers. Choose directory discovery or another directory to start publisher
setup; Cancel still cancels the aggregate login. On Windows, Marketplace setup
prefers WAM when it is available.

When Marketplace publishing is enabled and you already know the seller tenant
GUID, explicitly target setup without entering the Skip/directory menu:

```bash
wiqd auth login --interactive --tenant d795438c-7449-40e1-a515-a6a01862a861
```

WIQD validates and normalizes the GUID before provider discovery. Only a runtime
login handler that explicitly declares the tenant input receives it. If no
active provider accepts the input, the command fails before any provider runs.
The selected provider still owns external-browser sign-in, identity and tenant
verification, final confirmation, and secure persistence.

When a valid `partner-center.json` already exists, `--tenant` is an assertion,
not an override: a matching tenant follows the existing cache-first flow, while
a different tenant fails before secure-store or network access. During
first-run setup, rejecting the returned seller normally permits another
directory/account attempt; with `--tenant`, retry remains pinned to that tenant
and permits another account there. Restart with another tenant value, or omit
the option, to select a different directory.

### `wiqd auth login` requires a real terminal

The `wiqd auth login` aggregator requires a human at a real terminal, even when a provider supports a separate noninteractive credential mechanism — `--interactive` or not, this command has no headless variant. If stdin or stdout is not a TTY — a piped/redirected shell, a `Start-Process` with redirected stdio, or a dispatched agent session — `wiqd auth login` fails immediately (before doing any work) instead of hanging indefinitely:

```
✗ Interactive sign-in requires a terminal. Run `wiqd auth login` in an interactive
shell, or establish each provider's session ahead of time using its own documented
non-interactive/service-account mechanism instead of `wiqd auth login`.
```

This exits with code `2` in well under 5 seconds, for both the default invocation and `--interactive`. **Automation must never call `wiqd auth login`.** Use the selected provider's documented noninteractive mechanism instead. Core-backed pipeline setup is covered in [CI/CD Authentication](/getting-started/ci-cd-authentication/). `wiqd auth status` is not TTY-gated; it may acquire or renew tokens silently but does not prove access to every lifecycle resource.

There is deliberately no assume-TTY flag or environment override. If standalone
Git Bash/mintty is reported as redirected, use its TTY bridge (for example,
`winpty`) or run the command from PowerShell/Windows Terminal. The gate applies
to the `wiqd auth login` aggregator; raw `wiqd exec <tool> ...` passthrough is
caller-owned and does not inherit this terminal or timeout policy.

`wiqd auth login --json` can render a success envelope to a real terminal (and
in mock mode), but redirecting stdout to capture that envelope triggers the same
fail-fast gate by design. For automation, configure the provider's documented
noninteractive mechanism and then capture `wiqd auth status --json`.

### Other ways `wiqd auth login` can exit with code `2`

Exit `2` always means "the command could not even attempt a sign-in", never "a
provider rejected you". Besides the terminal requirement above, two
configuration problems produce it:

| Error code                  | Meaning                                                                                                | Fix                                                                                                                    |
| --------------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `AUTH_LOGIN_INVALID_TENANT` | `--tenant` is malformed or the all-zero GUID. | Supply a nonzero GUID in `8-4-4-4-12` format. |
| `AUTH_LOGIN_TENANT_UNSUPPORTED` | No active runtime login provider declares the tenant input. | Activate a provider that documents tenant-scoped login, or omit `--tenant`. |
| `AUTH_LOGIN_NO_PROVIDERS`   | No installed, activated extension contributes an auth provider, so there was nothing to sign in to.    | Run `wiqd ext list` to see what is installed, then activate a provider-contributing extension with `wiqd ext add <id>`. |
| `selected_backend_missing`  | A backend-selector feature flag names a backend that no activated extension provides — it may be installed but not activated, or not installed at all. | Reset the flag (`wiqd config flags reset <flag>`) or activate the selected backend with `wiqd ext add <id>`.            |

Both are reported by `wiqd auth login` with the same exit code and a stable
error code. `selected_backend_missing` in particular is reported **identically**
by `wiqd auth login`, `wiqd auth status`, and `wiqd auth logout`, so that
misconfiguration never looks like a success in one command and an error in
another. (`AUTH_LOGIN_NO_PROVIDERS` is specific to `auth login`: `status` and
`logout` have nothing to sign in, so an empty provider set is not an error for
them.) In particular, `wiqd auth login` never prints an empty provider list and
exits `0` — a login that signed nothing in is a failure.

## Check Status

View the currently signed-in account and token status:

```bash
wiqd auth status
```

### Check tenant consistency

Being signed in does not mean that every tool uses the same Microsoft 365
tenant. An agent deployed in a customer tenant may not appear when another
provider queries your home organization's tenant.

`wiqd auth status` now reports tenant information for providers that declare
this capability. Raw tenant IDs are not displayed: `tenant-1`, `tenant-2`, and
similar labels distinguish tenants **within one report only**. They are not
tenant selectors and must not be compared across separate command invocations.

```text
Microsoft 365 (wiqd core): signed in [tenant: tenant-1]
Work IQ: unknown [tenant: unknown (provider does not expose tenant status)]
m365: Cannot confirm tenant consistency...
```

The core lifecycle provider can report its effective tenant. Current Work IQ
1.0.0 has no supported read-only auth-status command, so its tenant remains
unknown; wiqd never reads its token cache or triggers a login to fill that gap.
Eval has the same inspection limitation. Providers can declare independent
service identities as not applicable to resource-tenant comparison.

When two providers in the same declared comparison group report different
tenants, wiqd warns that a resource deployed through one may not be visible
through the other. A consistent result requires at least two providers and
complete tenant evidence for the group. A missing, signed-out, or unsupported
provider means consistency cannot be confirmed.

```bash
wiqd auth status --json
```

JSON adds `tenant` to participating provider rows and `tenantComparisons` for
declared groups. Unknown tenant reasons distinguish unsupported inspection,
an unavailable provider, a missing tenant value, and an invalid value. Providers
without a tenant declaration retain their existing output.

These diagnostics are advisory and do not change the command's existing exit
behavior. Verify the target tenant in each provider's supported tooling when a
warning appears. The provider-scoped `wiqd auth login --tenant` input does not
implement automatic or coordinated switching, and `auth status` never signs
users out.

Read each row independently. A signed-in row can coexist with another provider's
signed-out row. `auth status` may silently refresh a provider-owned token while
inspecting it, but never opens an interactive prompt.

## Sign Out

```bash
wiqd auth logout
```

Logout is blanket and best-effort: it asks every active provider to clear the
session/cache that provider owns, continues when one provider fails, and returns
a non-zero aggregate result when any provider reports failure. There is no
provider-specific or account-specific logout selector.

This does not globally sign the user out of Microsoft in the system browser,
operating-system account manager, or tenant. Those external sessions can affect
what a later provider-owned interactive flow shows. Always run
`wiqd auth status` after logout or account switching to confirm the actual
provider states.

## Brokered authentication

Extension auth providers use brokered authentication via MSAL (Microsoft Authentication Library) when available. Core Microsoft 365 and private Marketplace authentication use WAM on Windows. macOS and Linux currently use the system browser; macOS native broker activation is temporarily disabled until the shared app registration includes its broker redirect URI. Browser authentication may be rejected when your organization requires Token Protection.

:::note
If brokered authentication causes issues, you can disable it with `wiqd config set disableBrokeredAuth=true`. Providers that honor this setting use the system browser for their next interactive sign-in.
:::

## Redirected Local Commands

Providers that support it resolve your session **before** deciding whether a sign-in prompt is needed, so an existing developer session can support lifecycle commands in a pipe or redirected local shell. This is not the CI/CD credential contract, and explicit `wiqd auth login` still requires a terminal.

Such a command only fails for lack of a terminal when it genuinely needs to prompt. When that happens it says so, and points at the command that fixes it — for example:

```
✗ <provider> sign-in requires an interactive terminal. Run 'wiqd auth login --interactive' in a terminal first, then retry.

  Fix it:
    1. wiqd auth login --interactive   # run once in an interactive terminal
    2. wiqd auth status                # confirm the session is active
```

A well-behaved provider does not destroy a session you already had when a sign-in fails: its token cache is replaced only on a confirmed successful sign-in, or cleared by an explicit `wiqd auth logout`.

## CI/CD Pipelines

Username/password and refresh-token authentication are pipeline-only mechanisms,
separate from normal developer sign-in. See [CI/CD Authentication](/getting-started/ci-cd-authentication/)
for supported operations, secret inputs, consent, renewal and failure handling.
The local refresh-token bootstrap command prepares a pipeline secret without
changing your developer session; its release validation remains pending.

## See Also

- [wiqd auth login](/cli/reference/#wiqd-auth-login)
- [wiqd auth logout](/cli/reference/#wiqd-auth-logout)
- [wiqd auth status](/cli/reference/#wiqd-auth-status)
- [wiqd config](/cli/reference/#wiqd-config)
