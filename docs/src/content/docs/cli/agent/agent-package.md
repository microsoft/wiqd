---
title: wiqd agent package
description: Build a deployable Microsoft 365 app-package ZIP for a declarative agent.
---

# `wiqd agent package`

Build the current declarative-agent project into a deployable `.zip`. The
`microsoft.wiqd.core` extension runs fx-core in process, resolves the selected environment, and
reports the generated path and size.

```bash
wiqd agent package [--env <name>] [--output <zip>] [--path <project>]
```

## Options

| Option       | Default | Description                                      |
| ------------ | ------- | ------------------------------------------------ |
| `--env`      | `local` | Environment used to resolve manifest variables   |
| `--output`   | —       | Absolute or relative destination for the ZIP     |
| `--path`     | `.`     | Agent project directory                          |
| `--json`     | off     | Emit the shared machine-readable result envelope |
| `--verbose`  | off     | Show additional sanitized diagnostics on stderr  |

## Packaging-reference checks

Before fx-core starts, WIQD reads `appPackage/manifest.json` and follows each
`copilotAgents.declarativeAgents[].file` reference. It rejects:

- missing, malformed, absolute, traversing, or symlink-escaping DA and DA skill paths;
- a DA-only `agent_skills[].folder` that fx-core would omit while the `agent-skills` flag is off;
- local `worker_agents[].file` entries, which this bundled lifecycle does not support.
- projects with `appPackage/.generated/manifest.json` or an active `typeSpec/compile` lifecycle.
  The pinned SDK can generate or prefer that manifest after preflight, so WIQD fails closed rather
  than claiming that it validated the exact manifest placed in the ZIP.

Published Worker references using `worker_agents[].id` remain supported. App-manifest
`agentSkills[]` Cowork skills and DA-manifest `agent_skills[]` Chat skills are separate sets; you
do not need to register a skill on both surfaces. If both entries intentionally point at the same
folder, the top-level registration already includes those bytes.

For a hand-authored DA-only skill, enable packaging support before package or provision:

```bash
wiqd config flags set agent-skills true
```

The same fail-fast check applies to `wiqd agent provision`, `wiqd plugin package`, and
`wiqd plugin provision`. It reads only declared references and never rewrites the project. The
generated/TypeSpec identity check applies to package and normal publish, where the SDK builds a ZIP.

## Examples

```bash
# Package the documentation's example environment
wiqd agent package --env dev

# Named environment and output
wiqd agent package --env dev --output ./dist/claims-agent.zip

# CI output
wiqd agent package --env dev --json
```

## Output

Human-readable output reports the ZIP path, size, and environment. `--json` returns the shared
envelope with:

```json
{
  "schemaVersion": "2.1",
  "status": "success",
  "command": "agent-package",
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "data": {
    "outputPath": "C:\\src\\agent\\appPackage\\build\\appPackage.dev.zip",
    "sizeBytes": 12697,
    "sizeDisplay": "12.4 KB",
    "environment": "dev"
  }
}
```

Packaging succeeds only when fx-core succeeds and the resulting ZIP exists and is non-empty.

## Related commands

- [`wiqd agent provision`](/cli/reference/#wiqd-agent-provision) — create or update the selected
  environment before packaging.
- [`wiqd agent validate`](/cli/reference/#wiqd-agent-validate) — run static validation.
- [`wiqd agent validate --mode deep`](/cli/reference/#wiqd-agent-validate) — validate an already
  built package; deep validation does not build one.
- [Agent lifecycle](/concepts/agent-lifecycle/) — the full authoring flow.
