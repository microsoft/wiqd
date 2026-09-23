# Install & Update

**Telemetry:** `--skill wiqd` on every ordinary telemetry-emitting `wiqd` command. The version probe remains telemetry-cold.

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

**Next steps after install:** read the active core workflow (`atk` or `wiqd-core`)
to create an agent or validate an existing project.
