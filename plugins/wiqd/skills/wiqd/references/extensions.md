# Extension Management & Capabilities

**Telemetry:** `--skill wiqd` on every ordinary `wiqd` command.

Use this reference when the user asks about wiqd extensions, installed extensions, extension capabilities, activating or removing extensions, or how extensions work.

## Key Concepts

Extensions are **npm packages** that contain a `wiqd-extension.json` **manifest** at their package root. The manifest declares the extension's contributed surface: commands, skills, MCP servers, validation checks, and doctor health checks.

**Do NOT confuse these two files:**

| File                      | What it is                                                                                                          | Location                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| `wiqd-extension.json`     | Per-extension **manifest** — declares what an extension contributes (commands, capabilities, version, requirements) | Inside each extension's npm package directory     |
| `~/.wiqd/extensions.json` | Host **activation registry** — tracks which extensions are activated                                                | `~/.wiqd/extensions.json` (user config directory) |

The host discovers extensions by scanning `node_modules/` for packages containing a `wiqd-extension.json` manifest. Activation is **registration-only**: an extension is **active** if and only if its id is registered in `~/.wiqd/extensions.json` — there is no separate "bundled, always-active" state. The installer seeds registrations for the default 3P extension set (see **Bundled Extensions** below) at install time so they work out of the box, but a user MAY durably `wiqd ext remove` any of them. Mere presence in `node_modules/` does not auto-activate an extension.

## Listing Extensions

```bash
wiqd ext list [--json] --skill wiqd
```

Shows a table with columns: **ID**, **Name**, **Version**, **Origin** (`installer` / `user` / `—` when inactive), **State** (active / inactive / not installed), and **Upstream** (the downstream CLI an extension wraps, and whether wiqd can find it on this machine). A two-line legend below the table notes that Version is the wiqd extension package version (bundled extensions share the wiqd version), not the upstream tool version.

⚠️ **`wiqd ext list` does NOT show capabilities.** It is an inventory command only.

## Showing Extension Details & Capabilities

```bash
wiqd ext show <id> [--json] --skill wiqd
```

Shows detailed information including: **ID**, **Name**, **Version**, **Description**, **Capabilities** (e.g. commands, skills, mcp-server, validation), **Commands** count, **Package** path, and **Requirements** (wiqd version, node version).

⚠️ **When the user asks what extensions can do, or asks for capabilities, you MUST follow up `wiqd ext list` with `wiqd ext show <id>` for each extension.** `ext list` alone does not surface capabilities — `ext show` is the only command that does.

### Recommended workflow for "list extensions with capabilities"

1. Run `wiqd ext list --json --skill wiqd` to get the list of extensions
2. For each extension in the list, run `wiqd ext show <id> --json --skill wiqd`
3. Present a consolidated view showing each extension's ID, name, version, and capabilities

## Activating & Deactivating Extensions

```bash
wiqd ext add <id> --skill wiqd      # Activate an installed extension
wiqd ext remove <id> --skill wiqd   # Deactivate (does NOT uninstall the npm package)
```

The seeded default extensions (see **Bundled Extensions** below) are active out of the box, but — like any registered extension — they can be deactivated with `wiqd ext remove <id>` and later reactivated with `wiqd ext add <id>`. No extension is permanently non-removable.

## Bundled Extensions

wiqd's installer seeds **seven default 3P extensions** as registrations (origin `installer` in `~/.wiqd/extensions.json`) at install time. These are seeded defaults, NOT immovable bundled payload — any of them MAY be deactivated with `wiqd ext remove <id>` and later reactivated with `wiqd ext add <id>`. ATK and core are both installed and registered; the `plugin-core-engine` flag makes exactly one participate, so the other is hidden from `wiqd ext list` rather than missing:

| Extension             | Purpose                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------- |
| `microsoft.atk`       | Agents Toolkit — agent lifecycle (create, provision, share, package, publish, delete, open) |
| `microsoft.wiqd.core` | In-process core backend — selectable replacement for the ATK lifecycle                      |
| `microsoft.workiq`    | Work IQ — agent monitoring (monitor, ask, list)                                             |
| `microsoft.eval`      | Eval — agent evaluation (eval, eval init)                                                   |
| `microsoft.validate`  | Validation — manifest validation and LSP                                                    |
| `microsoft.github`    | GitHub — submit and list wiqd feedback as GitHub issues via `gh`                            |
| `microsoft.devui`     | DevUI — local Work IQ DevUI web experience for testing and debugging agents                 |


## Fallback (CLI unavailable)

If the wiqd CLI is unavailable, inspect extensions directly:

1. Locate extension packages in the wiqd npm installation's `node_modules/` directory
2. Read each extension's `wiqd-extension.json` manifest for its declared `capabilities`, `commands`, and `requirements`
3. The manifest `id`, `displayName`, `version`, `description`, and `capabilities` fields correspond to the fields shown by `wiqd ext show`
