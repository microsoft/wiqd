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


```bash
wiqd update --skip-plugin --skip-extension --skill wiqd
```



## Verify installation

```bash
wiqd --version
```

**Next steps after install:** read the core lifecycle workflow (`wiqd-core`)
to create an agent or validate an existing project.
