---
title: Installation
---

# Installation

WIQD is the agentic experience for building Microsoft 365 Copilot plugins end
to end. The **WIQD coding-assistant plugin** installed below supplies guided
workflows; the **Microsoft 365 plugin you create** is a separate app package
that composes skills, connectors, and optional declarative agents. See
[Quickstart](/getting-started/quickstart/) to build your first one.

WIQD supports two alternative installation paths:

| Path                     | Start here when                                                              | Installs                                                                                 |
| ------------------------ | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Plugin-first agentic** | You want to begin in GitHub Copilot CLI or Claude Code                       | The public WIQD plugin from Awesome Copilot or [`microsoft/wiqd`](https://github.com/microsoft/wiqd) |
| **Installation script**  | You want direct `wiqd` shell commands and VS Code validation | The WIQD CLI, optional VS Code extension, and public plugin for detected native hosts |

## Path 1: Install from the marketplace

Install a supported agent host first:

- [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)
- Claude Code

Then add the public marketplace and install WIQD for your chosen host.

### GitHub Copilot CLI

Install WIQD from the built-in Awesome Copilot marketplace:

```text
copilot plugin install wiqd@awesome-copilot
```

Alternatively, add the WIQD marketplace and install the same public plugin:

```text
copilot plugin marketplace add microsoft/wiqd
copilot plugin install wiqd@wiqd
```

### Claude Code

```text
claude plugin marketplace add microsoft/wiqd
claude plugin install wiqd@wiqd
```

Start a new host session after installation. Marketplace installation does not
install the `wiqd` CLI, and you do not need the CLI to begin agentic or
file-based authoring. If you later need direct lifecycle commands, use the
separate [installation-script path](#path-2-use-the-installation-script).

When a skill workflow needs the CLI and cannot find it, WIQD asks for approval to
install the CLI prerequisite (or repair a broken installation). This CLI-only
recovery leaves your marketplace plugin and VS Code extension unchanged. After
installation, the skill verifies the CLI and resumes your original request in the
same session. Authentication and EULA acceptance remain separate consent steps.
If you decline or installation is blocked, local file-based work may continue,
but online operations such as Work IQ feedback queries remain blocked.

### Migrating from a CLI-composed plugin

The WIQD CLI no longer exposes host-plugin management commands. The installer
can migrate a proven WIQD-owned local marketplace to the public source, but
stops on unverified local ownership or a conflicting requested marketplace
binding. Other remote registrations stay untouched and do not block installation.
It never deletes your plugin source directories. Extension activation does not
change host plugins.

Copilot may report that uninstall disabled a local live plugin without removing
its files. The installer handles that specific WIQD state by unregistering the
owned local marketplace without force, then installing the public plugin. Other
plugins that reference the marketplace still block migration, even if disabled.

Use an up-to-date host so the installer can verify the installed plugin's source.
If it cannot verify an existing `wiqd@wiqd` installation, it stops plugin changes
and asks you to resolve the installation rather than replacing it blindly.

Before switching an existing installation, inspect your chosen host's native
plugin and marketplace inventory to identify the actual source. An old local
deployment may share the WIQD plugin name with a public marketplace plugin; the
name alone does not prove the source is correct. Use the host's native uninstall
flow for that old deployment, remove or rebind its old local marketplace entry,
then follow the marketplace commands above. Start a new host session. Do not
delete configuration directories or run a blanket cleanup.

The `wiqd component plugin` subtree, `wiqd install plugin`,
`wiqd uninstall plugin`, and `wiqd install --status` have been removed.
Bare `wiqd install` no longer installs a plugin. VS Code remains managed with
`wiqd component vscode install|uninstall|info`; `wiqd plugin create` and other
Microsoft 365 business-plugin commands are unchanged.

## Path 2: Use the installation script

Install a supported Node.js/npm environment first, then use the script to install
the `wiqd` CLI and retained integrations:

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

1. **Verify Node.js/npm** — requires launchable Node.js 24.15+ and npm from the
   caller's current `PATH`. The installer never provisions a runtime, selects a
   version manager, elevates, or changes shell profiles.
2. **Install `wiqd`** — installs the exact compatible npm package set from the
   configured npm registry, or an explicitly supplied compatible tarball
3. **Verify** — confirms `wiqd --version` works, then `wiqd doctor` reconciles managed
   extension owners and reports targeted remediation when needed
4. **VS Code extension** — installs the Work IQ extension for real-time validation

5. **Host plugins** — installs or updates the public plugin for detected native
  Copilot and Claude hosts. It does not install either host. Use `-SkipPlugin`
  (PowerShell) or `--skip-plugin` (Bash) to skip this step.

Conflicting plugin sources require manual resolution; forcing a CLI reinstall
does not bypass plugin ownership checks. A plugin failure leaves the verified
CLI installed and reports a setup warning with recovery guidance.

Successful bootstrap installs record their hosted installer in
`~/.wiqd/install-method.json`. `wiqd update` reuses that installer to upgrade,
downgrade, or repair the CLI and its extension packages. Plugin updates follow
the installer's defaults; `wiqd update --skip-plugin` skips that work without
disabling installed plugins. If your install
predates this marker, rerun your intended bootstrap once with `-SkipPlugin`
(PowerShell) or `--skip-plugin` (Bash). Missing provenance uses the public
installer; invalid provenance requires rerunning the intended bootstrap rather
than silently switching sources.

## After installation

After installation, start with a standalone plugin. These documentation examples
explicitly select `dev`; the installer's printed Quick Start still selects `local`,
and actual CLI defaults are unchanged.

```text
wiqd plugin create --name my-plugin
cd my-plugin
wiqd plugin validate --mode source --env dev
wiqd plugin provision --env dev
```

Source checks are offline and cover the saved declarative-agent component when
present, not the entire plugin. Bare `wiqd plugin validate` instead defaults to
package mode and uploads an existing ZIP. After packaging, pass its returned path
with `wiqd plugin validate --mode package --package-file "<zip>"`.

Sign in with `wiqd auth login --interactive` before provisioning. The `dev`
environment is provisioned to your Microsoft 365 tenant; it is not an offline
deployment.

If host-plugin installation succeeded, start a new host session; no reinstall is
needed. If skipped or no host was detected, install the marketplace plugin
manually. For a fresh Copilot installation, the installer uses
`wiqd@awesome-copilot`. Copilot resolves its built-in Awesome Copilot marketplace;
the installer does not inspect, add, or rebind it. If native inventory verifies one enabled,
installed `wiqd@wiqd` deployment from `microsoft/wiqd`, bootstrap and
`wiqd update` update that identity in place without adding the Awesome Copilot
copy. An uncertain, disabled, duplicate, or non-installed canonical deployment
stops public plugin work before changes; inspect the host's plugin and
marketplace settings with `copilot plugin list --json` and
`copilot plugin marketplace list --json`, resolve the state yourself, and retry.
Use `-SkipPlugin` (PowerShell) or `--skip-plugin` (Bash) for CLI-only installation.
The installer does not switch, enable, or remove public deployments for you.

Claude continues to use `wiqd@wiqd` from `microsoft/wiqd`. WIQD does not manually
remove or rewrite remote plugins or marketplaces. Unverified Claude bindings
are handed to Claude's native marketplace-add command with a warning; if it
fails, plugin installation stops. Plugin detection uses the host's native
inventory, not a fixed manifest-file layout. If a host is unavailable but a
WIQD cache directory remains, restore that host and inspect its plugin inventory
before retrying the installer. If installation failed, follow the reported
remediation and retry. Success confirms the native install command completed,
not that individual skills were tested.
See [Build a Plugin](/getting-started/build-a-plugin/) for the complete workflow.

## Pass parameters to the bootstrap installer

The script-block-wrapped form `iex "& { $(irm 'URL') } -Flag"` is what makes it possible to append parameters that actually bind to the installer's `param()` block.

:::caution
**Don't use `iex (irm 'URL') -Flag`.** That bare form silently drops every appended parameter — `-Flag` falls onto the outer scope's `$args` and never reaches the installer. Always wrap with `iex "& { $(irm 'URL') } ... "` when you need to pass any flag.
:::

### Supported flags

| PowerShell flag | Bash equivalent | Description |
|-----------------|-----------------|-------------|
| `-SkipVSCode` | `--skip-vscode` | Skip the VS Code extension install step |
| `-SkipPlugin` | `--skip-plugin` | Skip all host-plugin installation, update, and migration work |
| `-Insiders` | `--insiders` | Install the extension in VS Code Insiders |
| `-Force` | `--force` | Reinstall even if components are already present |
| `-Tarball <path>` | `--tarball <path>` | Install one explicit compatible `@microsoft/wiqd` `.tgz`; all verification and integrations still run |
| `-Version <version>` | `--version <version>` | Specific wiqd version to install. With no override, the installer pins the exact version stamped into it at release time — never a floating `latest`/`preview` tag. Accepts a concrete version or an npm dist-tag such as `preview` or `latest`. |
| `-Channel <channel>` | `--channel <channel>` | Select `latest`, `preview`, or `dev`. The `dev` channel uses npm's `alpha` tag; `alpha` is accepted as a compatibility alias. Cannot be combined with the version flag. With no override, the stamped installer default is unchanged. |

### Daily development builds

The `dev` channel installs experimental snapshots of validated `main`, published
daily under the npm `alpha` tag. The name `dev` is a WIQD alias, not another
npm dist-tag.
For example, stable `0.19.0` is followed by
`0.20.0-alpha.20261022.123456`; the corresponding stable `0.20.0` sorts after
that alpha. Installing alpha never changes what other users receive from
`latest`.

```powershell
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -Channel dev"
```

```bash
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --channel dev
```

Alternatively, use `npm install -g @microsoft/wiqd@alpha`, or update an existing
installation with `wiqd update --channel dev`. Check availability with
`wiqd update --channel dev --check --json`.

The installer maps `dev` to npm `alpha` and resolves it to one exact version.
The older `--channel alpha` / `-Channel alpha` spelling continues to work.
If the tag cannot be
resolved, it stops with an error rather than silently installing stable.
No-argument updates still select `latest`; select `dev` explicitly each time.
To return to stable, run `wiqd update --channel latest`, or pin a specific
stable version with `wiqd update --version <version>`.

If the CLI installs successfully but a plugin or VS Code extension cannot be set
up, the installer shows a warning and continues the remaining optional setup.
This includes a missing bundled VS Code extension file or a failed extension
installation. You can keep using `wiqd`; follow the displayed
guidance and rerun the installer to retry the optional setup. Use `-SkipPlugin`
or `-SkipVSCode` (Bash: `--skip-plugin` or `--skip-vscode`) if you do not need
those integrations.

For plugin file-lock or access-denied errors, the installer provides this guidance:

> Plugin files may be locked or inaccessible. Close other running Copilot or Claude sessions, then retry from a regular terminal. If the error persists, check write access to the path reported above.

A failed native operation does not establish whether the plugin is still
installed or was removed; inspect the host's plugin settings if needed, then
rerun the installer.

### Examples

**PowerShell (Windows):**

```powershell
# Install without VS Code extension
iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') } -SkipVSCode"

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

# Install for VS Code Insiders
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --insiders

# Force reinstall AND skip VS Code (combine flags)
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --force --skip-vscode

# Pin to a specific version
curl -fsSL https://aka.ms/wiqd/install.sh | bash -s -- --version 0.1.9
```

## npm

`wiqd` is published to public npm as [`@microsoft/wiqd`](https://www.npmjs.com/package/@microsoft/wiqd). The one-liner installers above are still the recommended path because they also verify readiness and reconcile optional integrations, but they require Node/npm to be installed first. A manual install works too:

```bash
npm install -g @microsoft/wiqd
```

If the installer reports `E404`, either the requested `wiqd` version or one of its dependencies is unavailable from the registry identified by the installer. Follow the attributed message: for public npm, use the printed recovery command after the package is published; for a configured registry, fix or update that registry and re-run the installer.

## Install from an assistant conversation

The WIQD marketplace plugin and CLI are separate installations. If the CLI is
missing, a human-attended assistant can complete setup in the conversation even
when its shell has no interactive terminal:

1. The assistant checks that supported Node.js/npm (and PowerShell 7 on Windows)
   already exist, selects an exact published compatible CLI version, shows the
   commands, and asks permission to install or repair it. It does not install
   Node/npm or treat your original product request as installation permission.
2. With your approval, it acquires `@microsoft/wiqd@<exact-version>` through npm
   from a temporary directory, resolves the absolute launcher in that npm global
   prefix, and verifies the selected CLI version. This is not EULA acceptance.
3. If current WIQD terms are not already accepted, it displays the pre-release
   notice, terms URL and current content version returned by that CLI, then asks
   you to choose **Agree and continue** or **Decline**, in your language, with no
   default agreement. You do not need to type a statement, version or URL.
   Only agreement to this specific question authorizes
   `wiqd eula accept wiqd --yes --json`; permission to install alone does not.
   The assistant rechecks the CLI and terms before executing; changed terms
   require a new confirmation. It does not construct a consent phrase for you.
4. It verifies current host acceptance, completes the same-version platform
   installer with `-SkipPlugin -SkipVSCode` (or `--skip-plugin --skip-vscode`),
   and verifies the recovered CLI before continuing your original request.
   The installer uses the same verified launcher even if it is missing from
   PATH or shadowed by an older installation. Any alias/PATH binding is limited
   to this setup invocation; your profile and persistent PATH stay unchanged.

Work IQ/Eval terms, authentication and tenant permissions remain separate.
Existing working installations need not be reinstalled merely to accept current
host terms. Failed acceptance or setup is reported as a blocker, not success.

You can decline or cancel either permission. The assistant stops the pending
operation and reports any installation already completed; it does not pretend
to roll back those changes. An unattended session without a responding human
cannot newly obtain this consent. Missing or ambiguous replies do not count as
agreement. The following CI path requires its own explicit job-owner
authorization; conversation approval does not grant unattended or downstream consent.

## Fresh CI runners: explicit WIQD terms acceptance

Provision Node.js 24.15.0+ and npm first. Select an exact approved WIQD version
that supports `--yes`; npm-only acquisition makes the CLI available before
acceptance. The job owner must review [WIQD's current terms](https://aka.ms/wiqd/eula)
and authorize this operation, including any terms changes when selecting a new
candidate. Installation, CI detection, or a blocked command never supplies consent.

**PowerShell 7:**

```powershell
$version = '<approved-exact-version>'
npm.cmd install -g "@microsoft/wiqd@$version" '--loglevel=error'
if ($LASTEXITCODE -ne 0) { throw 'WIQD installation failed' }
$prefix = npm.cmd prefix -g
if ($LASTEXITCODE -ne 0) { throw 'npm prefix resolution failed' }
$launcher = (Resolve-Path -LiteralPath (Join-Path "$prefix".Trim() 'wiqd.cmd') -ErrorAction Stop).Path
$installed = & $launcher --version --no-banner
if ($LASTEXITCODE -ne 0 -or "$installed".Trim() -ne $version) {
    throw 'Wrong or unavailable WIQD launcher; inspect PATH and npm prefix'
}
& $launcher eula accept wiqd --yes --json
if ($LASTEXITCODE -ne 0) { throw 'WIQD terms acceptance failed' }
$status = & $launcher eula status --json | ConvertFrom-Json
$code = $LASTEXITCODE
$report = if ($code -eq 0 -and $status.status -eq 'success') {
    $status.data
} elseif ($code -eq 2 -and $status.status -eq 'error' -and $status.exitCode -eq 2 -and
    $status.error.code -eq 'EULA_STATUS_BINARY_UNRESOLVED' -and
    @($status.error.data.tools | Where-Object state -eq 'binary-unresolved').Count -gt 0) {
    $status.error.data
} else { throw 'EULA status inspection failed' }
if ($report.wiqd.tool -ne 'wiqd' -or $report.wiqd.state -ne 'accepted' -or
    $report.wiqd.cliVersion -ne $version) {
    throw 'Current WIQD terms are not accepted'
}
```

**Bash:**

```bash
set -e
version='<approved-exact-version>'
npm install -g "@microsoft/wiqd@$version" --loglevel=error
prefix=$(npm prefix -g)
launcher="$prefix/bin/wiqd"
test -x "$launcher"
test "$("$launcher" --version --no-banner)" = "$version"
"$launcher" eula accept wiqd --yes --json
code=0
status=$("$launcher" eula status --json) || code=$?
printf '%s' "$status" | node -e '
let text=""; process.stdin.on("data", c => text += c);
process.stdin.on("end", () => {
  const j=JSON.parse(text), code=Number(process.argv[1]);
  const report=code===0 && j.status==="success" ? j.data :
    code===2 && j.status==="error" && j.exitCode===2 &&
    j.error.code==="EULA_STATUS_BINARY_UNRESOLVED" &&
    j.error.data.tools.some(t=>t.state==="binary-unresolved") ? j.error.data : null;
  process.exit(report?.wiqd.tool==="wiqd" && report.wiqd.state==="accepted" &&
    report.wiqd.cliVersion===process.argv[2] ? 0 : 1);
});' "$code" "$version"
```

Keep using that absolute launcher for your intended local product command:
`& $launcher plugin show --path <existing-plugin-project> --json` in PowerShell,
or `"$launcher" plugin show --path <existing-plugin-project> --json` in Bash, before any authorized
tenant operations. Acceptance releases only the host gate, not authentication,
project validation, or Work IQ/Eval agreements. A fresh npm install can return
status exit 2 because a downstream managed binary is not yet installed; only the
specific error report above permits independent host observation.

`--yes` accepts current WIQD terms without a prompt or consent phrase, in CI,
non-TTY or TTY. It stores the terms identity/version, URL, timestamp and
`explicit-yes` method as mutable local evidence, not authenticated identity or
proof of organizational authority. Repeats preserve prior evidence. Store failure
returns 1 / `EULA_STORE_WRITE_FAILED`; mock, downstream/unknown selectors and
combinations with consent/stamp refuse with 2. Without `--yes`, existing typed
confirmation/human relay and CI refusal remain.

If full installer setup is needed afterward, select that same exact candidate
with `-Version` / `--version` (or its verified tarball). The installer verifies
prior acceptance against the selected candidate. An older accepted CLI cannot
prove changed target terms. Fresh unattended web installation without prior
acceptance still refuses; do not run it as the first bootstrap step.
Installer `-Force` / `--force` means reinstall, not EULA consent. There is no
acceptance `--force` alias or supported installer acceptance switch.

## Verify Installation

```bash
wiqd --version
wiqd doctor
```

The `doctor` command checks the CLI and installed extensions, repairs managed
extension installations when needed, and reports remaining health or EULA warnings.
Optional extension warnings do not mean the CLI installation failed.

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
| Node.js | 24.15+ | Must already be launchable from the caller's `PATH` |
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

then a developer worktree launcher could not locate Node. Published global,
local, and npm-exec launchers are npm-owned and use the caller's working
Node/PATH environment; `WIQD_NODE` and an install-time recorded interpreter do
not apply to published-package launchers.

On Windows, the bootstrap removes only the selected npm prefix's `wiqd.ps1` so
restrictive execution policy selects npm's `wiqd.cmd`. If `wiqd` is blocked
after a direct npm install, try the `.cmd` launcher and repair PATH rather than
editing launcher bytes:

  ```
  '"node"' is not recognized as an internal or external command,
  operable program or batch file.
  ```

`node --version` in PowerShell may differ from the Node used by `wiqd.cmd`.
The npm launcher prefers `node.exe` beside itself; otherwise CMD searches the
current directory before PATH. Step 1 checks bootstrap Node/npm; Step 3 uses
the installed launcher's `wiqd doctor` to check WIQD's actual runtime.
If it reports unsupported Node, update the executable it names or correct its
lookup, then retry. `wiqd.cmd doctor --json` reports the actual Node version and
`executablePath`; incompatible extension packages are not necessarily missing.
If npm installation succeeded, fixing the selected Node normally lets you rerun
doctor without reinstalling WIQD. Switching a Node manager's global prefix may
instead require installing WIQD in that new prefix.
The installer does not change your Node manager, PATH, or npm launcher contents.

For published installs, fix the caller environment:

```powershell
# 1. Put Node back on PATH — usually just opening a new terminal after your
#    version manager's shell hook is installed.
node --version

wiqd.cmd --version
```

```bash
# 1. Put Node back on PATH
node --version

wiqd --version
```

Developer `scripts/install.ps1 -Local/-Worktree` launchers retain their separate
WIQD-owned fallback behavior. If no Node is installed at all, install Node 24.15
or later from [nodejs.org](https://nodejs.org) and re-run the installer.

The installer warns if this shell's normal `wiqd` command is missing or resolves
elsewhere, even when the selected npm launcher passed verification.
If a different prefix still wins after reinstall, compare `npm prefix -g` with
every resolved launcher (`Get-Command wiqd -All` on PowerShell or
`type -a wiqd` on Bash). Remove or reorder the stale prefix manually. Bootstrap
does not scan or delete launchers outside the selected npm prefix.

### Retired bootstrap options

`Source`/`source` (including `npm`), `Repo`/`repo`, bootstrap
`Local`/`local`, `NodeManager`/`node-manager`, and
`NodeVersion`/`node-version` are no longer accepted behaviors. Remove those
arguments from automation. Use the configured npm registry, or pass
`-Tarball`/`--tarball` for an explicit compatible candidate. Contributor
`scripts/install.ps1 -Local/-Worktree` remains supported and is not the web
bootstrap.

## Managed extension CLI state

Work IQ and Eval use extension-owned, exact npm pins rather than standalone global
packages. `wiqd doctor` eagerly reconciles each active owner into
`~/.wiqd/extensions/`. Its `--json` output keeps the standard `checks[]` shape.
Managed state intentionally survives `npm uninstall -g @microsoft/wiqd`; reinstalling
wiqd revalidates and reuses it.

Run `wiqd doctor` to repair an active managed generation. Doctor warns about a
separately rooted global copy but never removes it automatically. When the isolated
managed copy is healthy, the warning prints `npm uninstall -g <package>` as an
explicit optional cleanup command. Run it only after confirming no external workflow
or explicit override depends on that global package. `wiqd ext list` and `wiqd ext
show` inspect managed state; `wiqd ext remove` only deactivates an extension.

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

- [Quickstart](/getting-started/quickstart/) — Create, validate, and share your first plugin
- [Authentication](/getting-started/authentication/) — Sign in to your Microsoft 365 account
