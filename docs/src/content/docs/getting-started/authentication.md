---
title: Authentication
---

# Authentication

Work IQ Dev Tools use Microsoft identity to authenticate against Microsoft 365 and Azure services. You must sign in before running commands that interact with your tenant (provisioning, sharing, etc.).

## How authentication works

Work IQ Dev Tools do not run their own authentication flow. Each `auth` command delegates to the installed extensions: every extension that declares `auth.commands.{login,logout,status}` in its manifest (ATK, workiq, eval, etc.) is invoked as a subprocess, and its result is reported as a provider row. You authenticate against those extension binaries, not against an identity flow owned by Work IQ Dev Tools.

After a provider's login subprocess succeeds, Work IQ Dev Tools **verify** that an identity was actually acquired (re-probing the provider's status) before showing a `✔` and the authenticated account — a successful exit code alone is never treated as proof of a session. Login and logout target the same provider session (for ATK, the `m365` account), so a `wiqd auth logout` followed by `wiqd auth login` performs a real re-sign-in rather than a silent no-op.

Commands that interact with your tenant—including agent and plugin provisioning and sharing, plus agent info, uninstall, and publish—check the provider's status first. When the provider definitively reports that you are signed out, the command exits with code `2` and instructions to run `wiqd auth login` instead of waiting on an invisible upstream sign-in prompt. An unavailable or inconclusive status check does not block the command.

## Sign In

```bash
wiqd auth login
```

### Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--interactive` | `flag` | `false` | Force an interactive sign-in. Appends each provider's interactive arguments to the downstream invocation (e.g. ATK `-i true` instead of `-i false`) so a fresh sign-in is forced, and extends the per-provider timeout for browser-based flows. |

### Examples

Sign in to all installed extension providers:

```bash
wiqd auth login
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

The extension auth providers use brokered authentication via MSAL (Microsoft Authentication Library) when available. On platforms that support it, credentials are managed by the operating system's authentication broker (e.g., WAM on Windows).

:::note
If brokered authentication is not available or causes issues, you can disable it with `wiqd config set disableBrokeredAuth=true`.
:::

## See Also

- [wiqd auth login](/cli/reference/#wiqd-auth-login)
- [wiqd auth logout](/cli/reference/#wiqd-auth-logout)
- [wiqd auth status](/cli/reference/#wiqd-auth-status)
- [wiqd config](/cli/reference/#wiqd-config)
