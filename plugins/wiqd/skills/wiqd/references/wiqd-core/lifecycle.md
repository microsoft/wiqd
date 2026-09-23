# Agent Lifecycle

**Telemetry:** `--skill wiqd` on every `wiqd` command.

## Delete / Uninstall (`wiqd agent uninstall` · alias `wiqd agent delete`)

`uninstall` is the preferred name; `delete` is a fully equivalent, non-breaking alias. Both accept the same flags and behave identically.

```bash
# env / project mode (default) — tears down a provisioned environment of a local project
wiqd agent uninstall [--env <name>] [--path <dir>] [--yes] [--keep-env-file] [--interactive] [--json] --skill wiqd

# title-id mode — tears down ANY agent you can administer, with NO local project required
wiqd agent uninstall --title-id <T_xxx> [--yes] [--json] --skill wiqd
```

**⚠️ ALWAYS warn the user BEFORE running this command.** Deletion is destructive and irreversible — it destroys cloud resources (Entra app registration, Teams app, bot framework registration). Explain what will be removed and ask for confirmation before executing.

- Destroys cloud resources — does NOT delete local project source files
- Requires confirmation unless `--yes` is passed; **never pass `--yes` unless the user explicitly asked to skip confirmation**
- `--keep-env-file` preserves `env/.env.<name>` for reference (keeps app IDs locally; env/project mode only)
- Deleting one environment (e.g., `--env staging`) does not affect other environments (dev, local)
- In env/project mode the command cleans up the environment's `env/.env.<name>` file unless `--keep-env-file` is used
- If not provisioned (no env file found) → report nothing to delete; suggest the provision workflow or `--title-id` to delete by Title ID instead

**Title-ID mode (`--title-id`) — project-less teardown.** When `--title-id` is set, the command deletes the agent **by its Title ID alone**: it skips the project-structure and provisioned-env-file preflight, runs from **any directory** (no local project required), and touches **no local files**. Both Title ID forms are accepted — `T_xxx` or `T_xxx.declarativeAgent` (the dotted suffix is stripped before the id reaches ATK). Use this to clean up orphaned agents when there is no checked-out project:

```bash
# Find the Title ID, then uninstall by it — works from anywhere
wiqd agent list --id T_ --skill wiqd
# After the user confirms this exact Title ID:
wiqd agent uninstall --title-id T_xxxxxxxx --yes --skill wiqd
```

**🚫 Never bypass wiqd.** To tear down an agent, ALWAYS use `wiqd agent uninstall --title-id <id>` (or `wiqd agent delete --title-id <id>`). Do NOT call `teamsapp uninstall`, `atk uninstall`, or the Teams Admin Center / Azure portal directly — wiqd owns the confirmation, mode selection, error mapping, and env-file cleanup contract.

## Preview link

`wiqd agent provision` prints the M365 Copilot deep link when the environment
contains `M365_TITLE_ID`. Re-run provision after agent changes and use that link
to preview the updated agent.

## Env (`wiqd agent env`)

```bash
wiqd agent env list [--json] --skill wiqd
wiqd agent env add --name <name> --skill wiqd
wiqd agent env reset --env <name> --skill wiqd
```

After add/reset → suggest _"provision my agent"_.

**Preflight:** env commands require the lifecycle file + `appPackage/manifest.json`. **env/project-mode** uninstall/delete requires them too; **title-id-mode** uninstall/delete (`--title-id`) skips the project preflight entirely and needs no local project.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
