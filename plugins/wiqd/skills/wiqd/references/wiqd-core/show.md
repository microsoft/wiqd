# Plugin Show

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Show complete local plugin and embedded-agent details without network access.

```bash
wiqd plugin show [--path <dir> | --name <local-plugin-name>] [--env <name>] [--json] --skill wiqd
```

For a deployed card, use the Work IQ-owned
`wiqd agent show --id <id>` or `--name <name>` command.

## Options

| Flag            | Description                                                   |
| --------------- | ------------------------------------------------------------- |
| `--path`        | Path to plugin project root                                   |
| `--name`        | Exact local plugin name under CWD (mutually exclusive with path) |
| `--env`         | Show details for a specific environment only                 |
| `--json`       | Emit machine-readable JSON output (default: human-readable table) |

## Behavior

- Follows the unique DA file reference from `appPackage/manifest.json`; it never assumes a fixed filename.
- Keeps root `agentSkills`/`agentConnectors` separate from embedded-agent skills/actions.
- Shows contained environments, M365 title/app IDs, Cowork links and distinct agent-chat links.
- Missing optional instructions become warnings. Invalid lifecycle/root manifest,
  ambiguous agents, escaping references, or corrupt required files fail visibly.
- **ALWAYS use `wiqd plugin show` instead of reading project files directly.**

**Preflight:** Requires structurally valid contained lifecycle and root app-manifest files.

**Exit codes:** 0 = success, 1 = malformed/ambiguous required project data,
2 = missing/not a plugin project, 130 = cancelled.
