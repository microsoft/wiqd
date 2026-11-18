# wiqd CLI Preflight Check

Run this check before ordinary `wiqd` commands to detect missing, broken or
outdated installations and resolve an allowed published target.
The version probe itself is allowed before compatibility is established.

## CLI compatibility

Resolve the containing skill directory from the loaded `skills/wiqd/SKILL.md`
location, not the user's working directory. The installed checker and a copy of
`cli-compatibility.json` are in that directory's `assets`. When the enclosing
plugin root has `plugin.json`, the checker reads that root's declaration and
requires the skill-local copy to match; in skill-only packages it validates the
local copy. It validates the closed schema and single minor release line, resolves
the newest published stable version from the declared npm package and supported
minor line, and probes the selected CLI launcher. Discovery uses the package source already configured
for that package; do not switch registries or package families.
Pass the checker path as one argument without interpolating it into shell code.
If Node, the checker or required declaration is unavailable, stop and report
the blocker; do not guess a range or search unrelated installations.

In the shell environment used for the workflow, resolve `wiqd` to an absolute
filesystem launcher before running the checker. On PowerShell, inspect
`Get-Command wiqd -ErrorAction SilentlyContinue`: an alias or function is
ambiguous and blocks rather than proving absence. For an npm `.ps1` shim, select
its adjacent `wiqd.cmd` only if it exists; otherwise report the blocker. On
macOS/Linux, inspect `type -t wiqd` and `command -v wiqd`; aliases, functions,
builtins and failed or ambiguous resolution block. Resolve a filesystem result
to an absolute path, including when a PATH entry is relative.

Pass the absolute launcher as a separate argument, preserving its exact path:

Run `node "<skill-directory>/assets/cli-compatibility.cjs" --package @microsoft/wiqd --latest --launcher "<launcher>"`.
If the shell confirms there is no `wiqd` command at all, replace
`--launcher "<launcher>"` with `--missing-launcher`. Do not use that option for
an alias, function, inaccessible launcher or other resolution error.
Replace both placeholders with their absolute paths as individual arguments;
do not interpolate paths into executable shell code. The checker emits one JSON result: `compatible` exits 0 when local
CLI equals the newest allowed version, `newer` exits 0 when local CLI is higher,
`update-required` or `install-required` exits 3, and invalid metadata, failed
registry discovery, invalid input or a failed CLI probe exits 2. Invalid
metadata blocks execution; do not repair it by installing a CLI. The stable
channel rejects prereleases and ignores build metadata for version precedence.
Never compare to the plugin's own version or a source `VERSION`.
For every subsequent ordinary CLI call, invoke the exact absolute `launcher`
returned by the checker, with shell-appropriate argument quoting. Do not rely
on a bare `wiqd`, an alias, or an environment variable surviving another tool
call. If that path becomes unavailable, stop and repeat the resolution and check.

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

The `--latest` result supplies the exact update target from the declared minor
line, irrespective of the package's `latest` tag. The declaration must contain
one `~X.Y.0` range, not multiple alternatives. Never
select a prerelease, unconstrained `latest`, or a version outside that line.
Use that exact target for the target-specific installer; do not resolve it again
with a floating tag. Do not compare ranges or versions yourself.

For an `update-required`, `install-required` or approved broken-CLI repair,
read `install-update.md`, show the exact target-specific command and resolved
version from its conversational bootstrap, and ask for explicit approval using
`ask_user` before executing it. Explain that this installs, updates or repairs
only the CLI prerequisite while preserving the marketplace plugin and VS Code
extension; repair also uninstalls the listed CLI packages.
Do not uninstall, install, or repair before approval, unless an existing explicit request
authorizes that exact operation and scope. A request to query or build an agent is not
installation consent. A human-attended conversation with a non-TTY command subprocess
can obtain approval; lack of a terminal alone is not lack of a human.
In an unattended context, do not install; show the command and
report the prerequisite blocker. If approval is declined or cancelled, do not mutate the
environment or repeat the prompt; use step 6.

## Procedure

1. Resolve the launcher and run the checker above in the command environment
   used for subsequent calls. It queries the declared package's published minor
   line and runs the selected launcher with `--version --no-banner`. It reports
   registry failures and the probe's nonzero exit/stderr explicitly. Only a
   confirmed absent command takes the missing-CLI path. If the shell cannot
   execute commands at all, use step 6.

2. **Success** requires `compatible` and exit 0. A `newer` result also permits
   the workflow to continue, including for a prerelease with greater SemVer
   precedence: warn that the local CLI exceeds the selected target, without
   claiming it is supported, and do not downgrade it. For `update-required` or
   `install-required`, report the observed version (if any) and exact selected
   target, then ask for explicit approval before installation or update. Declining
   or unattended execution blocks ordinary CLI commands without mutation.
   For an approved `update-required`, execute the
   [conversational bootstrap](install-update.md#conversational-bootstrap)
   at the exact selected version, then continue with step 5.
   Registry failures, malformed/ambiguous version output, invalid metadata and
   other probe failures are blockers, not compatibility. After an authorized
   change, repeat the check against the actual command resolution. A successful
   version result does not waive auth, EULA or other command preflights.

   For an existing local project, do not recreate or copy a replacement project
   as a preflight step. Continue with the requested project-scoped `wiqd plugin`
   command. WIQD recognizes contained `m365agents.yml` and
   `appPackage/manifest.json` read-only, derives name/capabilities from the root
   manifest, and validates only the command-required component closure.
   Missing/unsafe structure fails with exit 2; malformed manifest/name/reference
   data fails with exit 1 without changing user data.


3. **Broken install** (the checker reports `probe-failed` and stderr contains `Cannot find module`, `ERR_MODULE_NOT_FOUND`, or `MODULE_NOT_FOUND`) → wiqd is on PATH but its npm package tree is corrupt or incomplete.
   - Tell the user: "✗ wiqd is installed but appears broken. Repair only the CLI prerequisite without replacing the marketplace plugin."
   - Repair includes `npm uninstall -g @microsoft/wiqd` only after approval.
     Stop if uninstall fails; do not assume reinstall repairs a corrupt tree.
   - Do not run workflow commands with the broken CLI. After approval, execute the
     [conversational bootstrap](install-update.md#conversational-bootstrap) for the current OS,
     then continue with step 5.

4. **Not installed** (`install-required`, including command not found / not on PATH) → wiqd is not installed.
   - Tell the user: "ℹ wiqd CLI is not installed. Install only the CLI prerequisite without replacing the marketplace plugin."
   - After approval, execute the [conversational bootstrap](install-update.md#conversational-bootstrap)
     for the current OS, then continue with step 5. Do not jump directly to file-based fallback.



5. **Verify recovery** — inspect the installer exit code and diagnostics. On a nonzero result,
   report the exact blocker and use step 6; do not loop or silently switch installer targets.
   - Resolve the launcher again and run the checker with that absolute path.
     If PATH is stale, inspect the installer-reported location or `npm prefix -g`,
     locate the verified installed shim (Windows: the prefix directory;
     macOS/Linux: its `bin` directory), and pass that path to the checker.
     Invoke the returned path directly for subsequent calls; do not assume a
     child installer's PATH changes persist in the caller.
   - A version string alone is not completed recovery. Require the bootstrap's
     verified current host EULA state and successful edition-specific setup.
   - Only after the checker reports `compatible` or `newer` plus those checks,
     resume the original workflow and execute the
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
