# Command Discovery

**Telemetry:** `--skill wiqd` on every ordinary telemetry-emitting `wiqd` command. Help and version calls remain telemetry-cold.

How to discover available wiqd commands, extensions, and capabilities.

## Discovering Commands

### Top-Level Help

```bash
wiqd --help
```

Shows the root command tree: `agent`, `config`, `auth`, `update`, `changelog`, `install`, `doctor`, `docs`, `feedback`, `ext`.

### Agent Subcommands

```bash
wiqd agent --help
```

Shows all agent lifecycle commands: `create`, `add`, `validate`, `show`, `provision`, `package`, `share`, `delete`, `open`, `eval`, `env`, `publish`, `monitor`, `ask`, `list`.

### Command-Specific Help

```bash
wiqd agent create --help
wiqd agent provision --help
wiqd config set --help
```

Each command shows its own options, arguments, and description.

## Discovering Extensions

Extensions contribute commands beyond wiqd core. Use `wiqd ext` to explore:

```bash
wiqd ext list [--json] --skill wiqd        # List all extensions with status
wiqd ext show <id> [--json] --skill wiqd   # Show extension details + capabilities
```

**⚠️ `ext list` shows inventory only.** To see what commands an extension contributes, follow up with `ext show <id>`.

See `references/extensions.md` for full extension management.

## Discovering the Lifecycle

wiqd covers the full agent lifecycle. The key phases are:

| Phase        | What to Say                            | Commands Involved                |
| ------------ | -------------------------------------- | -------------------------------- |
| **Build**    | "create an agent", "add a capability"  | `agent create`, `agent add`      |
| **Validate** | "validate my agent"                    | `agent validate`                 |
| **Improve**  | "run my evals", "evaluate my agent"    | `agent eval`                     |
| **Preview**  | "provision my agent", "share my agent" | `agent provision`, `agent share` |
| **Publish**  | "publish my agent"                     | `agent publish`                  |

For the full lifecycle map, see:

- `references/lifecycle-3p.md` — 3P golden path

## Discovering Documentation

wiqd documentation is published at https://aka.ms/wiqd/docs and also lives in-repo under `docs/src/content/docs/`. See `references/docs-search.md` for how to search it.

## Quick Orientation

| User Intent                      | Route To                                            |
| -------------------------------- | --------------------------------------------------- |
| "What can wiqd do?"              | This reference + `references/orientation.md`        |
| "How do I get started?"          | `references/orientation.md`                         |
| "What extensions are installed?" | `wiqd ext list`, then `wiqd ext show` per extension |
| "What commands exist?"           | `wiqd --help`, `wiqd agent --help`                  |
| "Search the docs for X"          | Docs site: https://aka.ms/wiqd/docs                 |
| "Check my environment"           | `wiqd doctor`                                       |
