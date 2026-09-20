# Agent Migrate

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Migrate a previously built M365 declarative agent — supplied as a `.zip` app package or extracted folder — into a fresh wiqd project. This is the inverse of `agent-package`: zip in → editable project out.

## Source Requirements

The source must contain **both** `manifest.json` and `declarativeAgent.json` at its root. Accept:

- A `.zip` file (built app package)
- A directory containing the extracted package contents

If either file is missing → **STOP immediately.** Do NOT scaffold. Report clearly what files are expected vs found.

## Workflow

### Phase 1 — Inspect the source

1. If `.zip`: extract to temp directory using `Expand-Archive`
2. Verify `manifest.json` and `declarativeAgent.json` exist at root
3. Capture: agent name, description, developer info, icons, plugin files, localization, instructions (inline vs file reference)

### Phase 2 — Scaffold via create workflow (MANDATORY)

4. **Scaffold the project skeleton with `wiqd agent create`** — this is the only supported way to lay down a valid project. Read `references/wiqd-core/scaffolding-workflow.md` for the full rules, then run the canonical command, substituting the agent name from `manifest.json#name.short`:

   ```bash
   wiqd agent create -n <project-name> -c declarative-agent -with-plugin no -i false --skill wiqd
   ```

   Do NOT hand-author `manifest.json`/`declarativeAgent.json` yourself — always let `wiqd agent create` generate the skeleton first, then merge the source content in Phase 3.

### Phase 3 — Merge content into scaffold

5. **Manifest merge** — overwrite `appPackage/manifest.json` with source, but keep the scaffold's new `id` (default; confirm with user if in doubt)
6. **DeclarativeAgent merge** — overwrite `appPackage/declarativeAgent.json`, then rewrite `instructions`:
   - Inline string → write to scaffold's instructions file, set `instructions` to file reference matching scaffold's format
   - Already a file reference → copy referenced file content to scaffold's instructions file
7. **Icons** — copy `color.png` and `outline.png` into `appPackage/`
8. **Plugins** — copy plugin manifests and their OpenAPI specs into `appPackage/`
9. **Localization** — copy language files if `localizationInfo` is present
10. **Other assets** — copy only files referenced by manifest or declarativeAgent

### Phase 4 — Validate & report

11. Run `wiqd agent validate --skill wiqd`
12. Report summary: project path, files migrated, files skipped, new app id

## Instructions Handling — Core Contract

The agent's instructions MUST end up in the scaffold's instructions file (typically `appPackage/instructions.txt`) and `declarativeAgent.json` MUST reference that file. Never leave instructions inlined after migration. Always match the scaffold's reference syntax exactly.

## Critical Rules

- **NEVER** create `declarativeAgent.json` manually — always use the create workflow first
- **NEVER** scaffold into a directory with an existing agent project — use the create workflow
- **NEVER** mutate the source zip or folder
- **NEVER** silently change the app id — if keeping scaffold's new id (default), say so
- **NEVER** leave instructions inline in `declarativeAgent.json`
- **NEVER** copy unreferenced files — produce a clean project

**Preflight:** Verify source path exists and contains expected files.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
