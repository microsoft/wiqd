# Agent Validate

**Telemetry:** `--skill wiqd`

Validate saved declarative agent source or a final package and report findings. Three validation modes:

- **Source** (explicit `--mode source`) — offline diagnostics on saved source. No auth needed.
- **Package** (default) — submits a captured, already-built `.zip` to TDP through Core.
- **Marketplace** — package validation plus StoreOps policy checks on the same captured ZIP.

Explicit validation, result interpretation and authorized repair belong to `workflows/validation.md`, contributed by `microsoft.validate`; detailed guidance lives under `references/validate/`. This Core reference supplies the source precondition for lifecycle callers such as `references/wiqd-core/provision.md`, `references/wiqd-core/package.md`, and editing/publishing workflows. Those callers trust its pass/fail outcome; they do not maintain a competing validation or repair loop. Account setup and publication keep their existing owners.

## When the user asks you to "fix it and re-validate"

If validation surfaced errors and the user explicitly asks you to fix them:

1. Hand the identified result, original mode and confirmed project/environment to `workflows/validation.md`. That workflow applies the smallest correct change for each diagnostic, including explicitly authorized JSON/YAML syntax repairs; a validation request alone does not authorize edits.
2. **Always re-validate the original mode** after applying the fix — never report a fix as done without re-validating. For lifecycle source findings, re-run `wiqd agent validate --mode source --path "<project>" --env "<environment>" --json --skill wiqd`. In your response, show the exact command re-run, not just "re-validating". Package/Marketplace repair follows `references/validate/autofix.md` with the explicit new ZIP and fresh applicable evidence.
3. If the re-run still has errors, the validation workflow continues within its two-round repair limit or reports a concrete blocker. Core resumes a previously authorized lifecycle operation only after source passes; it does not start a second repair loop or infer deployment/publication consent.

## Environment Resolution

Manifests often contain `${{VAR_NAME}}` placeholders (for example, `${{APP_NAME_SUFFIX}}`) that resolve at build/provision time from env files. If validation runs against **unresolved** placeholders, rego rules see literal `$`, `{`, `}` characters and may emit warnings such as `MVL30002` ("name field contains invalid characters").

`wiqd agent validate --mode source` resolves env vars **before** running rego, using the `--env` flag to select which env files to load:

```
env/.env.{env}          ← base values
env/.env.{env}.user     ← user-specific overrides (higher priority)
```

### Default behavior

- **`--env local`** (the default) — loads `env/.env.local` and `env/.env.local.user`.
- If the user specifies `--env dev`, loads `env/.env.dev` and `env/.env.dev.user`.
- Source uses only the selected project's environment pair, not another environment or an ancestor project's files.

### Choosing the right environment

1. Check the selected project's env files and the lifecycle operation's intended environment.
2. Default to `local` for normal dev-time validation when no other environment is selected.
3. If the user or caller names a target environment, pass it through with `--env <name>` and the same explicit `--path`.
4. If no env files exist, retain the selected environment and report unresolved `atk-env-var` diagnostics. Source treats missing deployment-generated values as advisory; do not invent IDs or files before provisioning. Syntax, type and file-reference errors still block.

### Example commands

```bash
wiqd agent validate --mode source --path "<project>" --json --skill wiqd                    # Uses --env local (default)
wiqd agent validate --mode source --path "<project>" --json --skill wiqd --env dev          # Resolve against dev environment
wiqd agent validate --mode source --path "<project>" --json --skill wiqd --env local        # Explicit local (same as default)
```

## Validation Modes

### Source Mode (offline)

```bash
wiqd agent validate --mode source --path "<project>" --env "<environment>" --json --skill wiqd
wiqd agent validate --mode source --json --skill wiqd --env dev --path ./my-agent
```

Runs the shared diagnostics service on saved `appPackage/declarativeAgent.json`. No network, auth, ZIP or build is required. It does not launch LSP or write an HTML/report directory. Read the returned checked-file list rather than claiming whole-project or final-package coverage.

Checks include JSON syntax, schema validation, semantic rules, environment/file-reference resolution and type mismatches. Report the actual diagnostic codes, severities and locations. JSON locations are zero-based; human table locations are one-based.

### Package Mode (default)

For an authorized source build, source-check the same project/environment before packaging:

```bash
wiqd agent validate --mode source --path "<project>" --env dev --json --skill wiqd
# Only after source succeeds and the build is authorized:
wiqd agent package --path "<project>" --json --skill wiqd --env dev --output "<new-absolute.zip>"
```

