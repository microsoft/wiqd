# wiqd CLI Preflight Check

Run this check before any `wiqd` command to detect missing or broken installations.

## Procedure

1. Run `wiqd --version` using the powershell tool and observe **both stdout/stderr and exit code**.

2. **Success** (exit 0, version string in stdout) → wiqd is working. Proceed with the skill workflow using CLI commands.


3. **Broken install** (exit ≠ 0, stderr contains `Cannot find module`, `ERR_MODULE_NOT_FOUND`, or `MODULE_NOT_FOUND`) → wiqd is on PATH but its npm package tree is corrupt or incomplete.
   - Tell the user: "✗ wiqd is installed but appears broken. Repair only the CLI prerequisite without replacing the marketplace plugin."
   - **Windows:** `npm uninstall -g @microsoft/wiqd; if ($LASTEXITCODE -eq 0) { iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipPlugin -SkipVSCode" }`
   - **macOS/Linux:** `npm uninstall -g @microsoft/wiqd && curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --skip-plugin --skip-vscode`
   - Do NOT proceed with any wiqd commands — they will all fail with the same error.
   - **Continue with step 5** (file-based fallback) — the skill can still operate on project files directly.

4. **Not installed** (command not found / not on PATH) → wiqd is not installed.
   - Tell the user: "ℹ wiqd CLI is not installed. Install only the CLI prerequisite without replacing the marketplace plugin."
   - **Windows:** `iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipPlugin -SkipVSCode"`
   - **macOS/Linux:** `curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --skip-plugin --skip-vscode`
   - **Continue with step 5** (file-based fallback) — the skill can still operate on project files directly.



5. **File-based fallback** — use this path for a broken install (step 3), a missing install (step 4), or when the powershell tool itself returns `success=false` or is unavailable.
   - For shell tool failure, note internally that the execution environment does not support CLI commands (for example, a sandboxed eval or restricted permissions).
   - **Do NOT stop.** Note internally that wiqd CLI is unavailable.
   - **Continue the skill workflow using file-based alternatives.** Use `view`, `glob`, and `grep` tools to read project files directly instead of running CLI commands.
   - Each skill's instructions include file-based fallback paths for when CLI commands are unavailable. Follow those instead.
   - This is the expected path in eval/sandbox environments. The skill should still complete successfully using file inspection.
