---
title: Authentication
---

# Authentication

Work IQ Dev Tools use extension-owned Microsoft identity providers for Microsoft 365 and Azure services. Commands that interact with your tenant need the appropriate provider's credentials. This guide covers normal developer sign-in. For pipeline-only username/password or refresh-token authentication, see [CI/CD Authentication](/getting-started/ci-cd-authentication/).

## How authentication works

The domain-neutral WIQD host delegates `auth login`, `auth logout`, and `auth status` to activated extension providers. Subprocess-backed providers (such as workiq) run their own binaries; runtime-backed providers run in-process. The `wiqd-ext-core` provider owns its MSAL client, developer cache, and CI authentication backends. Those are extension responsibilities, not host-aggregator identity logic.

After a provider's login subprocess succeeds, Work IQ Dev Tools **verify** that an identity was actually acquired before showing a `✔` and the authenticated account — a successful exit code alone is never treated as proof of a session. Verification reads the identity out of the login output first and falls back to re-probing the provider's status only when the login output shows none; a broker-backed account can be process-local and vanish before a separate status subprocess starts, so preferring the login output avoids reporting a real sign-in as a failure. Login and logout target the same provider session, so a `wiqd auth logout` followed by `wiqd auth login` performs a real re-sign-in rather than a silent no-op.

Runtime-backed providers return a structured signed-in / signed-out / error state directly, so no separate status subprocess or output pattern is used for them. The host reports the provider's result; it does not own that provider's client ID or token cache.

Commands that interact with your tenant—including agent and plugin provisioning and sharing, plus agent info, uninstall, and publish—check the provider's status first. When the provider definitively reports that you are signed out, the command exits with code `2` and instructions to run `wiqd auth login --interactive` instead of waiting on an invisible upstream sign-in prompt. An unavailable or inconclusive status check does not block the command.

## Sign In

```bash
wiqd auth login --interactive
```

### Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--interactive` | `flag` | `false` | Force an interactive sign-in. Appends each provider's interactive arguments to the downstream invocation (e.g. an interactive flag instead of the non-interactive default) so a fresh sign-in is forced, and extends the per-provider timeout for browser-based flows. Does not change the terminal requirement — see below. |

### Examples

Sign in to all installed extension providers:

```bash
wiqd auth login --interactive
```

Force interactive login:

```bash
wiqd auth login --interactive
```

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

## Sign Out

```bash
wiqd auth logout
```

## Brokered authentication

Extension auth providers use brokered authentication via MSAL (Microsoft Authentication Library) when available. Core Microsoft 365 authentication uses WAM on Windows. macOS and Linux currently use the system browser; macOS native broker activation is temporarily disabled until the shared app registration includes its broker redirect URI. Browser authentication may be rejected when your organization requires Token Protection.

:::note
If brokered authentication causes issues, you can disable it with `wiqd config set disableBrokeredAuth=true`. Core Microsoft 365 authentication and other providers that honor this setting use the system browser for their next interactive sign-in.
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
