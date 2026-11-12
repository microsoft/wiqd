# wiqd CLI Preflight Check

Run this check before any `wiqd` command to detect missing or broken installations.

**Windows web-installer prerequisite:** Before running the web installer
(including its use after an authorized repair), follow the
[PowerShell 7+ prerequisite](install-update.md#windows-prerequisite-powershell-7).
The installer requires PowerShell 7+ (`pwsh.exe`), not Windows PowerShell 5.1.
Find and reuse an existing 7+ host, including installations not on PATH, rather
than unnecessarily installing or upgrading PowerShell. If none is available,
report the prerequisite blocker and determine the setup path with the user;
use step 6 while CLI installation is blocked.
An otherwise working CLI does not require a PowerShell upgrade.

## Recovery approval

For a missing or broken CLI, read `install-update.md`, show the exact target-specific command
and resolved version from its conversational bootstrap, and ask for explicit approval using `ask_user` before
executing it. Explain that this installs or repairs the CLI prerequisite while preserving
the marketplace plugin and VS Code extension; repair also uninstalls the listed CLI packages.
Do not uninstall, install, or repair before approval, unless an existing explicit request
authorizes that exact operation and scope. A request to query or build an agent is not
installation consent. A human-attended conversation with a non-TTY command subprocess
can obtain approval; lack of a terminal alone is not lack of a human.
In an unattended context, do not install; show the command and
report the prerequisite blocker. If approval is declined or cancelled, do not mutate the
environment or repeat the prompt; use step 6.

## Procedure

1. Run `wiqd --version` using the powershell tool and observe **both stdout/stderr and exit code**.
   A command-not-found result is not a shell-tool failure: the shell executed the probe.
   If the shell cannot execute commands at all, use step 6 instead.

2. **Success** (exit 0, version string in stdout) → wiqd is working. Proceed with the skill workflow using CLI commands.

   For an existing local project, do not recreate or copy a replacement project
   as a preflight step. Continue with the requested project-scoped `wiqd plugin`
   command. WIQD recognizes contained `m365agents.yml` and
   `appPackage/manifest.json` read-only, derives name/capabilities from the root
   manifest, and validates only the command-required component closure.
   Missing/unsafe structure fails with exit 2; malformed manifest/name/reference
   data fails with exit 1 without changing user data.


3. **Broken install** (exit ≠ 0, stderr contains `Cannot find module`, `ERR_MODULE_NOT_FOUND`, or `MODULE_NOT_FOUND`) → wiqd is on PATH but its npm package tree is corrupt or incomplete.
   - Tell the user: "✗ wiqd is installed but appears broken. Repair only the CLI prerequisite without replacing the marketplace plugin."
   - Repair includes `npm uninstall -g @microsoft/wiqd` only after approval.
     Stop if uninstall fails; do not assume reinstall repairs a corrupt tree.
   - Do not run workflow commands with the broken CLI. After approval, execute the
     [conversational bootstrap](install-update.md#conversational-bootstrap) for the current OS,
     then continue with step 5.

4. **Not installed** (command not found / not on PATH) → wiqd is not installed.
   - Tell the user: "ℹ wiqd CLI is not installed. Install only the CLI prerequisite without replacing the marketplace plugin."
   - After approval, execute the [conversational bootstrap](install-update.md#conversational-bootstrap)
     for the current OS, then continue with step 5. Do not jump directly to file-based fallback.



5. **Verify recovery** — inspect the installer exit code and diagnostics. On a nonzero result,
   report the exact blocker and use step 6; do not loop or silently switch installer targets.
   - Run `wiqd --version` again in the command environment used for subsequent calls.
     If PATH is stale, inspect the installer-reported location or `npm prefix -g`, locate the
     verified installed shim (Windows: the prefix directory; macOS/Linux: its `bin` directory),
     and invoke it explicitly. Carry that resolution into subsequent shell calls; do not
     assume a child installer's PATH changes persist in the caller.
   - A version string alone is not completed recovery. Require the bootstrap's
     verified current host EULA state and successful edition-specific setup.
   - Only after exit 0 and a version string plus those checks, resume the original workflow and execute the
     requested operation. Do not stop after installation or ask the user to repeat the request.
     Existing authentication and downstream EULA consent gates still apply.
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
