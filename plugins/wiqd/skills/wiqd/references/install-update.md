# Install & Update

**Telemetry:** `--skill wiqd` on every ordinary telemetry-emitting `wiqd` command. The version probe remains telemetry-cold.

## Explicit VS Code Extension Install

When the user explicitly asks to install the wiqd VS Code extension, run:

```bash
wiqd component vscode install --skill wiqd
```

CLI availability does not establish that the VS Code extension is installed.
Do not stop after `wiqd --version` or substitute manual Extensions-view advice
for the requested installation. The component command handles an already-installed
extension idempotently; report its result and do not claim success on failure.
Use `--insiders` only when the user requests VS Code Insiders. If the CLI is
missing, install the CLI prerequisite below first, then run the component command.
The CLI-only preservation rules below apply to prerequisite installation and
updates, not to an explicit request to install the VS Code extension.

## Install wiqd CLI

Install only the CLI prerequisite. Keep the marketplace-installed plugin and VS Code extension unchanged.

For a missing or broken CLI discovered during another task, follow
[Recovery approval](preflight.md#recovery-approval) before installation or repair.
After approval in a human-attended non-TTY session, execute the conversational
bootstrap below rather than starting a web installer whose EULA prompt needs a terminal.
Direct terminal installations can use the platform installers below.
Follow [Verify recovery](preflight.md#procedure) to check the result and resume the original user request.
Installation consent does not authorize authentication or EULA acceptance.

### Conversational bootstrap

Use this sequence when a human can answer in chat but the command subprocess has
no TTY. An unattended session cannot grant installation permission or EULA consent.
Do not ask the user to open another terminal merely because stdin is redirected.

1. **Resolve and approve acquisition.** Verify caller-provided Node.js 24.15.0+
   and npm are executable; do not install/upgrade them or change persistent PATH/configuration.
   Resolve one exact published host version from the approved package source and
   applicable plugin compatibility policy. For a stable channel, read
   `npm view @microsoft/wiqd@latest version` and validate its exact release identity;
   never install a floating tag, assume a main-branch change is published, or
   infer the CLI version from the plugin version. Apply any published compatibility
   constraints; do not require new synchronization metadata when none is specified.
   Unreadable/invalid metadata or no compatible published candidate blocks recovery.
   Show the exact acquisition and final setup commands, selected version and
   any authorized uninstall to the human, then obtain installation/repair permission
   through preflight. This does not accept terms.

2. **Acquire the public host only.** From an owned temporary working directory
   outside the user's repository, run
   `npm install -g "@microsoft/wiqd@<resolved-exact-version>" --loglevel=error`
   (`npm.cmd` on Windows), with scripts enabled and ambient npm user/global
   configuration. Restore the caller directory and clean only owned temporary
   resources on success/failure. Check the native exit code, not stderr text.
   Do not add registry overrides, use `--ignore-scripts`, elevate, or automatically
   retry/change source. On failure report the real diagnostics and stop.
   This is acquisition, not completed setup or acceptance.
   Resolve `npm prefix -g`, then the absolute `wiqd.cmd` in that prefix on Windows,
   or `bin/wiqd` on macOS/Linux. Invoke that launcher with `--version --no-banner`
   and require the exact selected version. Reuse it for all subsequent commands;
   do not rely on a child shell changing PATH for later tool calls.

3. **Observe before accepting.** Use the verified launcher for
   `wiqd eula status --json --skill wiqd`. Validate command `eula-status`.
   A success envelope has no `exitCode` field: require process exit 0 and
   `status: "success"`. Only an error envelope must have an `exitCode` matching
   the process exit. Read `data.wiqd` only for exit-0 success.
   For exit 2, only error code `EULA_STATUS_BINARY_UNRESOLVED` with an
   `error.data.tools` row whose state is `binary-unresolved` permits reading
   `error.data.wiqd` independently; the aggregate status still failed.
   Other errors, malformed output or an unavailable host row block recovery.
   Require host `tool` and `id` equal to `wiqd`, `cliVersion` equal to the selected
   release, and a current descriptor `version` and `eulaUrl`. If the host state is
   already `accepted`, do not request or repeat acceptance. Otherwise require
   state `unaccepted` and continue with the next step.

4. **Ask for a simple host-terms choice.** Surface the CLI's pre-release
   notice, exact EULA URL and current content version from that candidate.
   The notice must explain that WIQD is experimental software for experimentation
   only, is not production-ready or officially supported, and may introduce
   breaking changes. On every platform, use a natural-language confirmation title
   such as "Accept the WIQD terms and continue?", not a technical label such as
   "WIQD host EULA v2". In the question body, link the current agreement, identify
   its content version, and explain that agreement records acceptance and resumes
   the original task. Keep exit codes, shell/test paths and command-line flags out
   of the main question.
   Use `ask_user` with a single-choice "Agree and continue" / "Decline" question
   in the user's language. Do not preselect agreement, use a free-text declaration
   field, or require the user to type a statement, version or URL. Separately
   disclose before the choice that agreement accepts these WIQD terms and authorizes
   `wiqd eula accept wiqd --yes --json --skill wiqd`. A clear affirmative answer
   to this specific question is sufficient; installation permission, silence,
   echoed instructions, unrelated approval and ambiguous answers are not consent.
   Decline/cancellation stops acceptance and the pending workflow without repeated
   prompting. Mock and unattended conversations cannot grant this confirmation;
   CI detection alone never supplies consent.
   After approval, recheck the selected absolute launcher/release and host
   descriptor against the identity, content version and URL shown to the human.
   Changed terms require a new confirmation before acceptance. Then invoke only
   the host command above; do not generate a `--consent` phrase or use hidden
   `--installer-stamp`, config edits, piped responses or TTY automation.
   Require exit 0 and a JSON success envelope for `eula-accept` whose `data`
   identifies `tool: "wiqd"`, state `accepted`, the displayed `id`, `version`,
   `eulaUrl`, and stored `method`/`acceptedAt`. Repeat the status check above and
   require the same current descriptor to be `accepted`. Store failure stops
   recovery; never retry acceptance blindly or treat exit 3 as acceptance.
   This host-only explicit opt-in does not replace the downstream `--consent`
   flow and never authorizes other tools' agreements.

5. **Complete same-candidate setup, then resume.** Run the target-specific platform
   installer below only AFTER verified host acceptance. Add `-Version <resolved-exact-version>`
   on Windows or `--version <resolved-exact-version>` on macOS/Linux, retaining both
   component-skip flags and the edition switch where applicable.
   Its prior-acceptance probe calls `wiqd` by name, so an absolute launcher used
   earlier is not sufficient. Bind that name to the verified launcher for this
   setup invocation only, using the wrappers below; do not invoke its terminal
   prompt from a non-TTY shell. A missing PowerShell 7 host blocks
   Windows web-installer setup; check it before acquisition/repair.
   Do not report npm-only acquisition as full installation or private setup.
   Require installer exit 0, reverify the selected absolute launcher/version and host
   acceptance, then resume the original user request without asking it to be repeated.
   Preserve the marketplace plugin and VS Code; downstream EULAs, sign-in and tenant
   authorization remain independent. Report any completed acquisition on later failure,
   without claiming rollback or successful recovery.

#### Setup-only launcher binding

On Windows, in the verified PowerShell 7+ host, set `$launcher` to the verified
absolute `wiqd.cmd` and `$setup` to a script block containing the target-specific
wrapped installer command with the exact version and component skips. Execute
both alias creation and setup in the same child scope:

```powershell
& {
  Set-Alias -Name wiqd -Value $launcher -Scope Local -ErrorAction Stop
  & $setup
}
```

The local alias bypasses both an older PATH entry and npm's `.ps1` shim without
changing execution policy or any launcher file. It disappears when the block
returns, including on failure; do not create a global alias or edit a profile.

On macOS/Linux, stage the target-specific installer first (preserving the private
installer's SHA-256 display below). Set `launcher` to the verified absolute
`bin/wiqd`, `launcher_dir` to its absolute directory, and `setup` to a Bash array
containing `bash`, the saved installer path,
the exact version and target-specific skip/edition arguments. Run:

```bash
(
  export PATH="$launcher_dir:$PATH"
  "${setup[@]}"
)
```

Only the setup subshell inherits this PATH. Do not change the caller's PATH,
copy shims, remove shadowing installations, or treat a failed probe as consent.

### Windows prerequisite: PowerShell 7+

The Windows installer requires **PowerShell 7 or later** (`pwsh.exe`), not
Windows PowerShell 5.1 (`powershell.exe`). Before installing, repairing, or
rerunning the installer for an update:

1. Check the executing host with `$PSVersionTable.PSVersion`. If it is already
   7+, use that host.
2. Otherwise, locate an existing `pwsh.exe` with `Get-Command pwsh -ErrorAction SilentlyContinue`.
   If it is not on PATH, check installed locations such as
   `C:\Program Files\PowerShell\7\pwsh.exe` before concluding it is missing.
   Verify the discovered executable with
   `& '<resolved path to pwsh.exe>' -NoProfile -Command '$PSVersionTable.PSVersion'`.
3. Run the Windows installer command below inside the verified PowerShell 7+
   host, not the original 5.1 session. Do not install or upgrade PowerShell
   when a usable 7+ host already exists.
4. If no usable PowerShell 7+ host is found, report the missing prerequisite
   and determine an appropriate setup path with the user before continuing.
   Do not run the CLI installer under 5.1 or treat CLI installation/update
   as authorization to upgrade PowerShell.

This prerequisite applies to Windows installer execution, not to an otherwise
working `wiqd --version` probe or ordinary CLI commands.


### Windows

```powershell
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipPlugin -SkipVSCode"
```

### macOS/Linux

```bash
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --skip-plugin --skip-vscode
```



⚠️ NEVER use `scripts/install.ps1` or local build scripts — those are developer-only.

## Update wiqd CLI

Keep marketplace-managed components unchanged during updates.
For Windows updates that rerun the installer, follow the
[PowerShell 7+ prerequisite](#windows-prerequisite-powershell-7) first.


```bash
wiqd update --skip-plugin --skip-extension --skill wiqd
```



## Verify installation

```bash
wiqd --version
```

**Next steps after install:** resume the original user request in its matched workflow;
do not redirect a Work IQ query or another pending task into agent creation.
For a standalone installation request with no pending workflow, report the verified CLI version.