Then hand the exact returned ZIP to `workflows/validation.md` for `--mode package --package-file "<zip>"`. Package validation uploads a read-only temporary copy of the captured ZIP to TDP through Core. It does not first run source validation or build automatically.

**Important:** Select an existing ZIP explicitly. Without `--package-file`, the CLI requires exactly one nonrecursive ZIP in `appPackage/build/` under the selected `--path`; it never selects the newest ZIP. Missing/ambiguous selection fails, and `--env` does not select a ZIP. Missing authentication or unavailable selected checks remain incomplete, not skipped warnings that permit a pass.

### Marketplace Mode

Use `workflows/validation.md` for `--mode marketplace`: it owns listing confirmation, current-host evidence and TDP plus StoreOps checks on the same captured ZIP. Do not add Marketplace checks to an offline source gate. Validation does not publish, and a passing result is not official approval.

Both `wiqd agent validate` and `wiqd plugin validate` use `source`, `package` (default), and `marketplace`. Old `static`, `deep`, `manifest`, comma-combined modes and `--provider` are unsupported, not aliases. Plugin source additionally requires readable `wiqd.plugin.json` and `appPackage/manifest.json`; no declarative-agent source means empty coverage, not whole-plugin acceptance. Package/Marketplace can validate a ZIP without source-project guards. Use compatible CLI/plugin releases and a fresh host session; CLI installation alone does not refresh plugin guidance. No validation experiment flag is required.

## Validation Providers

The canonical validation runtime selects the checks for the requested mode:

| Provider | Mode | Description |
| -------- | ---- | ----------- |
| **MVL** | Source | Shared manifest diagnostics service, also used by LSP |
| **TDP** | Package / Marketplace | Core's typed package-validation API |
| **StoreOps** | Marketplace | Policy/evidence library; policy results remain separate from package findings |

Source is an independent offline path, not an automatic first phase of package validation. A package rejection or unavailable TDP result does not suppress independent Marketplace findings. Read `validation.result` for the overall verdict, not policy-only `report.result`.

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

Package checks retain their returned provider codes; do not invent MOS/OMEX/TDP prefixes or convert package diagnostics into StoreOps policy identities. Marketplace policies use their reported SubPolicy numbers.

## Error Handling Protocol: Detect → Inform → Ask

When validation finds errors in a **standalone** invocation (for example, the user explicitly asked to validate an agent), the canonical validation workflow owns the result and next action:

1. **Detect** — run validation and collect all diagnostics.
2. **Inform** — present **all** errors with codes, locations, and descriptions.
3. **Ask** — wait for the user to decide how to proceed. Do **not** auto-fix.

## Validation Gate — when called as a precondition

When this reference is invoked as a **precondition** by another workflow such as `references/wiqd-core/provision.md`, `references/wiqd-core/package.md`, or `workflows/partner-center.md`, run a source **gate** against the same project/environment. The downstream caller trusts the outcome and either proceeds on pass or stops on fail. Authorized fixes are delegated to the canonical validation workflow.

```
        ┌────────────────────────┐
        │  wiqd agent validate   │◄──────────┐
        │  (source; same project │           │
        │   and environment)     │           │
        └───────────┬────────────┘           │
                    │                        │
          pass      │      fail              │
       (zero errs)  │  (1+ errors)           │
                    │       │                │
                    │       ▼                │
                    │  ┌──────────────────┐  │
                    │  │ validation owner │  │
                    │  │  (authorized     │──┘
                    │  │   scoped repair) │
                    │  └──────────────────┘
                    ▼
            ┌───────────────┐
            │  RETURN PASS  │ ──► caller proceeds
            └───────────────┘
```

### Required loop

1. **Validate** — run `wiqd agent validate --mode source --path "<project>" --env "<environment>" --json --skill wiqd`. Never run default package validation or build a ZIP merely to satisfy this precondition.
2. **If validation passes** (exit `0`, completed source `validation.result: PASSED`, zero errors) — return PASS to the caller. Surface warnings, but do not block. Read success `data` or completed non-pass `error.data`; malformed output, cancellation or missing CLI/project is a blocker, not a pass.
3. **If validation fails** (any errors):
   - **Inform** — present every diagnostic with code, file path, line/column, and message, grouped by file. Do not summarize away errors.
   - **Route to fixes** — only when authorized, hand findings and the same project/environment to `workflows/validation.md`. Do not rewrite unrelated content or run a competing Core edit/repair loop.
   - **Do not auto-fix** malformed JSON/YAML or invent missing config files without authorization. An explicit repair request permits grounded syntax repairs; missing business values, ambiguous changes or service access remain blockers.
   - **Re-validate** — the validation workflow rechecks the original source scope after its edits. Resume the caller only after a completed source pass; recheck after further changes.
   - **Stop** on no authorization, guesswork, no progress or the validation workflow's two-round limit, and return FAIL with the outstanding diagnostics.
