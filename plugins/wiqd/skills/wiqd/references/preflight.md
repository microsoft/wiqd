# wiqd CLI Preflight Check

Run this check before any `wiqd` command to detect missing or broken installations.

**Windows installation prerequisite:** Before running any install or repair
command below (including uninstalling a broken CLI), follow the
[PowerShell 7+ prerequisite](install-update.md#windows-prerequisite-powershell-7).
The installer requires PowerShell 7+ (`pwsh.exe`), not Windows PowerShell 5.1.
Find and reuse an existing 7+ host, including installations not on PATH, rather
than unnecessarily installing or upgrading PowerShell. If none is available,
report the prerequisite blocker and determine the setup path with the user;
use step 6 while CLI installation is blocked.
An otherwise working CLI does not require a PowerShell upgrade.

## Recovery approval

For a missing or broken CLI, read `install-update.md`, show the exact target-specific command
from the applicable branch below, and ask for explicit approval using `ask_user` before
executing it. Explain that this installs or repairs the CLI prerequisite while preserving
the marketplace plugin and VS Code extension; repair also uninstalls the listed CLI packages.
Do not uninstall, install, or repair before approval, unless an existing explicit request
authorizes that exact operation and scope. A request to query or build an agent is not
installation consent. In a non-interactive context, do not install; show the command and
report the prerequisite blocker. If approval is declined or cancelled, do not mutate the
environment or repeat the prompt; use step 6.

## Procedure

1. Run `wiqd --version` using the powershell tool and observe **both stdout/stderr and exit code**.
   A command-not-found result is not a shell-tool failure: the shell executed the probe.
   If the shell cannot execute commands at all, use step 6 instead.

2. **Success** (exit 0, version string in stdout) → wiqd is working. Proceed with the skill workflow using CLI commands.


3. **Broken install** (exit ≠ 0, stderr contains `Cannot find module`, `ERR_MODULE_NOT_FOUND`, or `MODULE_NOT_FOUND`) → wiqd is on PATH but its npm package tree is corrupt or incomplete.
   - Tell the user: "✗ wiqd is installed but appears broken. Repair only the CLI prerequisite without replacing the marketplace plugin."
   - **Windows:** `npm uninstall -g @microsoft/wiqd; if ($LASTEXITCODE -eq 0) { iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipPlugin -SkipVSCode" }`
   - **macOS/Linux:** `npm uninstall -g @microsoft/wiqd && curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --skip-plugin --skip-vscode`
   - Do not run workflow commands with the broken CLI. After approval, execute the command for the current OS, then continue with step 5.

4. **Not installed** (command not found / not on PATH) → wiqd is not installed.
   - Tell the user: "ℹ wiqd CLI is not installed. Install only the CLI prerequisite without replacing the marketplace plugin."
   - **Windows:** `iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipPlugin -SkipVSCode"`
   - **macOS/Linux:** `curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --skip-plugin --skip-vscode`
   - After approval, execute the command for the current OS, then continue with step 5. Do not jump directly to file-based fallback.



5. **Verify recovery** — inspect the installer exit code and diagnostics. On a nonzero result,
   report the exact blocker and use step 6; do not loop or silently switch installer targets.
   - Run `wiqd --version` again in the command environment used for subsequent calls.
     If PATH is stale, inspect the installer-reported location or `npm prefix -g`, locate the
     verified installed shim (Windows: the prefix directory; macOS/Linux: its `bin` directory),
     and invoke it explicitly. Carry that resolution into subsequent shell calls; do not
     assume a child installer's PATH changes persist in the caller.
   - Only after exit 0 and a version string, resume the original workflow and execute the
     requested operation. Do not stop after installation or ask the user to repeat the request.
     Existing authentication and EULA consent gates still apply.
   - If verification still fails, report its actual error and use step 6. Do not claim installation success.

6. **Unavailable or blocked** — use this path only when approval was declined or cancelled,
   interaction is unavailable, an installation prerequisite is blocked, installation/verification failed,
   or the shell tool itself is unavailable or cannot execute commands.
   - Report the observed blocker. Use `view`, `glob`, and `grep` only for workflow steps that
     can actually be completed from available local evidence, and label partial results.
   - For requests requiring live tenant data (for example Work IQ feedback queries), file
     inspection is not a substitute. Report that the live request remains blocked; do not
     claim that the data was retrieved or that the original task succeeded.
   - Do not bypass WIQD by invoking upstream CLIs directly or via `npx` as an installation fallback.
