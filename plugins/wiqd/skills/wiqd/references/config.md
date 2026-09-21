# Configuration

**Telemetry:** `--skill wiqd` on every ordinary `wiqd` command.

Manage persisted CLI defaults stored in `~/.wiqd/.wiqd.json`. Set preferences once and forget them.

## Commands

### View Current Config

```bash
wiqd config --skill wiqd
```

Displays all current key=value pairs, sorted alphabetically. Prints "No config set." if the file is empty or missing.

### Set Config Values

```bash
wiqd config set <key=value...> --skill wiqd
```

Accepts one or more `key=value` pairs. Keys are validated against the allowed set (case-insensitive).

| Key                   | Type    | Default          | Description                                                |
| --------------------- | ------- | ---------------- | ---------------------------------------------------------- |
| `disableBrokeredAuth` | boolean | `false` (absent) | Disables WAM broker auth; falls back to browser-based MSAL |
| `banner`              | string  | enabled (absent) | `"false"` disables the ASCII banner                        |
| `telemetry`           | string  | enabled (absent) | `"false"` disables OpenTelemetry export                    |

**Boolean parsing:** "true", "on", "1" → truthy; all others → falsy. Setting `disableBrokeredAuth` to a falsy value removes the key entirely (absence = default).

**Examples:**

```bash
# Disable WAM broker authentication (use browser flow)
wiqd config set disableBrokeredAuth=true --skill wiqd

# Disable the ASCII banner
wiqd config set banner=false --skill wiqd

# Opt out of telemetry
wiqd config set telemetry=false --skill wiqd

# Set multiple values at once
wiqd config set disableBrokeredAuth=true banner=false --skill wiqd
```

### Reset All Config

```bash
wiqd config reset --skill wiqd
```

Deletes the entire config file (`~/.wiqd/.wiqd.json`). Confirms the deleted path.

## Feature Flags

The `wiqd config flags` subgroup manages typed, registered feature flags. Flags live in a `"flags"` section inside `~/.wiqd/.wiqd.json` and can be overridden per-process via `WIQD_FLAG_<UPPER_SNAKE_NAME>` environment variables.

### List All Flags

```bash
wiqd config flags list --skill wiqd
```

Shows every registered flag: name, type, default, current effective value, and stage (alpha/beta/ga).

### Show Flag Details

```bash
wiqd config flags show <name> --skill wiqd
```

Shows full details for a single flag: description, owner, valid values, current source-of-value (default / persisted / env).

### Set a Flag

```bash
wiqd config flags set <name>=<value> --skill wiqd
```

Persists a flag override to `~/.wiqd/.wiqd.json`.

### Reset a Flag

```bash
wiqd config flags reset <name> --skill wiqd
wiqd config flags reset --all --skill wiqd
```

Removes a persisted flag override (returns to registry default). `--all` removes all flag overrides.

## Error Handling

| Error               | Output                                                                         |
| ------------------- | ------------------------------------------------------------------------------ |
| Invalid pair format | `Invalid setting 'badformat'. Expected key=value.`                             |
| Unknown key         | `Unknown option 'foo'. Valid options: disableBrokeredAuth, banner, telemetry.` |
| Unknown flag name   | Lists available flags                                                          |

## Relationship to Other Commands

- `wiqd auth login` reads `disableBrokeredAuth` to choose WAM vs browser flow
- `wiqd` (bare) and `wiqd --version` read `banner` config
- All commands read `telemetry` config for OpenTelemetry export

**Exit codes:** 0 = success, 1 = validation error (invalid key, bad format).