4. **Never** return PASS while errors remain. **Never** suppress, downgrade, or rewrite a diagnostic just to make the loop terminate.

This is a workflow gate, not a new backend gate on direct lifecycle CLI calls. Passing source does not prove final-ZIP acceptance or that provision uploads previously validated bytes; provision builds its own artifact. Final-package and publishing checks remain separate under their owning workflows.

### Gate behavior under `--yolo` and non-interactive modes

The gate runs in **all modes**, including `--yolo` and non-interactive. Neither mode grants repair consent. Without explicit repair authorization, stop and surface FAIL; authorized unambiguous fixes stay with the canonical validation workflow. Parse errors, missing files or conflicting fields requiring guesses remain blockers.

Non-interactive does **not** mean “fix anything that moves.” It means “act on what is authorized and safe, and report what is not.”

## LSP Server (`wiqd agent lsp`)

The validation engine is also available as a **Language Server Protocol (LSP) server** for real-time editor diagnostics. This is a hidden command and does not appear in `wiqd agent --help`.

```bash
wiqd agent lsp --skill wiqd
wiqd agent lsp --skill wiqd --verbose
```

### How it works

- Communicates over **stdin/stdout** (stdio transport) — editors launch the process and pipe JSON-RPC messages.
- Responds to `initialize` with server capabilities and handles `textDocument/didOpen`, `textDocument/didChange`, and `textDocument/didClose`.
- Publishes diagnostics for recognized manifest files such as `declarativeAgent.json` and `ai-plugin.json`.
- Silently ignores files that do not match known manifest types.
- Re-validates open manifests when watched env files (`.env.*`) change.
- Resolves `${{VAR}}` placeholders from layered `.env.<env>` + `.env.<env>.user` files when inside an agent project.
- Requires **no authentication** for local validation.

Do not pass global `--json`: stdout belongs to the LSP protocol, and the host rejects JSON mode before startup with exit `2`. Editor-injected arguments are not forwarded to the native server.

### Lifecycle

- Cleanly shuts down (exit `0`) on the standard LSP `shutdown` + `exit` sequence.
- Returns exit code `130` on cancellation (`Ctrl+C` / `SIGINT`).
- Does **not** leave orphaned processes — the server terminates when the client disconnects.

### Good fits

- Editor integrations (VS Code, Neovim, etc.) for real-time manifest validation
- Tooling that needs streaming editor diagnostics
- Any tooling that speaks LSP and needs manifest validation

For finite offline CI checks, use source mode instead of a long-lived LSP server.

## File-Based Fallback (when CLI is unavailable)

If `wiqd agent validate` cannot be run because of shell-tool failure, missing CLI install, or sandbox constraints:

1. **Structural validation** — inspect files directly:
   - Verify `appPackage/` exists with required files such as `declarativeAgent.json` and `manifest.json`
   - Check JSON syntax by reading and parsing each file
   - Verify required fields such as name, description, and version in `manifest.json`, plus instructions and capabilities in `declarativeAgent.json`
   - Check for `m365agents.yml` or `teamsapp.yml` at the project root
   - Look for unresolved `${{VAR_NAME}}` placeholders and confirm whether matching `env/.env.*` files exist
2. **Report findings** — present structural issues found via file inspection. Note that full MVL diagnostic codes are only available through the CLI, but common issues such as missing files, invalid JSON, and empty required fields can still be detected.
3. **State the limitations** — file inspection cannot run rego rules or package/Marketplace validation, or produce MVL diagnostic codes. Recommend using the full CLI path when those results are required. It never satisfies the lifecycle source gate or authorizes packaging, deployment or publication.

## Safety Rules

- **NEVER** deploy when errors exist — fix first.
- **NEVER** silently suppress or ignore errors.
- **NEVER** return PASS to a caller while diagnostics include errors or execution is incomplete.
- **ALWAYS** report **all** diagnostics, not just the first one.
- **ALWAYS** include diagnostic codes in error reports.
- **ALWAYS** route authorized validation fixes through `workflows/validation.md`; do not edit project files directly from this reference.
