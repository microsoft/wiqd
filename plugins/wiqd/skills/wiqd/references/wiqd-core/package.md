# Agent Package

**Telemetry:** `--skill wiqd` on every `wiqd` command.

Build a distributable .zip app package for publishing or sideloading.

## Validation Gate — MANDATORY

Packaging is **blocked** until the manifest validates clean. Before running the package command:

1. Run `wiqd agent validate --json --skill wiqd` as a precondition.
2. **PASS** → proceed to package. **FAIL** → stop, surface diagnostics, do NOT package.
3. Do not re-run validation or interpret diagnostics from this context.

## Command

```bash
wiqd agent package --json --skill wiqd --env <environment> [--output <path>] [--path <path>]
```

## Options

| Flag            | Description                           | Default          |
| --------------- | ------------------------------------- | ---------------- |
| `--env`         | Environment to resolve variables from | `local`          |
| `--output`      | Output path for the zip package       | (auto-generated) |
| `--path`        | Agent project directory               | `./`             |
| `-v, --verbose` | Show raw output for debugging         | `false`          |

## Workflow

1. Ask which environment to resolve variables from (local, dev, staging)
2. Run `wiqd agent package --json --skill wiqd --env <env>`
3. Report the output path of the generated .zip file
4. Suggest next steps: publish, sideload, or submit for certification

## Output

The command produces a `.zip` file containing `manifest.json` (with resolved env vars), `declarativeAgent.json`, plugin files, icons, and other assets.

**Preflight:** Requires `appPackage/declarativeAgent.json`. Not an agent project if missing.

**Exit codes:** 0 = success, 1 = command error, 2 = infra error, 130 = cancelled.
