---
title: wiqd plugin package
description: Build a deployable Microsoft 365 app-package ZIP for a declarative agent.
---

# `wiqd plugin package`

Build the current marked plugin project into a deployable `.zip`. The
`microsoft.wiqd.core` extension runs fx-core in process, resolves the selected environment, and
reports the generated path and size.

To submit the resulting ZIP unchanged, use
[`wiqd plugin publish --package-file <zip>`](/cli/plugin-publish/).
Project-mode publishing instead runs its YAML lifecycle and may rebuild.

```bash
wiqd plugin package [--env <name>] [--output <zip>] [--path <project>]
                    [--offline] [--include-file <file>] [--prepare-for-certification]
```

## Options

| Option       | Default | Description                                      |
| ------------ | ------- | ------------------------------------------------ |
| `--env`      | `local` | Environment used to resolve manifest variables   |
| `--output`   | —       | Absolute or relative destination for the ZIP     |
| `--path`     | `.`     | Plugin project directory                         |
| `--offline` | off | Build a local-only devPreview connector/skill ZIP without provisioning or network |
| `--include-file` | — | Include one regular, contained project file unchanged at the ZIP root |
| `--prepare-for-certification` | off | Emit normal and validation connector-reference variants; alias `--prepareForCertification` |
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

The same fail-fast check applies to `wiqd plugin provision`, normal `wiqd plugin package`, and
normal `wiqd plugin publish`. It reads only declared references and never rewrites the project. The
generated/TypeSpec identity check applies to package and normal publish, where the SDK builds a ZIP.

## Certification packages

First create the connector with
[`wiqd connector add --prepare-for-certification`](/cli/connector/#prepare-a-connector-for-certification)
and separately compose its exact returned `shared_...` reference into your plugin.
Keep the complete `shared_<apiId>-<tenantId>` reference in the authored manifest;
do not remove the tenant suffix or append `_validation` yourself.

```powershell
wiqd plugin package --env dev --prepare-for-certification --output .\dist\inventory.zip --json
# Or an explicit local-only preview package without provisioning:
wiqd plugin package --offline --prepareForCertification --output .\dist\inventory-local.zip --json
```

The command builds once and emits the selected primary ZIP plus a second ZIP with
`.validation` inserted before `.zip`. With no `--output`, these are
`appPackage/build/appPackage.<env>.zip` and
`appPackage/build/appPackage.<env>.validation.zip`.
Both destinations must be absent; choose a fresh output name instead of overwriting.

Only the primary ZIP changes
`agentConnectors[].toolSource.openApiConnector.authorization.referenceId` or the
equivalent `remoteMcpServer` field when its type is `ConnectionVault`:
`shared_<apiId>-<tenantId>` becomes `shared_<apiId>` by removing only the terminal
hyphen and 36-character tenant GUID. Hyphens and underscores inside the API ID
are preserved: `shared_ronak-test-<tenantId>` becomes `shared_ronak-test`.
The validation ZIP keeps the full original references, including GUID casing,
and packaged manifest bytes. No `_validation` suffix is appended. All other
manifest values and member bytes remain the same; the source manifest is unchanged.
Other authorization types are untouched. No eligible references, malformed IDs,
references without a trailing nonzero tenant GUID, or IDs exceeding 128 characters
fail without publishing a pair. A failed second publication rolls back the first;
existing files are never overwritten.

Human output identifies both ZIPs. JSON additionally returns
`validationOutputPath` and `validationSizeBytes`; ordinary packaging omits them.
`--include-file` includes the same bytes in both artifacts. No CMS/Marketplace
request or certification approval occurs during packaging. `--mock` refuses paired
packaging rather than claim verified artifacts; use `--offline` without mock for
real local ZIPs. Offline mode supports only the documented preview connector/skill
surfaces, persists a local package GUID when needed, and does not establish server acceptance.
Offline packaging validates the reference shape without tokens, authentication,
or network; it cannot verify the current signed-in tenant. That tenant comparison
belongs to live certification connector creation.

## Examples

```bash
# Package the documentation's example environment
wiqd plugin package --env dev

# Named environment and output
wiqd plugin package --env dev --output ./dist/claims-agent.zip

# CI output
wiqd plugin package --env dev --json
```

## Output

Human-readable output reports the ZIP path, size, and environment. `--json` returns the shared
envelope with:

```json
{
  "schemaVersion": "2.1",
  "status": "success",
  "command": "plugin.package",
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "data": {
    "outputPath": "C:\\src\\agent\\appPackage\\build\\appPackage.dev.zip",
    "sizeBytes": 12697,
    "sizeDisplay": "12.4 KB",
    "environment": "dev",
    "offline": false,
    "nextSteps": [
      {
        "command": "wiqd plugin publish --env dev",
        "description": "Submit the packaged plugin to the org catalog for administrator approval"
      },
      {
        "command": "wiqd plugin share --env dev",
        "description": "Grant access to specific users or your whole tenant"
      }
    ]
  }
}
```

Human output and JSON present the same ordered next steps, preserving the resolved
`--env` (`local` when omitted). Simple names such as `dev`, `test-west` and `qa_2`
appear directly in commands. Other valid names remain supported: their next steps
show only the intended operation's `--help` command, with the exact selected value
as a JSON string in the description and instructions to pass it manually to
`--env` using your shell's quoting/escaping. The JSON string is not shell syntax;
the help command does not execute publication or sharing. No environment rename or
migration is required.
With `--offline`, both modes recommend only `wiqd plugin show` and
`wiqd plugin package --help`, never cloud operations.

Packaging succeeds only when fx-core succeeds and the resulting ZIP exists and is non-empty.

## Related commands

- [`wiqd plugin provision`](/cli/reference/#wiqd-plugin-provision) — create or update the selected
  environment before packaging.
- [`wiqd plugin validate --mode source`](/cli/plugin-validate/) — offline saved-source checks
  with the same packaging path/environment; the coding-agent workflow runs this before building.
- [`wiqd plugin validate --mode package`](/cli/plugin-validate/) — validate the exact
  built ZIP. Marketplace mode includes package and policy checks; neither mode builds.
- [Agent lifecycle](/concepts/agent-lifecycle/) — the full authoring flow.
