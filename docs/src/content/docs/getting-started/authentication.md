---
title: Authentication
---

# Authentication

Work IQ Dev Tools use Microsoft identity to authenticate against Microsoft 365 and Azure services. You must sign in before running commands that interact with your tenant (provisioning, sharing, etc.).

## How authentication works

Work IQ Dev Tools do not run their own authentication flow. Each `auth` command delegates to the installed extensions: every extension that declares `auth.commands.{login,logout,status}` in its manifest (ATK, workiq, eval, etc.) is invoked as a subprocess, and its result is reported as a provider row. You authenticate against those extension binaries, not against an identity flow owned by Work IQ Dev Tools.

After a provider's login subprocess succeeds, Work IQ Dev Tools **verify** that an identity was actually acquired (re-probing the provider's status) before showing a `✔` and the authenticated account — a successful exit code alone is never treated as proof of a session. Login and logout target the same provider session (for ATK, the `m365` account), so a `wiqd auth logout` followed by `wiqd auth login` performs a real re-sign-in rather than a silent no-op.

Some extensions are **runtime-backed** instead of subprocess-backed: they run their sign-in in-process and return a structured signed-in / signed-out / error state directly, so no separate status subprocess or output pattern is used for them. Either way, Work IQ Dev Tools own no identity, client ID, or token cache — the provider does.

Commands that interact with your tenant—including agent and plugin provisioning and sharing, plus agent info, uninstall, and publish—check the provider's status first. When the provider definitively reports that you are signed out, the command exits with code `2` and instructions to run `wiqd auth login --interactive` instead of waiting on an invisible upstream sign-in prompt. An unavailable or inconclusive status check does not block the command.

## Sign In

```bash
wiqd auth login --interactive
```

### Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--interactive` | `flag` | `false` | Force an interactive sign-in. Appends each provider's interactive arguments to the downstream invocation (e.g. ATK `-i true` instead of `-i false`) so a fresh sign-in is forced, and extends the per-provider timeout for browser-based flows. |

### Examples

Sign in to all installed extension providers:

```bash
wiqd auth login --interactive
```

Force interactive login:

```bash
wiqd auth login --interactive
```

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
