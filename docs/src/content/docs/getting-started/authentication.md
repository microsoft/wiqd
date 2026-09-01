---
title: Authentication
---

# Authentication

Work IQ Dev Tools use Microsoft identity to authenticate against Microsoft 365 and Azure services. You must sign in before running commands that interact with your tenant (provisioning, sharing, etc.).

## How authentication works

Work IQ Dev Tools do not run their own authentication flow. Each `auth` command delegates to the installed extensions: every extension that declares `auth.commands.{login,logout,status}` in its manifest (ATK, workiq, eval, etc.) is invoked as a subprocess, and its result is reported as a provider row. You authenticate against those extension binaries, not against an identity flow owned by Work IQ Dev Tools.

After a provider's login subprocess succeeds, Work IQ Dev Tools **verify** that an identity was actually acquired before showing a `✔` and the authenticated account — a successful exit code alone is never treated as proof of a session. Verification reads the identity out of the login output first and falls back to re-probing the provider's status only when the login output shows none; a broker-backed account can be process-local and vanish before a separate status subprocess starts, so preferring the login output avoids reporting a real sign-in as a failure. Login and logout target the same provider session (for ATK, the `m365` account), so a `wiqd auth logout` followed by `wiqd auth login` performs a real re-sign-in rather than a silent no-op.

Some extensions are **runtime-backed** instead of subprocess-backed: they run their sign-in in-process and return a structured signed-in / signed-out / error state directly, so no separate status subprocess or output pattern is used for them. Either way, Work IQ Dev Tools own no identity, client ID, or token cache — the provider does.

Commands that interact with your tenant—including agent and plugin provisioning and sharing, plus agent info, uninstall, and publish—check the provider's status first. When the provider definitively reports that you are signed out, the command exits with code `2` and instructions to run `wiqd auth login --interactive` instead of waiting on an invisible upstream sign-in prompt. An unavailable or inconclusive status check does not block the command.

## Sign In

```bash
wiqd auth login --interactive
```

### Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--interactive` | `flag` | `false` | Force an interactive sign-in. Appends each provider's interactive arguments to the downstream invocation (e.g. ATK `-i true` instead of `-i false`) so a fresh sign-in is forced, and extends the per-provider timeout for browser-based flows. Does not change the terminal requirement — see below. |

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

Every provider's sign-in is ultimately a browser/device-code/broker flow that only a human at a real terminal can complete — `--interactive` or not, this command has no headless variant. If stdin or stdout is not a TTY — a piped/redirected shell, a `Start-Process` with redirected stdio, or a dispatched agent session — `wiqd auth login` fails immediately (before doing any work) instead of hanging indefinitely:

```
✗ Interactive sign-in requires a terminal. Run `wiqd auth login` in an interactive
shell, or establish each provider's session ahead of time using its own documented
non-interactive/service-account mechanism instead of `wiqd auth login`.
```

This exits with code `2` in well under 5 seconds, for both the default invocation and `--interactive`. **Automation must never call `wiqd auth login`.** To get a provider signed in headlessly, use that provider's own documented non-interactive mechanism directly (for example, ATK's own CLI reads its own service-principal environment variables) — outside of wiqd — and let downstream commands reuse the resulting cached session. `wiqd auth status` is read-only and is never gated by this check, so it is safe to use in CI/automation to verify a session that was established that way.

There is deliberately no assume-TTY flag or environment override. If standalone
Git Bash/mintty is reported as redirected, use its TTY bridge (for example,
`winpty`) or run the command from PowerShell/Windows Terminal. The gate applies
to the `wiqd auth login` aggregator; raw `wiqd exec <tool> ...` passthrough is
caller-owned and does not inherit this terminal or timeout policy.

`wiqd auth login --json` can render a success envelope to a real terminal (and
in mock mode), but redirecting stdout to capture that envelope triggers the same
fail-fast gate by design. For automation, establish the provider session
directly and then capture `wiqd auth status --json`.

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

Extension auth providers use brokered authentication via MSAL (Microsoft Authentication Library) when available. On platforms that support it, credentials are managed by the operating system's authentication broker (for example, WAM on Windows). Providers that support browser authentication open the system browser when the native broker is unavailable; on macOS and Linux this is the normal interactive sign-in path.

:::note
If brokered authentication causes issues, you can disable it with `wiqd config set disableBrokeredAuth=true`. Providers that honor this setting use the system browser for their next interactive sign-in.
:::

## Automation and non-interactive shells

Providers that support it resolve your session **before** deciding whether a sign-in prompt is needed, so a valid session works in a pipe, a redirected shell, or a CI step without any extra configuration. Piping stdout — what `--json` consumers do — never changes an auth outcome.

Such a command only fails for lack of a terminal when it genuinely needs to prompt. When that happens it says so, and points at the command that fixes it — for example:

```
✗ <provider> sign-in requires an interactive terminal. Run 'wiqd auth login --interactive' in a terminal first, then retry.

  Fix it:
    1. wiqd auth login --interactive   # run once in an interactive terminal
    2. wiqd auth status                # confirm the session is active
```

A well-behaved provider does not destroy a session you already had when a sign-in fails: its token cache is replaced only on a confirmed successful sign-in, or cleared by an explicit `wiqd auth logout`.

## See Also

- [wiqd auth login](/cli/reference/#wiqd-auth-login)
- [wiqd auth logout](/cli/reference/#wiqd-auth-logout)
- [wiqd auth status](/cli/reference/#wiqd-auth-status)
- [wiqd config](/cli/reference/#wiqd-config)
