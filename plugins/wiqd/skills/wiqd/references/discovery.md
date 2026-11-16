# Command Discovery

**Telemetry:** `--skill wiqd` on every ordinary telemetry-emitting `wiqd` command. Help and version calls remain telemetry-cold.

How to discover available wiqd commands, extensions, and capabilities.

## Discovering Commands

### Top-Level Help

```bash
wiqd --help
```

Shows the available top-level namespaces, including `plugin` for project lifecycle
and `agent` for agent-specific operations. Active extensions and feature flags
determine the complete command tree; use the installed help rather than guessing
commands from older versions.

### Plugin Subcommands

```bash
wiqd plugin --help
wiqd plugin list --help
wiqd plugin add --help
```

Project creation, validation, provisioning, packaging, sharing, and publishing
belong under `plugin`, not `agent`. Follow nested help to find commands such as
`plugin list templates` and `plugin add agent`.

### Agent Subcommands

```bash
wiqd agent --help
```

Shows the agent-specific commands contributed by active extensions, such as
`add`, `info`, `eval`, `show`, and `list`. Do not infer retired lifecycle commands
such as `agent create` or `agent provision`; use the corresponding `plugin`
commands.


### Browsing Agent Templates

For a request to list or compare available embedded-agent templates, run:

```bash
wiqd plugin list templates --json --skill wiqd
```

Report the template IDs, names, and descriptions from the returned catalog.
This is a global, read-only operation: no project, project name, authentication,
or scaffolding is needed. Stop after presenting the catalog unless the user also
requests creation. There is no `wiqd agent templates` command.

### Command-Specific Help

```bash
wiqd plugin create --help
wiqd plugin provision --help
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

| Phase        | What to Say                            | Commands Involved                                                                                        |
| ------------ | -------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Build**    | "create an agent", "add a capability"  | `plugin create`, `plugin add agent`, `agent add`                                                         |
| **Validate** | "validate my agent"                    | `validation` workflow: source for saved source, package for ZIP, Marketplace for package + policy checks |
| **Improve**  | "run my evals", "evaluate my agent"    | `agent eval`                                                                                             |
| **Preview**  | "provision my agent", "share my agent" | `plugin provision`, `plugin share`                                                                       |
| **Publish**  | "publish my agent"                     | `plugin publish`                                                                                         |

For the full lifecycle map, see:

- `references/lifecycle-3p.md` — 3P golden path

## Discovering Documentation

wiqd documentation is published at https://aka.ms/wiqd/docs and also lives in-repo under `docs/src/content/docs/`. See `references/docs-search.md` for how to search it.

## Quick Orientation

| User Intent                      | Route To                                                        |
| -------------------------------- | --------------------------------------------------------------- |
| "What can wiqd do?"              | This reference + `references/orientation.md`                    |
| "How do I get started?"          | `references/orientation.md`                                     |
| "What extensions are installed?" | `wiqd ext list`, then `wiqd ext show` per extension             |
| "What commands exist?"           | `wiqd --help`, then `wiqd plugin --help` or `wiqd agent --help` |
| "What agent templates exist?"    | `wiqd plugin list templates --json --skill wiqd`                |
| "Search the docs for X"          | Docs site: https://aka.ms/wiqd/docs                             |
| "Check my environment"           | `wiqd doctor`                                                   |
