---
title: Installation
---

# Installation

Install the `wiqd` CLI and all dependencies with a single command.

## One-Liner Install (Recommended)

The fastest way to get started — installs Node.js (if needed), the `wiqd` CLI, and the VS Code extension:

### macOS / Linux

```bash
curl -fsSL https://aka.ms/wiqd/install.sh | bash
```

:::tip
For a review-before-run approach:
```bash
curl -fsSL https://aka.ms/wiqd/install.sh -o install-wiqd.sh
cat install-wiqd.sh      # review the script
bash install-wiqd.sh     # run it
```
:::

### Windows (PowerShell)

:::note[PowerShell 7+ required]
Work IQ Dev Tools require **PowerShell 7 or later**. Run the installer from `pwsh` — not the built-in Windows PowerShell 5.1 (`powershell.exe`), which the installer refuses up front. If you don't have PowerShell 7 yet:

```powershell
winget install Microsoft.PowerShell
```

Then open a new `pwsh` session and run the one-liner below.
:::

```powershell
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
```

:::tip
For a review-before-run approach:
```powershell
irm "https://aka.ms/wiqd/install.ps1" -OutFile install-wiqd.ps1
Get-Content install-wiqd.ps1   # review the script
.\install-wiqd.ps1             # run it
```
:::

The installer will:

