# Agent Validate

**Telemetry:** `--skill wiqd`

Validate declarative agent manifests and report diagnostics. Two validation modes:

- **Static** (default) — instant, offline MVL/rego checks. No auth needed.
- **Deep** — static first, then submits a built `.zip` to downstream validation services.

This workflow owns the end-to-end validation loop for the project — including the fix-and-re-validate cycle when called as a precondition by downstream workflows such as `references/wiqd-core/provision.md`, `references/wiqd-core/package.md`, and `workflows/partner-center.md`. Those workflows delegate to this one and trust its pass/fail outcome; they do not re-implement validation logic, diagnostic interpretation, or fix routing.

## When the user asks you to "fix it and re-validate"

If validation surfaced errors and the user explicitly asks you to fix them:

1. Apply the smallest correct change for each diagnostic (including obvious JSON/YAML syntax repairs such as a missing comma, brace, or quote — the user has authorized the fix, so the "do not auto-fix malformed JSON" guardrail below does not apply once they've said "fix it").
2. **Always re-run `wiqd agent validate --json --skill wiqd`** after applying the fix — never report a fix as done without re-validating. Re-validation is mandatory; the user needs proof the manifest is clean now. In your response, show the exact `wiqd agent validate` command you re-ran (write the command literally — don't paraphrase it as "re-validating") so the user can see and reproduce what was checked.
3. If the re-run still has errors, repeat (fix → re-validate) until it passes clean or a fix would require guessing, then report the outstanding diagnostics.

## Environment Resolution

Manifests often contain `${{VAR_NAME}}` placeholders (for example, `${{APP_NAME_SUFFIX}}`) that resolve at build/provision time from env files. If validation runs against **unresolved** placeholders, rego rules see literal `$`, `{`, `}` characters and may emit false-positive warnings such as `MVL30002` ("name field contains invalid characters").

To avoid this, `wiqd agent validate` resolves env vars **before** running rego, using the `--env` flag to select which env files to load:

```
env/.env.{env}          ← base values
env/.env.{env}.user     ← user-specific overrides (higher priority)
```

### Default behavior

- **`--env local`** (the default) — loads `env/.env.local` and `env/.env.local.user`.
- If the user specifies `--env dev`, loads `env/.env.dev` and `env/.env.dev.user`.

### Choosing the right environment

1. Check whether the project is provisioned by looking for files in `env/` such as `.env.local` or `.env.dev`.
2. Default to `local` for normal dev-time validation.
3. If the user names a target environment, pass it through with `--env <name>`.
4. If no env files exist at all, run without `--env` so unresolved placeholders surface as `atk-env-var` diagnostics.

### Example commands

```bash
wiqd agent validate --json --skill wiqd                    # Uses --env local (default)
wiqd agent validate --json --skill wiqd --env dev          # Resolve against dev environment
wiqd agent validate --json --skill wiqd --env local        # Explicit local (same as default)
```

## Validation Modes

### Static Mode (default)

```bash
wiqd agent validate --json --skill wiqd
wiqd agent validate --json --skill wiqd --env dev
wiqd agent validate --json --skill wiqd --path ./my-agent
```

Runs the MVL validation pipeline on raw project files. No network, no auth, and typically sub-second.

Checks include JSON syntax, schema validation, semantic rules, ATK env-var and file-reference resolution, and type mismatches. Reports all diagnostics with MVL codes and line/column positions.

### Deep Mode

```bash
# Step 1: Build the package first (see references/wiqd-core/package.md)
wiqd agent package --json --skill wiqd --env dev

# Step 2: Run deep validation with the built package
wiqd agent validate --json --skill wiqd --mode deep --env dev

# Or explicitly pass the package path:
wiqd agent validate --json --skill wiqd --mode deep --package-file appPackage/build/appPackage.dev.zip

# Filter to a single deep provider:
wiqd agent validate --json --skill wiqd --mode deep --provider mos
```

Runs static validation first. If it passes, submits the `.zip` to registered validation provider plugins (MOS, OMEX, TDP) for downstream service checks.

**Important:** Deep mode requires a pre-built app package. The handler does **not** build the package itself — run `wiqd agent package` first. If `--package-file` is omitted, the handler auto-discovers the most recent `.zip` in `appPackage/build/`. If no package is found, it exits with: `No app package found. Run 'wiqd agent package' first.`

If a provider's auth is not configured, that provider is skipped with a warning instead of becoming a blocking error.

## Validation Providers

The validate command uses a strategy pattern with pluggable providers:

| Provider | Mode   | Description                                         | Status         |
| -------- | ------ | --------------------------------------------------- | -------------- |
| **MVL**  | Static | Rego-based manifest validation (DiagnosticsService) | ✅ Implemented |
| **MOS**  | Deep   | MetaOS platform validation                          | ⏭️ Stub        |
| **OMEX** | Deep   | Office Marketplace validation                       | ⏭️ Stub        |
| **TDP**  | Deep   | Teams Developer Portal validation                   | ⏭️ Stub        |

Static always runs first. Deep providers only run if static passes.

## Diagnostic Codes

Errors from the manifest validation library (MVL) are prefixed with `MVL`:

| Code Range  | Category                          |
| ----------- | --------------------------------- |
| `MVL10xxx`  | JSON syntax and structural errors |
| `MVL20xxx`  | Schema validation errors          |
| `MVL30xxx`  | Semantic validation errors        |
| `MVL80xxx+` | First-party capability rules      |

Work IQ diagnostics use descriptive codes:

- `atk-env-var` — Environment variable reference issues
- `atk-file-ref` — File reference issues
- `type-mismatch` — Type validation errors
- `json-syntax` — JSON syntax errors

Deep providers use their own code prefixes: `MOS-xxx`, `OMEX-xxx`, `TDP-xxx`.

## Error Handling Protocol: Detect → Inform → Ask

When validation finds errors in a **standalone** invocation (for example, the user explicitly asked to validate an agent):

1. **Detect** — run validation and collect all diagnostics.
2. **Inform** — present **all** errors with codes, locations, and descriptions.
3. **Ask** — wait for the user to decide how to proceed. Do **not** auto-fix.

## Validation Gate — when called as a precondition

When this workflow is invoked as a **precondition** by another workflow such as `references/wiqd-core/provision.md`, `references/wiqd-core/package.md`, or `workflows/partner-center.md`, operate as a **gate** that drives the loop to a terminal pass/fail outcome. The downstream caller trusts the outcome and either proceeds on pass or stops on fail.

```
        ┌────────────────────────┐
        │  wiqd agent validate   │◄──────────┐
        │  (static, then deep    │           │
        │   when appropriate)    │           │
        └───────────┬────────────┘           │
                    │                        │
          pass      │      fail              │
       (zero errs)  │  (1+ errors)           │
                    │       │                │
                    │       ▼                │
                    │  ┌──────────────────┐  │
                    │  │  edit workflow   │  │
                    │  │  (smallest safe  │──┘
                    │  │   fix per error) │
                    │  └──────────────────┘
                    ▼
            ┌───────────────┐
            │  RETURN PASS  │ ──► caller proceeds
            └───────────────┘
```

### Required loop

1. **Validate** — run static validation. For packaging/publishing flows where the artifact will leave the developer's machine, build the package first with `wiqd agent package --json --skill wiqd` (see `references/wiqd-core/package.md`) and then run deep validation with `wiqd agent validate --json --mode deep --skill wiqd`. If the user is not authenticated, deep providers are skipped with a warning; continue with static-only.
2. **If validation passes** (exit `0`, zero errors) — return PASS to the caller. Surface warnings, but do not block.
3. **If validation fails** (any errors):
   - **Inform** — present every diagnostic with code, file path, line/column, and message, grouped by file. Do not summarize away errors.
   - **Route to fixes** — send unambiguous manifest fixes through `the edit workflow`, applying the smallest correct change per diagnostic. Do not rewrite unrelated content.
   - **Do not auto-fix** malformed JSON/YAML or invent missing config files. For those error classes, stop and ask the user.
   - **Re-validate** — return to step 1 against the modified files.
   - **Repeat** until validation passes with zero errors, the same error persists across two fix attempts, or a fix would require guesswork. In those failure cases, stop and return FAIL with the outstanding diagnostics.
4. **Never** return PASS while errors remain. **Never** suppress, downgrade, or rewrite a diagnostic just to make the loop terminate.

### Gate behavior under `--yolo` and non-interactive modes

The gate runs in **all modes**, including `--yolo` and non-interactive. In non-interactive mode, the gate may auto-route to `the edit workflow` for unambiguous fixes such as a schema enum typo or an unknown property name with an obvious correct spelling, but it **must** stop and surface FAIL for anything ambiguous such as parse errors, missing files, or conflicting fields.

Non-interactive does **not** mean “fix anything that moves.” It means “act on what is safe and report what is not.”

## LSP Server (`wiqd agent lsp`)

The validation engine is also available as a **Language Server Protocol (LSP) server** for real-time editor diagnostics. This is a hidden command and does not appear in `wiqd agent --help`.

```bash
wiqd agent lsp --skill wiqd
wiqd agent lsp --skill wiqd --verbose
```

### How it works

- Communicates over **stdin/stdout** (stdio transport) — editors launch the process and pipe JSON-RPC messages.
- Responds to `initialize` with server capabilities (`textDocument/didOpen`, `textDocument/didChange`, `textDocument/didClose`).
- Publishes diagnostics on `textDocument/didOpen` and `textDocument/didChange` for recognized manifest files such as `declarativeAgent.json` and `manifest.json`.
- Silently ignores files that do not match known manifest types.
- Re-validates open manifests when watched env files (`.env.*`) change.
- Resolves `${{VAR}}` placeholders from layered `.env.<env>` + `.env.<env>.user` files when inside an agent project.
- Requires **no authentication** for static validation.

### Lifecycle

- Cleanly shuts down (exit `0`) on the standard LSP `shutdown` + `exit` sequence.
- Returns exit code `130` on cancellation (`Ctrl+C` / `SIGINT`).
- Does **not** leave orphaned processes — the server terminates when the client disconnects.

### Good fits

- Editor integrations (VS Code, Neovim, etc.) for real-time manifest validation
- CI pipelines that want streaming diagnostics
- Any tooling that speaks LSP and needs manifest validation

## File-Based Fallback (when CLI is unavailable)

If `wiqd agent validate` cannot be run because of shell-tool failure, missing CLI install, or sandbox constraints:

1. **Structural validation** — inspect files directly:
   - Verify `appPackage/` exists with required files such as `declarativeAgent.json` and `manifest.json`
   - Check JSON syntax by reading and parsing each file
   - Verify required fields such as name, description, and version in `manifest.json`, plus instructions and capabilities in `declarativeAgent.json`
   - Check for `m365agents.yml` or `teamsApp.yml` at the project root
   - Look for unresolved `${{VAR_NAME}}` placeholders and confirm whether matching `env/.env.*` files exist
2. **Report findings** — present structural issues found via file inspection. Note that full MVL diagnostic codes are only available through the CLI, but common issues such as missing files, invalid JSON, and empty required fields can still be detected.
3. **State the limitations** — file-based validation cannot run rego rules, deep validation, or produce MVL diagnostic codes. Recommend using the full CLI path when those results are required.

## Safety Rules

- **NEVER** deploy when errors exist — fix first.
- **NEVER** silently suppress or ignore errors.
- **NEVER** return PASS to a caller while diagnostics include errors.
- **ALWAYS** report **all** diagnostics, not just the first one.
- **ALWAYS** include diagnostic codes in error reports.
- **ALWAYS** route fixes through `the edit workflow`; do not edit project files directly from this workflow.
