# Agent Package

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Build a distributable .zip app package for publishing or sideloading.

## Validation Gate — MANDATORY

In this workflow, packaging is **blocked** until saved source validates clean. Before running the package command:

1. Run `wiqd agent validate --mode source --json --skill wiqd --env <environment> --path <path>` as a precondition, using the same environment and explicit project path that will be packaged.
2. **PASS** → proceed to package. **FAIL** → stop, surface diagnostics, do NOT package.
3. For authorized repairs, use `workflows/validation.md` and return only after same-mode source revalidation passes. Do not call default package validation before building or recurse through packaging.

This is a workflow gate, not a new mandatory backend gate on direct package calls. Source checks
do not prove final ZIP acceptance; validate the returned ZIP with `--mode package` or
`--mode marketplace` when requested. No validation mode builds automatically.

## Command

```bash
wiqd agent package --json --skill wiqd --env <environment> [--output <path>] [--path <path>] [--include-file <path>]
```

## Options

| Flag            | Description                           | Default          |
| --------------- | ------------------------------------- | ---------------- |
| `--env`         | Environment to resolve variables from | `local`          |
| `--output`      | Output path for the zip package       | (auto-generated) |
| `--path`        | Agent project directory               | `./`             |
| `--include-file` | One project file included unchanged at the ZIP root | unset |
| `-v, --verbose` | Show raw output for debugging         | `false`          |

## Workflow

1. Ask which environment to resolve variables from (local, dev, staging)
2. Run `wiqd agent package --json --skill wiqd --env <env>`
3. Report the output path of the generated .zip file
4. Suggest next steps: publish, sideload, or submit for certification

## Bundled Reference Preflight

Before fx-core runs, WIQD follows every
`appPackage/manifest.json#copilotAgents.declarativeAgents[].file` entry. It does not assume the
agent is named `appPackage/declarativeAgent.json`.

- DA-only `agent_skills[].folder` content requires the evaluated `agent-skills` flag unless a
  top-level `agentSkills[].folder` registration already packages the same folder. Cowork and DA
  Chat skill sets may be deliberately different; do not add a second registration just to satisfy
  packaging.
- For a hand-edited DA-only skill, run
  `wiqd config flags set agent-skills true` before package or provision.
- Local `worker_agents[].file` references are unsupported by this bundled lifecycle. Use the
  canonical published `worker_agents[].id`.
- Missing, malformed, absolute, traversing, or symlink-escaping declared paths fail before the SDK
  call. WIQD reads only declared references and does not rewrite the project.
- WIQD currently fails closed when `appPackage/.generated/manifest.json` exists or the active
  lifecycle file contains `typeSpec/compile`. The pinned SDK can generate or prefer that manifest
  after preflight, so WIQD cannot yet guarantee that the validated manifest is the packaged one.
  Remove stale generated output and use a non-TypeSpec lifecycle before retrying.

## Output

The command produces a `.zip` file containing `manifest.json` (with resolved env vars), its
referenced declarative-agent manifest files, plugin files, icons, and other assets.

**Preflight:** Requires `appPackage/manifest.json`; declarative-agent files are discovered through
its `copilotAgents.declarativeAgents[].file` references.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.

## Explicit supplemental file

Only files referenced by the manifest are automatically packaged. To include one
additional file without manual ZIP editing:

```bash
wiqd agent package --include-file ./appPackage/release-metadata.json --output ./dist/agent.zip --skill wiqd --workflow wiqd-core
```

The path resolves from the selected project (`--path`), not the shell directory.
The file must be a regular, non-symlink file contained in that project; its
basename becomes the ZIP-root entry. Its contents are copied exactly, not
interpreted or rewritten. Existing member names, including case-insensitive
matches, cannot be overwritten. Files and completed ZIPs are limited to 64 MiB.
Inclusion builds and verifies a staged archive before replacing the final ZIP;
errors, changed inputs, and cancellation leave any previous final ZIP intact.
Omitting the option preserves ordinary packaging. `wiqd plugin package` supports
the same option. Packaging is not a store-policy or publication approval.