1. **Detect Node.js** — if missing or below the minimum version:
   - **Windows:** installs [fnm](https://github.com/Schniz/fnm) (Fast Node Manager) via `winget install Schniz.fnm` if fnm is not already present, activates it in the current PowerShell session, then installs Node LTS through `fnm i --lts`. No new terminal required — `node` and `npm` are available immediately.
   - **macOS/Linux:** installs via nvm, Homebrew, or apt.
   - Existing supported Node.js installations are preserved.
2. **Install `wiqd`** — downloads and installs the wiqd CLI (includes ATK as a dependency)
3. **Verify** — confirms `wiqd --version` works and dependencies are present
4. **VS Code extension** — installs the Work IQ extension for real-time validation
5. **Copilot CLI plugin** — deploys the wiqd plugin for GitHub Copilot CLI (skip with `-SkipPlugin` / `--skip-plugin`)

## Pass parameters to the bootstrap installer

The script-block-wrapped form `iex "& { $(irm 'URL') } -Flag"` is what makes it possible to append parameters that actually bind to the installer's `param()` block.

:::caution
**Don't use `iex (irm 'URL') -Flag`.** That bare form silently drops every appended parameter — `-Flag` falls onto the outer scope's `$args` and never reaches the installer. Always wrap with `iex "& { $(irm 'URL') } ... "` when you need to pass any flag.
:::

### Supported flags

| PowerShell flag | Bash equivalent | Description |
|-----------------|-----------------|-------------|
| `-SkipVSCode` | `--skip-vscode` | Skip the VS Code extension install step |
| `-SkipPlugin` | `--skip-plugin` | Skip the Copilot CLI plugin install step |
| `-Insiders` | `--insiders` | Install the extension in VS Code Insiders |
| `-Force` | `--force` | Reinstall even if components are already present |
| `-NodeVersion 24` | `--node-version 24` | Specify the Node.js major version (default: `24`) |
| `-Version <version>` | `--version <version>` | Specific wiqd version to install. With no override, the installer pins the exact version stamped into it at release time — never a floating `latest`/`preview` tag. Accepts a concrete version or an npm dist-tag such as `preview` or `latest`. |

### Examples

**PowerShell (Windows):**

```powershell
# Install without VS Code extension
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipVSCode"

# Install without Copilot CLI plugin
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipPlugin"

# Install for VS Code Insiders
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -Insiders"

# Force reinstall AND skip VS Code (combine flags)
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -Force -SkipVSCode"

# Pin to a specific version
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -Version '0.1.9'"
```

**Bash (macOS/Linux)** — uses `bash -s --` to pass parameters to the script via stdin:

```bash
# Install without VS Code extension
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --skip-vscode

# Install without Copilot CLI plugin
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --skip-plugin

# Install for VS Code Insiders
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --insiders

# Force reinstall AND skip VS Code (combine flags)
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --force --skip-vscode

# Pin to a specific version
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --version 0.1.9
```

## npm

`wiqd` is published to public npm as [`@microsoft/wiqd`](https://www.npmjs.com/package/@microsoft/wiqd). The one-liner installers above are still the recommended path (they also handle Node.js, the VS Code extension, and the Copilot CLI plugin), but a manual install works too:

```bash
npm install -g @microsoft/wiqd
```

## Verify Installation

```bash
wiqd --version
wiqd doctor
```

The `doctor` command verifies all CLI tools (wiqd, ATK, workiq, eval) are present and functional.

## Update

Re-run the installer with the `--force` flag to update to the latest version:

```bash
# macOS/Linux
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --force

# Windows (PowerShell)
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -Force"
```

## System Requirements

| Requirement | Minimum | Notes |
|-------------|---------|-------|
| Node.js | 24.15+ | Auto-installed by one-liner installer (via fnm on Windows) |
| npm | (bundled with Node.js) | Included with Node.js 24+ |
| OS | Windows 10+, macOS, Linux | All platforms supported via installer scripts |
| Internet | Required | For package downloads |

## Troubleshooting

### wiqd can't find Node.js

If `wiqd` fails with:

```
✗ wiqd: Node.js 24.15+ is required but no node executable was found.
  Already installed? Add it to PATH, or set WIQD_NODE to its full path.
  Not installed? Get it from https://nodejs.org, then re-run wiqd.
```

then the launcher wiqd installed could not locate a Node executable. This applies to the launchers wiqd writes: the Windows global `wiqd.ps1` and the per-worktree `.bin/` launchers. This is common with version managers such as fnm and nvm, whose shell hook only puts Node on `PATH` once your shell profile has run — a terminal opened before that hook was in place has Node on disk but not on `PATH`.

Two install paths use npm's own launcher instead, which resolves `node` from `PATH` only. On both, `WIQD_NODE` has no effect and the fix is to put Node back on `PATH`:

- **A global install on macOS or Linux.**
- **Windows, after the one-liner installer, or after `wiqd update`.** Those paths remove wiqd's own `wiqd.ps1` so a `Restricted` or `AllSigned` execution policy cannot hard-fail the command, so PowerShell resolves npm's `wiqd.cmd` instead. Installing directly with `npm install -g @microsoft/wiqd` leaves wiqd's own launcher in place, so `WIQD_NODE` does apply there. On the npm-launcher paths, the error you will see is cmd's own, not the message above:

  ```
  '"node"' is not recognized as an internal or external command,
  operable program or batch file.
  ```

wiqd's own launcher looks for Node in this order, and uses the first one that exists:

1. `WIQD_NODE`, if you set it to the full path of a `node` executable.
2. A `node.exe` sitting next to the launcher in the npm global directory (Windows).
3. `node` on your `PATH`.
4. The absolute path to the Node the launcher was written under — at install time for the global launcher, at `install.ps1 -Worktree` time for a worktree launcher. It is deliberately last, so switching versions with fnm or nvm still takes effect. A POSIX worktree launcher generated on Windows has no rung 4 at all, because a Windows Node path is meaningless under WSL or Git Bash.

The two fixes, in order of preference:

```powershell
# 1. Put Node back on PATH — usually just opening a new terminal after your
#    version manager's shell hook is installed.
node --version

# 2. Or point wiqd at a specific Node explicitly.
$env:WIQD_NODE = 'C:\Program Files\nodejs\node.exe'
wiqd --version
```

```bash
# 1. Put Node back on PATH
node --version

# 2. Or point wiqd at a specific Node explicitly
export WIQD_NODE=/usr/local/bin/node
wiqd --version
```

`WIQD_NODE` is an escape hatch, not a permanent fix — if you find yourself needing it every session, your Node version manager's shell hook is not being sourced. Run `wiqd doctor` for the manager-state report. If no Node is installed at all, install Node 24.15 or later from [nodejs.org](https://nodejs.org) and re-run the installer.

### I have multiple Node version managers installed

If you already have nvm-windows, nvm, volta, asdf, nodenv, Homebrew Node, system Node, or Chocolatey-installed Node on your machine, the installer detects every Node version manager on PATH before deciding what to do. The short version:

- **Existing Node ≥ 24.15.0:** the installer uses your existing Node and does NOT install fnm. Your shell profile is left untouched.
- **Existing Node too old:** the installer prompts (interactive) for upgrade-in-place vs switch-to-fnm. In CI / non-interactive contexts, it exits 1 with explicit guidance.
- **fnm + nvm both installed, nvm wins PATH:** the installer detects the conflict, refuses to claim success, and prompts for resolution. This is the bug the detection logic was designed to catch.

You can pin the strategy explicitly:

```powershell
# Use existing nvm-windows install, skip fnm install entirely
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -NodeManager nvm"

# Force fnm even when other managers are detected
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -NodeManager fnm"

# Corporate-policy escape hatch — never install fnm, use system Node only
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -NodeManager system"
```

```bash
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --node-manager nvm
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --node-manager fnm
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --node-manager system
```

`wiqd doctor` also reports the Node manager state on every run and warns when fnm is installed-but-inactive while wiqd's npm globals appear to live under fnm.

### Windows: an older `npm install -g @microsoft/wiqd` crashes on `copyBinaries.js`

**Affects:** `@microsoft/wiqd@0.3.0` and earlier (fixed in `0.3.1+`).

**Symptom:** the install exits non-zero with an error like:

```text
npm error path C:\<npm-prefix>\node_modules\@microsoft\wiqd\node_modules\@azure\msal-node-runtime
npm error command failed
npm error command C:\WINDOWS\system32\cmd.exe /d /s /c node ./copyBinaries.js
npm error Error: Cannot find module '...\@azure\msal-node-runtime\copyBinaries.js'
```

**Root cause:** older tarballs declared `bundledDependencies`. On Windows + npm 11, the reify pass for a tarball that carries that field silently abandons most of the transitive dependency tree mid-install and exits 0 — including the entire `@azure/msal-*` chain. npm then ran `@azure/msal-node-runtime`'s `install` lifecycle script (`node ./copyBinaries.js`) against an empty placeholder directory, which crashed with `MODULE_NOT_FOUND`.

**Fix:** upgrade to a current release, where `bundledDependencies` has been removed so the tarball reifies its full transitive tree on the first pass and a single `npm install -g` runs every postinstall script normally.

```powershell
npm uninstall -g @microsoft/wiqd
npm cache clean --force
# Either the official installer:
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
# …or a plain global install now works on its own:
npm install -g @microsoft/wiqd
```

**Verifying you have the fix:**

```powershell
$rt = Join-Path (npm config get prefix).Trim() "node_modules\@microsoft\wiqd\node_modules\@azure\msal-node-runtime"
Get-ChildItem $rt -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
# Healthy install: >= 24. Broken install: 0.
```

### Windows: a downloaded installer is blocked by execution policy

The recommended one-liner runs the installer **in memory** (`iex "& { $(irm ...) }"`), so PowerShell's execution policy and the "unknown publisher" Mark-of-the-Web never apply — it works under every policy, including `Restricted`. wiqd's install scripts are intentionally **not** Authenticode-signed because every path we publish is in-memory or produces an untagged local file.

You only hit a policy block if you deviate from the one-liner — e.g., you download `install-wiqd.ps1` through a browser (which tags it with the Mark-of-the-Web) and then run it from disk under `RemoteSigned`, or your machine enforces `AllSigned`. Two ways to proceed:

```powershell
# Preferred: just use the in-memory one-liner — no file on disk, no policy gate.
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"

# Or, if you deliberately saved the installer and want to review-then-run it:
irm 'https://aka.ms/wiqd/install.ps1' -OutFile install-wiqd.ps1   # no Mark-of-the-Web
Get-Content install-wiqd.ps1                                       # review
Unblock-File install-wiqd.ps1                                      # clear MOTW if a browser added it
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-wiqd.ps1
```

`irm -OutFile` does not add the Mark-of-the-Web, so a file saved that way runs unsigned under `RemoteSigned` without `Unblock-File`. The `Unblock-File` step is only needed for a copy a browser (or another MOTW-tagging app) downloaded.

## Next Steps

- [Quickstart](/getting-started/quickstart/) — Create your first agent in 5 minutes
- [Authentication](/getting-started/authentication/) — Sign in to your Microsoft 365 account
