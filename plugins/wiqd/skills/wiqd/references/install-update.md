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

**Next steps after install:** read the core lifecycle workflow (`wiqd-core`)
to create an agent or validate an existing project.
