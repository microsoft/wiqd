# Authentication

**Telemetry:** `--skill wiqd` on every ordinary `wiqd` command.

Manage wiqd CLI authentication — sign in, check status, and sign out.

## Commands

### Login

```bash
wiqd auth login [--account <email>] [--interactive] --skill wiqd
```

Signs in to wiqd and to every extension that contributes an auth provider. Each provider caches its own tokens, so subsequent agent commands work without re-authentication.

| Flag            | Description                                                                                                | Default |
| --------------- | ---------------------------------------------------------------------------------------------------------- | ------- |
| `--account`     | Global account hint accepted by the host; provider-specific account selection is not currently implemented | —       |
| `--interactive` | Force each provider's interactive argument set. Both forms still require real terminal stdin and stdout.   | `false` |

**What happens on login:**

1. Before extension discovery, the host refuses the command unless stdin and stdout are real terminal streams
2. The host resolves the active auth providers, failing closed on exit `2` if a backend-selector flag names an extension that is not activated
3. The host asks every extension that declares an auth provider to sign in
4. Each provider owns its own token cache and identity stack — the host stores no tokens itself
5. A provider that fails is reported per-provider; the others still run

**Exit codes:**

| Code  | Meaning                                                                                                                                                                        |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `0`   | Every provider signed in and a verified identity was acquired                                                                                                                  |
| `1`   | At least one provider failed to authenticate                                                                                                                                   |
| `2`   | Not a real terminal (`AUTH_LOGIN_REQUIRES_TTY`), no auth provider available (`AUTH_LOGIN_NO_PROVIDERS`), or the selected backend is not activated (`selected_backend_missing`) |
| `130` | Cancelled (Ctrl+C)                                                                                                                                                             |

Exit `2` always means the sign-in was never attempted. `wiqd auth login` never
reports success for an empty provider list — if nothing was signed in, it fails.

There is no headless or assume-TTY mode. Automation establishes each provider
session directly and verifies it afterward with `wiqd auth status --json`.
Standalone Git Bash/mintty users whose streams are not reported as TTYs should
use a TTY bridge such as `winpty` or run login from PowerShell/Windows Terminal.
Raw `wiqd exec <tool> ...` passthrough is caller-owned and does not inherit the
aggregator's TTY or timeout policy.

### Logout

```bash
wiqd auth logout --skill wiqd
```

Clears cached credentials for every extension auth provider. Idempotent: "already logged out" is still exit 0.

**⚠️ Safety:** Logout clears shared token caches. In shared or concurrent eval environments, this affects all in-flight sessions. Confirm with the user before running in shared environments.

### Status

```bash
wiqd auth status [--json] --skill wiqd
```

Displays current authentication state **without ever prompting**. It may perform a silent token acquisition — and so refresh and re-persist a token — because a read-only cache inspection cannot see a session the OS broker holds, which is what let status disagree with the commands run beside it.

Reports:

- Per-provider auth state
- Account name
- Whether an account is cached but no token could be acquired for it silently

| Flag     | Description                                                       | Default |
| -------- | ----------------------------------------------------------------- | ------- |
| `--json` | Emit machine-readable JSON output (default: human-readable table) | `false` |

**Exit codes:**

| Code  | Meaning                                                                           |
| ----- | --------------------------------------------------------------------------------- |
| `0`   | Status rendered; per-provider rows carry the signal                               |
| `2`   | The selected backend is configured but not activated (`selected_backend_missing`) |
| `130` | Cancelled (Ctrl+C)                                                                |


## Error Recovery

| Error                                   | Action                                                                                            |
| --------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Sign-in times out                       | Retry; check network/proxy                                                                        |
| One provider fails after login          | Non-fatal — the others still signed in; the failing one can retry                                 |
| Status reports not signed in            | Run `wiqd auth login --interactive --skill wiqd` from a real terminal                             |
| Login reports `AUTH_LOGIN_REQUIRES_TTY` | Restore terminal stdin/stdout; use `winpty` under mintty or switch to PowerShell/Windows Terminal |
| 404 on `gh` operations                  | Wrong active gh account — switch to the correct account                                           |

Core Microsoft 365 authentication prefers the native broker on Windows and
macOS. macOS brokered authentication requires an enrolled device and the
Microsoft Enterprise SSO plug-in supplied by Company Portal; it provides the
device-bound tokens required by Token Protection policies. Linux and systems
where the native broker reports unavailable use browser authentication.

## Relationship to Other Commands

- **Prerequisite for:** `wiqd agent provision`, `wiqd agent share`, `wiqd agent publish`, `wiqd agent ask`, `wiqd agent monitor`
- **Configured by:** `wiqd config set disableBrokeredAuth=true` switches Core and supporting providers from native broker to browser flow
- **Diagnosed by:** `wiqd auth status`

See each command's exit-code table above; cancellation returns `130`.
