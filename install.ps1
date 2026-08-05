# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#   ██╗    ██╗██╗ ██████╗ ██████╗
#   ██║    ██║██║██╔═══██╗██╔══██╗
#   ██║ █╗ ██║██║██║   ██║██║  ██║
#   ██║███╗██║██║██║▄▄ ██║██║  ██║
#   ╚███╔███╔╝██║╚██████╔╝██████╔╝
#    ╚══╝╚══╝ ╚═╝ ╚══▀▀═╝ ╚═════╝
#
# wiqd Installer
# Usage: iex "& { $(irm 'https://aka.ms/wiqd/install.ps1') }"
#
# Or for safer review-before-run:
#   irm "https://aka.ms/wiqd/install.ps1" -OutFile install.ps1
#   Get-Content install.ps1   # review
#   .\install.ps1             # run
#
# Installs the wiqd CLI and all dependencies:
#   1. Verify Node.js >= the minimum version (block + suggest if missing;
#      the installer never installs Node itself)
#   2. @microsoft/wiqd (npm global package — includes extension stubs;
#      ATK, eval, and workiq are transitive npm dependencies, resolved by
#      `npm install -g @microsoft/wiqd`)
#   3. Verify installation (smoke-test that `wiqd` and the transitive CLIs are
#      on PATH; no install work — that all happens in Step 2)
#   4. Work IQ VS Code extension (optional)
#   5. wiqd plugin — installed only for the plugin host(s) already on PATH
#      (Copilot CLI and/or Claude Code). Never installs a host; skipped
#      gracefully when neither is present. Skip entirely with -SkipPlugin.
#
#
# -Force         Full reinstall, end-to-end. Bypasses every "already installed"
#                short-circuit:
#                  * Step 2 (wiqd CLI): reinstall even when the version matches.
#                                       This also re-resolves the transitive
#                                       ATK / eval / workiq deps.
#                  * Step 4 (VS Code extension): re-run --install-extension --force
#                                                even if the extension is already
#                                                listed by `code --list-extensions`.
#
# Requires: Internet access.

# CmdletBinding makes PowerShell reject unknown/misspelled parameters (e.g. a
# typo'd -FirstParth) with a clear error instead of silently swallowing them
# into $args and running a partial install. This mirrors the bash installer,
# whose arg parser already exits on an unknown option.
[CmdletBinding()]
param(
    # The 3P installer ships from the public npm registry only.
    [ValidateSet("npm")]
    [string]$Source = "npm",
    [string]$Version = "latest",
    [string]$Repo = "microsoft/wiqd",
    [switch]$SkipVSCode,
    [switch]$SkipPlugin,
    [switch]$PluginNonFatal,
    [switch]$Insiders,
    [string]$NodeVersion = "24",
    [switch]$Force
)

# Windows PowerShell 5.1 lacks features wiqd's installer relies on (the
# $PSNativeCommandUseErrorActionPreference native-error gate below, ternary
# and null-coalescing operators, && chaining), so it fails cryptically partway
# through. Refuse up front with an actionable message. Placed immediately after
# param() (PowerShell's required-first block) so the gate runs before any other
# logic. Under pwsh 7+ — including CI and the dot-sourced test harness — the
# condition is false and this is a no-op.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "`n  X Windows PowerShell $($PSVersionTable.PSVersion) is not supported." -ForegroundColor Red
    Write-Host "    wiqd requires PowerShell 7 or later.`n" -ForegroundColor Red
    Write-Host "    Install PowerShell 7:" -ForegroundColor Yellow
    Write-Host "      winget install Microsoft.PowerShell`n" -ForegroundColor Yellow
    Write-Host "    Then re-run this installer from pwsh (not powershell.exe):" -ForegroundColor Yellow
    Write-Host "      pwsh -Command `"iex `"`"& { `$(irm 'https://aka.ms/wiqd/install.ps1') }`"`"`"`n" -ForegroundColor Yellow
    # Also emit to stderr: when `wiqd update` runs this script under an EOL pwsh 6,
    # it captures stderr (not the Write-Host host stream) to build its failure
    # message — without this line the user gets a generic "update failed".
    [Console]::Error.WriteLine("Windows PowerShell $($PSVersionTable.PSVersion) is not supported. wiqd requires PowerShell 7 or later. Install it with: winget install Microsoft.PowerShell")
    $global:LASTEXITCODE = 1
    # Under the `iex "& { $(irm ...) }"` web one-liner the installer body runs inside the
    # caller's interactive host, where `exit` would terminate the user's session. Only call
    # exit when running as a real on-disk script (pwsh -File / CI / wiqd update), detected by
    # a populated $PSCommandPath; otherwise fall back to `return` which unwinds only the block.
    if (-not [string]::IsNullOrEmpty($PSCommandPath)) { exit 1 }
    return
}

$ErrorActionPreference = 'Stop'

# PowerShell 7.3+ wraps native-command stderr writes into a terminating
# NativeCommandError when $ErrorActionPreference is 'Stop'. That converts
# benign npm/gh/winget warnings into installer crashes.
# Default to $false at script scope so every native call is judged solely
# by $LASTEXITCODE; Invoke-Native enforces this locally too. PowerShell 5.x
# / 7.0–7.2 ignore the variable, so the assignment is a safe no-op there.
$PSNativeCommandUseErrorActionPreference = $false

$script:InstallUrl = 'https://aka.ms/wiqd/install.ps1'

$MinNodeVersion = [version]"24.15.0"
$WiqdPackage = "@microsoft/wiqd"
$VSCodeExtensionId = "Microsoft.wiqd"
# Some install paths activate additional extensions as part of the same run,
# so the plugin-compose step below must force a rebuild even when `wiqd`
# itself is already up to date (a plain compose would otherwise leave the
# previously-composed skill set deployed). Declared here, in the shared area,
# so it evaluates to falsy in the 3P mirror where no setter ever runs.
$script:PluginForceRecompose = $false

# The plugin step is a foreach over possibly-multiple hosts (copilot, claude),
# so "succeeded" (>=1 host installed cleanly) and "failed" (>=1 host errored)
# are tracked separately from $installSuccess. A host being ABSENT is a
# graceful skip, never a failure; only an attempted-and-errored install trips
# Failed/Succeeded/Skipped/Cancelled (+ FailedPluginHosts) drive the
# summary banners, the skills-list gate, and the final exit code.
$script:PluginInstallFailed = $false
$script:PluginInstallSucceeded = $false
$script:PluginInstallSkipped = $false
$script:PluginInstallCancelled = $false
$script:FailedPluginHosts = @()


# Stamped by sync-version.ps1 — do not edit manually.
$script:WiqdVersion = "0.11.0"


# nvm4w ships npm.ps1 which uses $MyInvocation.InvocationName to parse args.
# When called via & inside another script, InvocationName mismatches the parsed
# command text, corrupting the first argument (e.g. "install" → "pm install").
# Resolve npm.cmd (bypasses the .ps1 wrapper) once and reuse everywhere.
$npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npmCmd) { $npmCmd = Get-Command npm -ErrorAction SilentlyContinue }
$script:NpmExe = if ($npmCmd) { $npmCmd.Source } else { $null }

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

function Write-Step  { param($n, $total, $msg) Write-Host "[$n/$total] $msg" -ForegroundColor Yellow }
function Write-Ok    { param($msg) Write-Host " $msg" -ForegroundColor Green }
function Write-Info  { param($msg) Write-Host " $msg" -ForegroundColor White }
function Write-Warn  { param($msg) Write-Host " $msg" -ForegroundColor DarkYellow }
function Write-Err   { param($msg) Write-Host " ERROR: $msg" -ForegroundColor Red }
function Write-Hint  { param($msg) Write-Host " $msg" -ForegroundColor Gray }

function Test-CommandExists { param($cmd) $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }

# Wraps a native-command invocation so callers can inspect $LASTEXITCODE
# instead of being killed by PowerShell's NativeCommandError wrapper. The
# script block must invoke a single native command;
# this helper does NOT catch CommandNotFoundException — callers needing
# that wrap with try/catch (e.g., the `wiqd --version` probes).
function Invoke-Native {
    param([Parameter(Mandatory)][scriptblock]$Command)

    # Restore-on-exit semantics for $PSNativeCommandUseErrorActionPreference:
    # detect whether the variable existed at this scope BEFORE we mutate it,
    # so we can either restore the prior value or remove the variable
    # afterwards. PowerShell 5.x / 7.0–7.2 don't read the variable; the
    # bookkeeping is harmless on those versions.
    $hadPrev = [bool](Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Local -ErrorAction SilentlyContinue)
    $prev = if ($hadPrev) { $PSNativeCommandUseErrorActionPreference } else { $null }
    $PSNativeCommandUseErrorActionPreference = $false

    try {
        $stdout   = [System.Collections.Generic.List[string]]::new()
        $stderr   = [System.Collections.Generic.List[string]]::new()
        $combined = [System.Collections.Generic.List[string]]::new()

        # 2>&1 merges native stderr into the success stream as ErrorRecord
        # objects. Inspect each pipeline item to separate them back out
        # while also preserving observed order in $combined.
        & $Command 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $line = $_.Exception.Message
                $stderr.Add($line)
                $combined.Add($line)
            } elseif ($null -ne $_) {
                $line = $_.ToString()
                $stdout.Add($line)
                $combined.Add($line)
            }
        }

        return [pscustomobject]@{
            StdOut   = $stdout.ToArray()
            StdErr   = $stderr.ToArray()
            Combined = $combined.ToArray()
            ExitCode = $LASTEXITCODE
            Failed   = ($LASTEXITCODE -ne 0)
        }
    } finally {
        if ($hadPrev) {
            $PSNativeCommandUseErrorActionPreference = $prev
        } else {
            Remove-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Local -ErrorAction SilentlyContinue
        }
    }
}

# Runs a `wiqd --version` / `wiqd doctor` install-time smoke-test through
# Invoke-Native with WIQD_INSTALLER_PROBE=1 and WIQD_TELEMETRY=0 scoped to
# just this call. Install machinery is not real user activity: it must not
# emit a telemetry event, and it must not consume the CLI's one-time
# first-run disclosure before the user's first genuine invocation.
# Prior env values are restored immediately after,
# so the setting never leaks to the rest of the script or the user's session.
function Invoke-WiqdProbe {
    param([Parameter(Mandatory)][scriptblock]$Command)

    $prevProbe = $env:WIQD_INSTALLER_PROBE
    $prevTelemetry = $env:WIQD_TELEMETRY
    $env:WIQD_INSTALLER_PROBE = '1'
    $env:WIQD_TELEMETRY = '0'
    try {
        return Invoke-Native $Command
    } finally {
        $env:WIQD_INSTALLER_PROBE = $prevProbe
        $env:WIQD_TELEMETRY = $prevTelemetry
    }
}

# R32: npm's "already installed" decision is metadata-only — it compares the
# registered package.json version and never checksums the extracted tree, so an
# interrupted install can leave @microsoft/wiqd registered-but-incomplete
# (package.json present, bundle missing) while the version-skip gate still fires.
# This checks the two artifacts that MUST exist and be non-empty for the CLI to
# run: the bin launcher and the esbuild bundle. Transitive deps, the .ps1 shim,
# seeded config, and package.json are deliberately excluded (pruned deps and
# optional files produce false positives; package.json is what npm already
# trusts). Returns the list of missing-or-empty artifact paths; an empty list
# means the install is complete. Fails closed (reports incomplete) when the npm
# global root can't be resolved rather than passing blind.
function Test-WiqdInstallComplete {
    $missing = [System.Collections.Generic.List[string]]::new()

    if (-not $script:NpmExe) {
        $missing.Add('npm (could not resolve npm global root)')
        return $missing.ToArray()
    }

    $rootResult = Invoke-Native { & $script:NpmExe root -g --loglevel=error }
    $npmRoot = if ($rootResult -and -not $rootResult.Failed) {
        ($rootResult.StdOut -join "`n").Trim()
    } else {
        $null
    }
    if (-not $npmRoot) {
        $missing.Add('npm (could not resolve npm global root)')
        return $missing.ToArray()
    }

    $requiredArtifacts = @(
        (Join-Path $npmRoot (Join-Path $WiqdPackage 'bin/wiqd.js')),
        (Join-Path $npmRoot (Join-Path $WiqdPackage 'dist/wiqd-cli.cjs'))
    )

    foreach ($artifact in $requiredArtifacts) {
        $item = Get-Item -LiteralPath $artifact -ErrorAction SilentlyContinue
        if (-not $item -or $item.Length -le 0) {
            $missing.Add($artifact)
        }
    }

    return $missing.ToArray()
}

# Deprecated npm config keys (npm 10.x).
$script:DeprecatedNpmConfigKeys = @(
    'always-auth',
    'cache-min', 'cache-max',
    'cache-lock-stale', 'cache-lock-wait', 'cache-lock-retries',
    'production', 'optional', 'dev'
)

# Reads ~/.npmrc directly (NOT `npm config list` — that command itself
# emits the deprecation warnings we're trying to surface, re-triggering
# the very stderr-noise class we're protecting users from). Returns the
# array of deprecated keys present, or @() if none. Idempotent / cached.
function Test-NpmConfigDeprecation {
    if ($script:NpmConfigDeprecationChecked) {
        return $script:NpmConfigDeprecationFound
    }

    $found = @()
    try {
        $npmrcPath = Join-Path $env:USERPROFILE '.npmrc'
        if (Test-Path -LiteralPath $npmrcPath) {
            $lines = Get-Content -LiteralPath $npmrcPath -ErrorAction SilentlyContinue
            foreach ($raw in $lines) {
                $line = $raw.Trim()
                if (-not $line -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
                $eq = $line.IndexOf('=')
                if ($eq -lt 1) { continue }
                $key = $line.Substring(0, $eq).Trim()
                if ($script:DeprecatedNpmConfigKeys -contains $key -and $found -notcontains $key) {
                    $found += $key
                }
            }
        }
    } catch {
        # Best-effort: missing or unreadable npmrc must not block installation.
    }

    $script:NpmConfigDeprecationFound = $found
    $script:NpmConfigDeprecationChecked = $true
    return $found
}

# Emits the yellow warning for deprecated npmrc keys (call site decides
# WHEN to surface — typically once at the top of the wiqd-install step).
function Show-NpmConfigDeprecationWarning {
    $found = Test-NpmConfigDeprecation
    if ($found.Count -eq 0) { return }

    Write-Host ""
    Write-Warn "Deprecated npm config keys detected in ~/.npmrc:"
    foreach ($key in $found) {
        Write-Host "     $key" -ForegroundColor DarkYellow
    }
    Write-Hint "  These trigger npm warnings that may clutter installer output."
    Write-Hint "  Cleanup (run for each key above): npm config delete <key>"
    Write-Host ""
}

# Returns $true when the installer is allowed to prompt the user
# interactively. Falls closed: any exception → not interactive. CI
# environments, redirected stdin, $env:WIQD_INSTALLER_NON_INTERACTIVE,
# and the -NonInteractive flag (via $script:ForceNonInteractive) all
# suppress the prompt. Public island: both 1P and 3P installers gate
# their EULA prompt on this function, so it must survive the mirror strip.
function Test-IsInstallerInteractive {
    if ($script:ForceNonInteractive) { return $false }
    if ($env:CI) { return $false }
    if ($env:WIQD_INSTALLER_NON_INTERACTIVE) { return $false }
    try {
        return -not [Console]::IsInputRedirected
    } catch {
        return $false
    }
}

function Install-NpmGlobalPackages {
    # The ONE `npm install -g` primitive for every install source: every
    # registry-name or local-tarball install funnels through here with an
    # ORDERED spec list. When two specs are given, order matters — pass the
    # host tarball/name FIRST and any dependent tarball SECOND so the
    # dependent's exact host-version pin resolves from the co-installed local
    # tarball instead of the (not-yet-published) registry.
    param(
        [Parameter(Mandatory)][string[]]$Packages,
        [string]$DisplayName = "wiqd"
    )

    Write-Info "Installing $DisplayName..."

    if (-not $script:NpmExe) {
        Write-Warn "npm not found on PATH"
        return $false
    }

    # Single plain global install. The published @microsoft/wiqd tarball no
    # longer declares bundledDependencies (its bundled extension stubs ship as
    # plain files under extensions/), so npm 11 reifies the full transitive tree on
    # the first pass and runs every install/postinstall script — including
    # @azure/msal-node-runtime's copyBinaries.js, which stages the MSAL native
    # binding. No --ignore-scripts, no in-dir backfill, no npm rebuild —
    # a single-pass npm install.
    $r = Invoke-Native { & $script:NpmExe install -g @Packages --loglevel=error }
    $npmOutput = $r.StdOut

    if ($r.ExitCode -ne 0) {
        # Classify an EEXIST file conflict distinctly from a network/registry
        # failure (R35). npm aborts the whole global install with EEXIST when a
        # launcher target already exists but isn't owned by the installing
        # package — a purely LOCAL problem the GitHub/EMU fallback can't fix (it
        # would hit the identical conflict). Name the exact conflicting file and
        # the removal command, raise the conflict flag so the auto-mode caller
        # skips the misleading network fallback, and stop. Delete nothing.
        $combined = ($r.Combined -join "`n")
        if ($combined -match 'EEXIST') {
            $script:NpmInstallConflict = $true
            $conflictPath = if ($combined -match '(?im)^\s*npm error path\s+(.+?)\s*$') { $Matches[1].Trim() } else { $null }
            Write-Err "npm install failed: a file already exists (EEXIST)."
            if ($conflictPath) {
                Write-Hint "Remove-Item '$conflictPath' -Force   (then re-run this installer)"
            }
            return $false
        }
        # Classify an EACCES/EPERM permission failure distinctly from a
        # network/registry failure (R35). npm aborts the global install when it
        # can't write to the global prefix — a purely LOCAL problem the
        # GitHub/EMU fallback can't fix. Lead with the npm-recommended remedy
        # (point npm at a user-writable prefix), offer elevation as the
        # alternative, and stop. Change nothing. npm itself discourages
        # `sudo npm install -g`, so re-running as Administrator is the fallback,
        # not the headline.
        if ($combined -match 'EACCES' -or $combined -match 'EPERM') {
            $script:NpmInstallPermission = $true
            $prefixResult = Invoke-Native { & $script:NpmExe config get prefix --loglevel=error }
            $npmPrefix = if ($prefixResult.StdOut.Count -gt 0) { $prefixResult.StdOut[0].Trim() } else { $null }
            Write-Err "npm install failed: permission denied on the npm global prefix (EACCES/EPERM)."
            Write-Hint "Point npm at a user-writable prefix, or re-run this installer as Administrator:"
            if ($npmPrefix) {
                Write-Hint "  (current global prefix: $npmPrefix)"
            }
            Write-Hint "  npm config set prefix <dir>   (then re-run this installer)"
            return $false
        }
        Write-Warn "npm install failed for $DisplayName"
        if ($r.StdErr.Count -gt 0) {
            Write-Hint ($r.StdErr -join ' ')
        }
        Write-Hint "Re-run 'npm install -g $($Packages -join ' ')' to see the full npm error output."
        return $false
    }

    $successLine = $npmOutput |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ -match "added|changed|up to date" } |
        Select-Object -First 1

    if ($successLine) {
        Write-Ok $successLine
    } else {
        Write-Ok "$DisplayName installed successfully"
    }

    return $true
}

function Invoke-WiqdSeedDefaults {
    # Seed the default extension registrations at install time via the host's own
    # hidden `wiqd ext seed-defaults` command. Activation is registration-only:
    # mere presence on disk never activates an
    # extension, so the install path is responsible for registering the defaults.
    # The command is idempotent (the seededDefaults ledger gates each id), so a
    # re-run never resurrects a default the user removed and a second invocation
    # is a harmless no-op. Non-fatal: a seeding hiccup leaves wiqd installed and
    # the user can recover with `wiqd doctor` / `wiqd ext add`.
    $r = Invoke-Native { & wiqd ext seed-defaults }
    if ($r.Failed) {
        Write-Warn "Could not seed default extensions automatically."
        Write-Hint "Run 'wiqd doctor' to restore them, or 'wiqd ext add <id>' per default."
        return $false
    }
    Write-Ok "Default extensions registered"
    return $true
}

# Renders the post-install dependency verdict for the downstream CLIs, sourced
# from `wiqd doctor --json` so the installer and doctor never disagree on presence.
# Severity is row-owned, NOT taken from doctor's status: a missing REQUIRED dep
# (atk) is fatal and the caller must stop the install; a missing OPTIONAL dep
# (eval/workiq/EULA) degrades gracefully and only warns. Returns $true to
# continue, $false when a required dependency is missing (caller exits 1).
# Fails closed with the canonical reinstall hint when the probe is unavailable
# or its JSON can't be parsed because required ATK presence cannot be verified.
function Show-DependencyStatus {
    # Ordered display rows. `Keys` maps onto the doctor check `name`s: the
    # healthy workiq probe is named "workiq --json", but a missing one collapses
    # to "workiq", so both names are accepted for the workiq row. `ExtensionId`
    # supplies the registration repair when doctor omitted the check entirely;
    # emitted failures use doctor's own trimmed message.
    $rows = @(
        @{ Keys = @('atk');                     Label = 'atk';         Required = $true;  OkWord = 'Installed'; Note = '(required for `wiqd agent` commands)';       ExtensionId = 'microsoft.atk';    ReRun = $true }
        @{ Keys = @('runevals');                Label = 'runevals';    Required = $false; OkWord = 'Installed'; Note = '(optional - needed for `wiqd agent eval`)'; ExtensionId = 'microsoft.eval';   ReRun = $true }
        @{ Keys = @('workiq --json', 'workiq'); Label = 'workiq';      Required = $false; OkWord = 'Installed'; Note = '(optional - needed for `wiqd agent` commands)'; ExtensionId = 'microsoft.workiq'; ReRun = $true }
        @{ Keys = @('workiq EULA', 'workiq');   Label = 'workiq EULA'; Required = $false; OkWord = 'Accepted';  Note = '';                                            ExtensionId = 'microsoft.workiq'; ReRun = $false }
    )

    $probe = Invoke-WiqdProbe { & wiqd doctor --json }
    $checks = $null
    if ($probe.StdOut.Count -gt 0) {
        try {
            $checks = (($probe.StdOut -join "`n") | ConvertFrom-Json).data.checks
        } catch {
            $checks = $null
        }
    }
    if (-not $checks) {
        Write-Err "Could not verify required downstream components."
        Write-Hint "Re-run: npm install -g @microsoft/wiqd"
        return $false
    }

    # Materialize the checks as an ordered list so rows can consume matches
    # positionally. This matters when workiq is MISSING: doctor collapses BOTH
    # the "workiq --json" and "workiq EULA" checks to the bare name "workiq", so
    # a name→single-value map would lose one. Consuming in declaration order
    # (probe before EULA) assigns each collapsed "workiq" entry to the right row.
    $checkList = @($checks)
    $consumed = New-Object 'bool[]' $checkList.Count

    $labelWidth = (($rows | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum) + 2
    $contIndent = ' ' * ($labelWidth + 6)  # aligns wrapped lines under the message column

    $resolved = @()
    $allOk = $true
    $fatal = $false
    foreach ($row in $rows) {
        $check = $null
        for ($i = 0; $i -lt $checkList.Count; $i++) {
            if ($consumed[$i]) { continue }
            if ($row.Keys -contains [string]$checkList[$i].name) {
                $check = $checkList[$i]
                $consumed[$i] = $true
                break
            }
        }
        $isOk = ($null -ne $check) -and ([string]$check.status -eq 'ok')
        if (-not $isOk) {
            $allOk = $false
            if ($row.Required) { $fatal = $true }
        }
        $resolved += @{ Row = $row; Check = $check; IsOk = $isOk }
    }

    Write-Host ""
    if ($allOk) {
        Write-Host " ✓ All required components are installed and ready." -ForegroundColor Green
    } elseif ($fatal) {
        Write-Host " ⚠ Setup incomplete." -ForegroundColor Yellow
        Write-Host " Required components are missing; repair them before using wiqd." -ForegroundColor Yellow
    } else {
        Write-Host " ⚠ Optional components need attention." -ForegroundColor Yellow
        Write-Host " wiqd is installed; affected optional commands may be unavailable." -ForegroundColor Yellow
    }

    foreach ($item in $resolved) {
        $row = $item.Row
        $label = ($row.Label + ':').PadRight($labelWidth)
        if ($item.IsOk) {
            $text = "   ✓ $label $($row.OkWord)"
            if ($row.Note) { $text += "  $($row.Note)" }
            Write-Host $text -ForegroundColor Green
            continue
        }

        # Not OK: required rows are a red ✗, optional rows a yellow ⚠.
        $icon = if ($row.Required) { '✗' } else { '⚠' }
        $color = if ($row.Required) { 'Red' } else { 'DarkYellow' }
        $lead = if ($null -eq $item.Check) {
            "Extension check unavailable ($($row.ExtensionId) is inactive)."
        } else {
            Get-ShortDoctorMessage $item.Check
        }
        Write-Host "   $icon $label $lead" -ForegroundColor $color
        if ($row.ReRun) {
            $repair = if ($null -eq $item.Check) { "wiqd ext add $($row.ExtensionId)" } else { 'npm install -g @microsoft/wiqd' }
            Write-Host "${contIndent}Re-run: " -ForegroundColor Gray -NoNewline
            Write-Host $repair -ForegroundColor Cyan
        }
    }
    Write-Host ""

    return -not $fatal
}

# Trims a doctor check message to its lead clause for compact install-time
# display: cuts at the first em-dash or sentence boundary so a long remediation
# message collapses to e.g. "workiq not found" / "EULA not accepted".
function Get-ShortDoctorMessage {
    param($check)
    if (-not $check) { return 'Not available' }
    $msg = [string]$check.message
    if (-not $msg) { return 'Not available' }
    $msg = ($msg -split ' — ')[0]
    $msg = ($msg -split '\. ')[0]
    return $msg.Trim()
}


function Install-FromNpmRegistry {
    param($package, $version)

    # Always pin an exact, already-resolved version (R29/R31) — a bare package name
    # or a floating dist-tag would silently resolve npm's 'latest' dist-tag, which
    # carries no prerelease during the preview period and would install the wrong
    # build.
    $packageSpec = if ($version) { "$package@$version" } else { $package }

    return (Install-NpmGlobalPackages -Packages @($packageSpec) -DisplayName "$packageSpec from npm registry")
}


function Get-NodeVersion {
    try {
        $r = Invoke-Native { & node --version }
        $raw = if ($r.StdOut.Count -gt 0) { $r.StdOut[0] } else { '' }
        if ($raw -match 'v?(\d+\.\d+\.\d+)') { return [version]$Matches[1] }
    } catch { }
    return $null
}

function Get-NpmGlobalPackageVersion {
    param($package)
    try {
        # --loglevel=error suppresses npm warnings on stderr (defense in depth);
        # Invoke-Native splits stdout from stderr so stray warnings can never
        # pollute the JSON parse downstream.
        $r = Invoke-Native { & $script:NpmExe list -g $package --json --depth=0 --loglevel=error }
        if ($r.StdOut.Count -eq 0) { return $null }
        $json = ($r.StdOut -join "`n") | ConvertFrom-Json
        $deps = $json.dependencies
        if ($deps -and $deps.PSObject.Properties[$package]) {
            return $deps.PSObject.Properties[$package].Value.version
        }
    } catch { }
    return $null
}

function Get-TargetVersion {
    param($Source, $Repo, $Version, $Package)

    # Explicit version or dist-tag requested — resolve it to a concrete version via
    # the registry (R30) so the up-to-date comparison never diffs a moving tag (e.g.
    # "preview") against an installed concrete version. Falls back to the literal
    # (leading 'v' stripped) if the registry can't be reached.
    if ($Version -and $Version -ne "latest") {
        if ($Source -in @("npm", "auto")) {
            try {
                $r = Invoke-Native { & $script:NpmExe view "$Package@$Version" version --loglevel=error }
                $ver = if ($r.StdOut.Count -gt 0) { $r.StdOut[0] } else { '' }
                if ($r.ExitCode -eq 0 -and $ver) {
                    return $ver.Trim()
                }
            } catch { }
        }
        return ($Version -replace '^v', '')
    }


    # No explicit version, npm source — pin to the exact version stamped into this
    # installer at release time (R29), never a dist-tag query: during the preview
    # period the 'latest' dist-tag does not carry the prerelease, so resolving it
    # here would silently downgrade or skip a preview build.
    if ($Source -in @("npm", "auto")) {
        return $script:WiqdVersion
    }

    # Could not determine target version — let install proceed to be safe.
    return $null
}

function Refresh-PathInSession {
    # Append newly-registered PATH entries without overwriting process-local paths
    $machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $registered = "$machinePath;$userPath" -split ";" | Where-Object { $_ }
    $current = $env:PATH -split ";" | Where-Object { $_ }
    $missing = $registered | Where-Object { $_ -notin $current }
    if ($missing) {
        $env:PATH = ($current + $missing) -join ";"
    }
}

function Remove-WiqdPowerShellShim {
    try {
        if (-not $script:NpmExe) {
            return
        }

        $r = Invoke-Native { & $script:NpmExe config get prefix --loglevel=error }
        $npmPrefix = if ($r.StdOut.Count -gt 0) { $r.StdOut[0] } else { '' }
        if ([string]::IsNullOrWhiteSpace($npmPrefix) -or $npmPrefix -eq "undefined" -or $npmPrefix -eq "null") {
            return
        }

        # Remove the .ps1 shim that npm creates — it's unsigned and blocked by
        # restrictive PowerShell execution policies. The .cmd shim works fine.
        $ps1Shim = Join-Path $npmPrefix.Trim() "wiqd.ps1"
        Remove-Item $ps1Shim -Force -ErrorAction SilentlyContinue
    } catch {
        # Best-effort cleanup. Missing shims or prefix lookup failures should not
        # block the install because the .cmd shim remains available.
    }
}


# ─────────────────────────────────────────────
# Quick Start helpers
# ─────────────────────────────────────────────

function Get-WiqdInstalledSkills {
    # Reads installed skill names from the globally-installed wiqd package and
    # its bundled extensions. Skills live in two places:
    #   1. $npmRoot/@microsoft/wiqd/plugin/skills/         (core/bundled)
    #   2. $npmRoot/@microsoft/wiqd/extensions/wiqd-ext-*/skills/  (extension-contributed)
    # We deduplicate (bundle wins, matching MarketplaceStaging) and sort.
    # We use `npm root -g` so the path works across Windows/macOS/Linux.
    try {
        if ($null -eq $script:NpmExe) {
            return @()
        }

        $rootResult = Invoke-Native { & $script:NpmExe root -g --loglevel=error }
        $npmRoot = if ($rootResult.StdOut.Count -gt 0) { $rootResult.StdOut[0].Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($npmRoot)) {
            return @()
        }

        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $names = [System.Collections.Generic.List[string]]::new()

        # 1. Bundle skills (wins on conflicts).
        $bundleSkills = Join-Path $npmRoot "@microsoft" "wiqd" "plugin" "skills"
        if (Test-Path $bundleSkills) {
            Get-ChildItem -Path $bundleSkills -Directory -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Name.StartsWith('_') } |
                ForEach-Object {
                    if ($seen.Add($_.Name)) { [void]$names.Add($_.Name) }
                }
        }

        # 2. Extension-contributed skills (alphabetic discovery order, first wins).
        $extRoot = Join-Path $npmRoot "@microsoft" "wiqd" "extensions"
        if (Test-Path $extRoot) {
            Get-ChildItem -Path $extRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'wiqd-ext-*' } |
                Sort-Object Name |
                ForEach-Object {
                    $extSkills = Join-Path $_.FullName "skills"
                    if (Test-Path $extSkills) {
                        Get-ChildItem -Path $extSkills -Directory -ErrorAction SilentlyContinue |
                            Where-Object { -not $_.Name.StartsWith('_') } |
                            ForEach-Object {
                                if ($seen.Add($_.Name)) { [void]$names.Add($_.Name) }
                            }
                    }
                }
        }

        return @($names | Sort-Object)
    } catch {
        return @()
    }
}

function Write-WiqdQuickstart {
    # Renders the closing Quick Start block. Kept compact and helper-driven
    # to minimize merge conflicts with in-flight installer edits.
    # Must mirror the bash installer's print_wiqd_quickstart output character-
    # for-character (diff is shell-idiom only). Host-aware: the plugin is only
    # composed for a plugin host that is present, so the guidance matches what
    # the user can actually run — Copilot CLI commands when Copilot is on PATH,
    # Claude Code guidance when only Claude is, and a manual-finish hint (not a
    # host the user lacks) when neither is present.
    $installedSkills = Get-WiqdInstalledSkills
    $copilotPresent = Test-CommandExists 'copilot'
    $claudePresent = Test-CommandExists 'claude'
    Write-Host " Quick Start:" -ForegroundColor Cyan
    Write-Host "   wiqd agent create --name my-agent              Create a new agent" -ForegroundColor White
    Write-Host "   wiqd agent validate                            Validate your agent" -ForegroundColor White
    Write-Host "   wiqd agent provision --env local               Deploy locally" -ForegroundColor White
    Write-Host ""
    if ($copilotPresent) {
        Write-Host " Or with Copilot CLI (interactive mode):" -ForegroundColor Cyan
        Write-Host "   copilot -i `"create a new declarative agent`"" -ForegroundColor White
        Write-Host "   copilot -i `"validate my agent`"" -ForegroundColor White
        Write-Host "   copilot -i `"deploy my agent locally`"" -ForegroundColor White
        Write-Host ""
    } elseif ($claudePresent) {
        Write-Host " Or in Claude Code — the wiqd plugin's slash commands are available." -ForegroundColor Cyan
        Write-Host ""
    }
    if ($copilotPresent -or $claudePresent) {
        # Gate the skills list on the plugin step actually SUCCEEDING this run,
        # never on host presence alone — Get-WiqdInstalledSkills reads the npm
        # bundle on disk, which exists regardless of whether `wiqd component
        # plugin install` ever ran or failed, so host-presence-only gating
        # produced a phantom list. Require a CLEAN run (succeeded AND not
        # failed): in a multi-host loop one host can succeed while another
        # fails, and the bundle-derived list has no way to attribute skills to
        # a specific host, so ANY attempted failure must suppress the blanket
        # list rather than overstate success next to a partial-install banner.
        if ($script:PluginInstallSucceeded -and -not $script:PluginInstallFailed -and -not $script:PluginInstallCancelled) {
            Write-Host " Installed wiqd skills:" -ForegroundColor Cyan
            if ($installedSkills.Count -gt 0) {
                foreach ($name in $installedSkills) {
                    Write-Host "   /$name" -ForegroundColor White
                }
            } else {
                Write-Host "   (No installed skills detected — see https://aka.ms/wiqd/docs)" -ForegroundColor Gray
            }
            Write-Host ""
        } elseif (-not $script:PluginInstallSkipped -and -not $script:PluginInstallCancelled) {
            Write-Host " wiqd skills are not installed for this host yet." -ForegroundColor Yellow
            # Prefer a host we KNOW failed over the present-host fallback, so a
            # mixed-host run (one succeeded, one failed) points the retry hint
            # at the host that actually needs it instead of a working one.
            $retryHost = if ($script:FailedPluginHosts.Count -gt 0) { $script:FailedPluginHosts[0] } elseif ($copilotPresent) { 'copilot' } else { 'claude' }
            Write-Host "   Run 'wiqd component plugin install --cli $retryHost' to install them" -ForegroundColor White
            Write-Host ""
        }
    } else {
        Write-Host " To use wiqd inside an agent, install Copilot CLI or Claude Code, then run:" -ForegroundColor Cyan
        Write-Host "   wiqd component plugin install    (add --cli claude for Claude Code)" -ForegroundColor White
        Write-Host ""
    }
    Write-Host " Documentation:" -ForegroundColor Cyan
    Write-Host "   https://aka.ms/wiqd/docs" -ForegroundColor White
    Write-Host ""
}



# A real install is always EXECUTED (iex "& { $(irm …) }"), never dot-sourced —
# only this repo's test harness dot-sources this file to import its functions.
# Gate on BOTH the explicit opt-in AND dot-source context; an externally-set
# WIQD_INSTALLER_TEST_MODE on a real (executed) install is inert. No shippable
# sentinel value to discover or abuse.
if ($env:WIQD_INSTALLER_TEST_MODE -and $MyInvocation.InvocationName -eq '.') { return }

# The entire imperative install program is wrapped in a function that RETURNS
# its 0/1/2/130 result code instead of calling `exit`. Under the canonical
# `iex "& { $(irm ...) }"` one-liner, the block runs inside the caller's
# interactive host — an `exit` anywhere in this body would terminate the
# user's whole PowerShell session instead of just this install run. The single
# terminal call site (at the very end of this file) is the only place that
# ever calls `exit`, and only when this is a real on-disk invocation.
function Invoke-WiqdInstall {

# ─────────────────────────────────────────────
# Banner — Witch hat + gradient WIQD block letters
# Matches the CLI's Banner.cs output using ANSI true-color
# ─────────────────────────────────────────────

function Show-WiqdBanner {
    $e = [char]27

    # ANSI true-color foreground helpers
    function Fg($r, $g, $b) { "$e[38;2;${r};${g};${b}m" }
    $reset = "$e[0m"

    # M365 Copilot brand palette (same RGB values as Banner.cs)
    $lime    = Fg 192 200  40
    $green   = Fg  72 168  96
    $teal    = Fg  24 168 200
    $blue    = Fg   0 144 216
    $purple  = Fg 168  72 192
    $magenta = Fg 216  72 144
    $pink    = Fg 240  72 120
    $coral   = Fg 240 120  96
    $orange  = Fg 240 144  72
    $dim     = Fg 110 116 130

    Write-Host ""

    # Hat (per-row color matching Banner.cs)
    Write-Host " $lime               ╱╲              $reset"
    # Row 1: sparkles ✦ at col 9 (Pink), ✧ at col 23 (Lime)
    Write-Host -NoNewline " ${green}         "
    Write-Host -NoNewline "${pink}✦"
    Write-Host -NoNewline "${green}    ╱  ╲     "
    Write-Host -NoNewline "${lime}✧"
    Write-Host "${green}       $reset"
    # Row 2: sparkle ✧ at col 27 (Blue)
    Write-Host -NoNewline " ${teal}             ╱    ╲        "
    Write-Host -NoNewline "${blue}✧"
    Write-Host "${teal}   $reset"
    Write-Host " $magenta            ╱══════╲           $reset"
    # Row 4: sparkles · at col 5 (Purple), · at col 27 (Coral)
    Write-Host -NoNewline " ${blue}     "
    Write-Host -NoNewline "${purple}·"
    Write-Host -NoNewline "${blue}     ╱        ╲      "
    Write-Host -NoNewline "${coral}·"
    Write-Host "${blue}   $reset"
    Write-Host " $purple          ╱          ╲         $reset"
    Write-Host " $coral     ____╱____________╲____    $reset"
    Write-Host " $orange    ╱______________________╲   $reset"
    Write-Host ""

    # WIQD block letters — 7-stop gradient sampled per character column
    $wiqdLines = @(
        "  ██╗    ██╗██╗ ██████╗ ██████╗ "
        "  ██║    ██║██║██╔═══██╗██╔══██╗"
        "  ██║ █╗ ██║██║██║   ██║██║  ██║"
        "  ██║███╗██║██║██║▄▄ ██║██║  ██║"
        "  ╚███╔███╔╝██║╚██████╔╝██████╔╝"
        "   ╚══╝╚══╝ ╚═╝ ╚══▀▀═╝ ╚═════╝ "
    )

    # Gradient stops: LIME → GREEN → TEAL → BLUE → PURPLE → MAGENTA → CORAL
    $stops = @(
        @(192, 200,  40), @( 72, 168,  96), @( 24, 168, 200),
        @(  0, 144, 216), @(168,  72, 192), @(216,  72, 144),
        @(240, 120,  96)
    )

    foreach ($line in $wiqdLines) {
        $sb = [System.Text.StringBuilder]::new(" ")
        $maxC = $line.Length
        for ($c = 0; $c -lt $maxC; $c++) {
            $ch = $line[$c]
            if ($ch -eq ' ') {
                [void]$sb.Append(' ')
            } else {
                # Linearly interpolate between gradient stops
                $pos = if ($maxC -gt 1) { ($c / ($maxC - 1)) * ($stops.Count - 1) } else { 0 }
                $idx = [math]::Floor($pos)
                $frac = $pos - $idx
                if ($idx -ge $stops.Count - 1) { $idx = $stops.Count - 2; $frac = 1.0 }
                $a = $stops[$idx]; $b = $stops[$idx + 1]
                $r = [int]($a[0] + ($b[0] - $a[0]) * $frac)
                $g = [int]($a[1] + ($b[1] - $a[1]) * $frac)
                $bl = [int]($a[2] + ($b[2] - $a[2]) * $frac)
                [void]$sb.Append("$e[38;2;${r};${g};${bl}m$ch")
            }
        }
        [void]$sb.Append($reset)
        Write-Host $sb.ToString()
    }

    Write-Host ""
    Write-Host " ${dim}       wiqd installer v${script:WiqdVersion}$reset"
    Write-Host ""
}

Show-WiqdBanner

# ─────────────────────────────────────────────
# EULA acceptance prompt — before any real work
# ─────────────────────────────────────────────
# On a fresh install the user hasn't accepted wiqd's EULA yet, so the first
# product command would be rejected by the gate. We fold the acceptance into
# the installer's own interactive flow: show the pre-release notice, prompt
# accept/decline, and (after a successful install) persist the acceptance via
# the hidden --installer-stamp flag. On upgrade, when the current EULA version
# is already accepted, we skip the prompt entirely.

function Read-EulaAcceptance {
    # Check whether an existing wiqd install already has the EULA accepted for
    # the version being installed. If so, skip the prompt.
    if (Get-Command wiqd -ErrorAction SilentlyContinue) {
        try {
            $r = Invoke-Native { & wiqd eula status --json }
            $statusJson = $r.Stdout -join "`n" | ConvertFrom-Json
            if ($statusJson.status -eq 'success') {
                $wiqdRow = $statusJson.data.wiqd
                if ($wiqdRow -and $wiqdRow.tool -eq 'wiqd' -and $wiqdRow.state -eq 'accepted') {
                    return 'already-accepted'
                }
            }
        } catch {
            # wiqd not functional or too old — fall through to prompt.
        }
    }

    if (-not (Test-IsInstallerInteractive)) {
        Write-Warn "EULA acceptance required but installer is running non-interactively."
        Write-Hint "Re-run the installer in an interactive terminal to accept the EULA."
        return 'non-interactive'
    }

    Write-Host ""
    Write-Host " Pre-release notice" -ForegroundColor Yellow
    Write-Host "   wiqd is experimental software shared for experimentation" -ForegroundColor White
    Write-Host "   purposes only. It is not production-ready and is not" -ForegroundColor White
    Write-Host "   officially supported. Expect breaking changes." -ForegroundColor White
    Write-Host ""
    Write-Host "   EULA: https://aka.ms/wiqd/eula" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Choose how to proceed:" -ForegroundColor White
    Write-Host "   [a] Accept the EULA and continue installing" -ForegroundColor White
    Write-Host "   [c] Cancel and exit" -ForegroundColor White
    Write-Host ""

    $prompt = " Your choice [default: a]: "
    $reply = Read-Host -Prompt $prompt
    if ([string]::IsNullOrWhiteSpace($reply)) { $reply = 'a' }

    switch ($reply.Trim().ToLowerInvariant()) {
        'a' { return 'accepted' }
        default { return 'declined' }
    }
}

$eulaChoice = Read-EulaAcceptance

if ($eulaChoice -eq 'declined') {
    Write-Host ""
    Write-Warn "Cancelled — EULA not accepted. Nothing was installed."
    return 1
}

if ($eulaChoice -eq 'non-interactive') {
    Write-Host ""
    Write-Warn "Cannot proceed without EULA acceptance in non-interactive mode."
    return 1
}

# $eulaChoice is 'accepted' or 'already-accepted' — continue with install.
# The acceptance will be persisted after a successful install (see post-install).

# Determine total steps
$totalSteps = 3
if (-not $SkipVSCode) { $totalSteps++ }
if (-not $SkipPlugin) { $totalSteps++ }

# ─────────────────────────────────────────────
# Step 1: Ensure Node.js
# ─────────────────────────────────────────────

Write-Step 1 $totalSteps "Checking Node.js..."

# The 3P installer never installs Node — it only verifies a usable Node is
# already present and blocks with guidance when it is missing or too old.
$nodeVer = Get-NodeVersion
if (-not $nodeVer) {
    Write-Err "Node.js is required but was not found on PATH."
    Write-Host ""
    Write-Host " Install Node.js v$MinNodeVersion or newer, then re-run this installer:" -ForegroundColor Yellow
    Write-Host "   https://nodejs.org/en/download/" -ForegroundColor White
    Write-Host ""
    return 1
}
if ($nodeVer -lt $MinNodeVersion) {
    Write-Err "Node.js v$nodeVer found, but wiqd requires v$MinNodeVersion or newer."
    Write-Host ""
    Write-Host " Upgrade Node.js, then re-run this installer:" -ForegroundColor Yellow
    Write-Host "   https://nodejs.org/en/download/" -ForegroundColor White
    Write-Host ""
    return 1
}
Write-Ok "Node.js v$nodeVer detected"

# nvm4w ships an npm.ps1 wrapper that corrupts args when called via &; resolve
# npm.cmd once and reuse it (mirrors the top-of-script resolution).
$npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npmCmd) { $npmCmd = Get-Command npm -ErrorAction SilentlyContinue }
$script:NpmExe = if ($npmCmd) { $npmCmd.Source } else { $null }

if (-not (Test-CommandExists "npm")) {
    Write-Err "npm not found despite Node.js being installed."
    Write-Hint "Restart your terminal and re-run this installer."
    return 1
}
$npmVerResult = Invoke-Native { & $script:NpmExe --version }
$npmVer = if ($npmVerResult.StdOut.Count -gt 0) { $npmVerResult.StdOut[0] } else { 'unknown' }
Write-Ok "npm v$npmVer ready"

# Surface stale ~/.npmrc keys once, before any npm install runs.
Show-NpmConfigDeprecationWarning

# ─────────────────────────────────────────────
# Step 2: Install wiqd (npm global)
# ─────────────────────────────────────────────

Write-Step 2 $totalSteps "Installing wiqd CLI..."

$currentVersion = Get-NpmGlobalPackageVersion $WiqdPackage
$installedWiqdVersion = $script:WiqdVersion
# Resolved unconditionally (not just when something is already installed) because
# the actual install call below also needs a concrete, pinned version (R29/R30) —
# never a bare package name or a floating dist-tag.
$targetVersion = Get-TargetVersion -Source $Source -Repo $Repo -Version $Version -Package $WiqdPackage

# Skip install only when the exact target version already matches — no -Force
# needed to upgrade.
$skipInstall = $false
if ($currentVersion -and -not $Force) {
    if ($targetVersion -and $currentVersion -eq $targetVersion) {
        $skipInstall = $true
    }
}

if ($skipInstall) {
    $installedWiqdVersion = $currentVersion
    # R32: a neutral hand-off, NOT a health claim. Step 3 owns the verdict.
    Write-Info "Found wiqd v$currentVersion — verifying..."
    Write-Hint "Use -Force to reinstall"
    Remove-WiqdPowerShellShim
} else {
    if ($currentVersion) {
        Write-Info "Updating wiqd (current: v$currentVersion)..."
    }

    $script:NpmInstallConflict = $false
    $script:NpmInstallPermission = $false
    $installOk = Install-FromNpmRegistry -package $WiqdPackage -version $targetVersion

    if (-not $installOk) {
        if ($script:NpmInstallConflict) {
            # EEXIST advisory (exact file + removal command) already printed by
            # the install primitive (R35). A local file conflict is not a
            # network problem, so don't add the connectivity hint.
            return 1
        }
        if ($script:NpmInstallPermission) {
            # EACCES/EPERM advisory (prefix fix + elevation) already printed by
            # the install primitive (R35). A local permission failure is not a
            # network problem, so don't add the connectivity hint.
            return 1
        }
        Write-Err "wiqd installation failed."
        Write-Host ""
        Write-Hint "Check your network connection and that npm can reach the registry, then re-run."
        return 1
    }

    Remove-WiqdPowerShellShim

    Refresh-PathInSession
    $wiqdVer = $null
    try {
        $r = Invoke-WiqdProbe { & wiqd --version }
        if ($r.ExitCode -eq 0 -and $r.StdOut.Count -gt 0) {
            $wiqdVer = $r.StdOut[0]
        }
    } catch { }

    if ($wiqdVer) {
        $installedWiqdVersion = $wiqdVer.Trim()
        Write-Ok "wiqd installed: $installedWiqdVersion"
    } else {
        $prefixResult = Invoke-Native { & $script:NpmExe config get prefix --loglevel=error }
        $npmBin = if ($prefixResult.StdOut.Count -gt 0) { $prefixResult.StdOut[0] } else { '' }
        if ($npmBin) {
            Write-Warn "wiqd installed but not in PATH"
            Write-Hint "Add to PATH: $npmBin"
        } else {
            Write-Err "wiqd installation could not be verified"
        }
    }
}


# ─────────────────────────────────────────────
# Step 3: Verify installation
# ─────────────────────────────────────────────
#
# ATK (@microsoft/m365agentstoolkit-cli), eval (@microsoft/m365-copilot-eval),
# and workiq (@microsoft/workiq@preview) are all declared as regular npm
# dependencies of @microsoft/wiqd, so Step 2's
# `npm install -g @microsoft/wiqd` resolves them transitively into
# <npm-prefix>/lib/node_modules/@microsoft/wiqd/node_modules/.bin/. wiqd's
# binary-resolver finds them there at command-execution time. No imperative
# install step is needed — `wiqd doctor` is the authoritative post-install
# verifier for these tools.

Write-Step 3 $totalSteps "Verifying installation..."

$installSuccess = $false

# R32: verify on-disk completeness BEFORE trusting a runtime probe. npm reports
# "already installed" on version metadata alone, so an interrupted install can
# leave the package registered-but-incomplete and the probe below could either
# run a stale copy or fail confusingly. A missing/empty required artifact is a
# fatal verdict with an uninstall-first repair (a plain re-run or -Force is an
# npm no-op on same-version corruption — only `npm uninstall -g` re-extracts).
$missingArtifacts = @(Test-WiqdInstallComplete)
if ($missingArtifacts.Count -gt 0) {
    Write-Err "installation incomplete. Repair:"
    Write-Hint "  npm uninstall -g $WiqdPackage, then re-run this installer."
    return 1
}

try {
    $r = Invoke-WiqdProbe { & wiqd --version }
    $wiqdCheck = if ($r.StdOut.Count -gt 0) { $r.StdOut[0] } else { $null }
    if ($wiqdCheck) {
        $installedWiqdVersion = $wiqdCheck.Trim()
        Write-Ok "wiqd CLI: $installedWiqdVersion"
        $installSuccess = $true
        # Seed the default extension registrations now that the host is on PATH.
        # Registration-only activation means the defaults are inert until the
        # install path registers them; do it before the plugin step so the
        # plugin composes from the active set. Non-fatal.
        Invoke-WiqdSeedDefaults | Out-Null
    } else {
        # R32: files are present (completeness passed above) but the CLI didn't
        # run — it's a PATH problem, not a broken install. Fatal so the exit
        # code is honest, with the uninstall-first repair as the fallback.
        Write-Err "wiqd installed, but not yet on PATH. Restart your terminal."
        Write-Hint "  Still failing? npm uninstall -g $WiqdPackage, then re-run this installer."
        return 1
    }
} catch {
    Write-Err "wiqd installed, but not yet on PATH. Restart your terminal."
    Write-Hint "  Still failing? npm uninstall -g $WiqdPackage, then re-run this installer."
    return 1
}

# A missing REQUIRED dependency (atk) is fatal: stop before the VS Code /
# plugin steps so the user fixes the broken install first.
if (-not (Show-DependencyStatus)) {
    return 1
}

# Persist EULA acceptance now that the wiqd CLI is verified on PATH — BEFORE the
# host-integration steps (VS Code, plugin) that themselves invoke EULA-gated
# wiqd commands. The human already accepted at the installer's own interactive
# prompt; this only records the version-stamped acceptance so those steps run
# un-gated. Non-fatal: the user can still run `wiqd eula accept wiqd` manually.
if ($eulaChoice -eq 'accepted') {
    try {
        Invoke-Native { & wiqd eula accept wiqd --installer-stamp } | Out-Null
    } catch {
        # Non-fatal: the user can still run `wiqd eula accept wiqd` manually.
    }
}

# ─────────────────────────────────────────────
# Step 4: VS Code Extension (optional)
# ─────────────────────────────────────────────

if (-not $SkipVSCode) {
    $stepNum = 4

    $codeCmd = if ($Insiders) { "code-insiders" } else { "code" }
    $codeName = if ($Insiders) { "VS Code Insiders" } else { "VS Code" }

    Write-Step $stepNum $totalSteps "Installing $codeName extension..."

    if (Test-CommandExists $codeCmd) {
        # Check if already installed (skip the short-circuit when -Force is set:
        # devs explicitly asked for a full reinstall, so re-run --install-extension
        # which itself already passes --force and idempotently overwrites).
        $listResult = Invoke-Native { & $codeCmd --list-extensions }
        $extensions = $listResult.StdOut
        if (($extensions -match $VSCodeExtensionId) -and -not $Force) {
            Write-Ok "Work IQ extension already installed in $codeName"
        } else {
            try {
                if (($extensions -match $VSCodeExtensionId) -and $Force) {
                    Write-Info "Reinstalling Work IQ extension in $codeName (-Force)..."
                }
                & $codeCmd --install-extension $VSCodeExtensionId --force 2>&1 | Out-Null
                Write-Ok "Work IQ extension installed in $codeName"
            } catch {
                Write-Warn "Could not install extension: $_"
                Write-Hint "Install manually: $codeCmd --install-extension $VSCodeExtensionId"
            }
        }
    } else {
        Write-Warn "$codeName not found — skipping extension install"
        Write-Hint "Install $codeName from https://code.visualstudio.com/"
    }
}

# ─────────────────────────────────────────────
# Step N: Copilot CLI Plugin (automatic)
# ─────────────────────────────────────────────

if ($SkipPlugin) {
    $script:PluginInstallSkipped = $true
}

if (-not $SkipPlugin) {
    $pluginStepNum = 4
    if (-not $SkipVSCode) { $pluginStepNum = 5 }

    Write-Step $pluginStepNum $totalSteps "Installing wiqd plugin..."

    if ($installSuccess) {
        # We NEVER install a plugin host. Installing a third-party agent CLI
        # (Copilot CLI / Claude Code) without consent is out of scope for the
        # wiqd install — the host is the plugin host, not a wiqd dependency.
        # Detect which supported host(s) are already on PATH and
        # compose the plugin only for those; `wiqd component plugin install --cli <host>`
        # resolves the same binary, so a PATH hit here matches the command's own
        # host check. If neither host is present, skip gracefully and
        # non-fatally — the wiqd CLI install itself is already complete.
        $pluginHosts = @()
        if (Test-CommandExists 'copilot') { $pluginHosts += 'copilot' }
        if (Test-CommandExists 'claude') { $pluginHosts += 'claude' }

        if ($pluginHosts.Count -eq 0) {
            Write-Info "No Copilot CLI or Claude Code detected — skipping plugin install."
            Write-Hint "Install one, then run 'wiqd component plugin install' (add '--cli claude' for Claude Code)."
        } else {
            foreach ($pluginHost in $pluginHosts) {
                try {
                    # Every `wiqd component plugin install` is a clean reinstall (it wipes the
                    # target plugin dir before copying the bundle), so no --force is
                    # needed to refresh an existing install. --force IS needed when an
                    # install path activated additional extensions in this same run: a
                    # plain compose treats an unchanged wiqd version as already up to
                    # date and would leave the prior toggle's skill set deployed, so
                    # --force forces the uninstall-then-reinstall that rebuilds the
                    # plugin tree from the freshly-composed source.
                    $pluginInstallArgs = @('component', 'plugin', 'install', '--cli', $pluginHost)
                    if ($script:PluginForceRecompose) { $pluginInstallArgs += '--force' }
                    $pluginOutput = & wiqd @pluginInstallArgs 2>&1
                    $pluginExitCode = $LASTEXITCODE
                    if ($pluginExitCode -eq 0) {
                        Write-Ok "wiqd plugin installed for $pluginHost"
                        $script:PluginInstallSucceeded = $true
                    } elseif ($pluginExitCode -eq 130) {
                        Write-Warn "wiqd plugin install cancelled for $pluginHost (exit code 130)"
                        $pluginDetail = ($pluginOutput | Out-String).Trim()
                        if ($pluginDetail) {
                            Write-Warn "  $pluginDetail"
                        }
                        $script:PluginInstallCancelled = $true
                        break
                    } else {
                        Write-Warn "Could not install wiqd plugin for $pluginHost (exit code $pluginExitCode)"
                        $pluginDetail = ($pluginOutput | Out-String).Trim()
                        if ($pluginDetail) {
                            Write-Warn "  $pluginDetail"
                        }
                        Write-Hint "Run 'wiqd component plugin install --cli $pluginHost' to retry"
                        $script:PluginInstallFailed = $true
                        $script:FailedPluginHosts += $pluginHost
                    }
                } catch {
                    Write-Warn "Could not install wiqd plugin for ${pluginHost}: $_"
                    Write-Hint "Run 'wiqd component plugin install --cli $pluginHost' to retry"
                    $script:PluginInstallFailed = $true
                    $script:FailedPluginHosts += $pluginHost
                }
            }
        }
    } else {
        Write-Warn "Skipping plugin install — wiqd CLI not verified on PATH"
        Write-Hint "Restart your terminal and run: wiqd component plugin install"
    }
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

Write-Host ""
# The full-success banner requires BOTH the CLI-on-PATH probe AND a clean
# plugin step — a plugin failure must never be masked by "success" text, even
# though the CLI itself is fully usable (see the elseif branch below).
if ($installSuccess -and -not $script:PluginInstallFailed -and -not $script:PluginInstallCancelled) {
    Write-Host " ╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host " ║    ✓ wiqd installed successfully!    ║" -ForegroundColor Green
    Write-Host " ╚══════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""


    Write-WiqdQuickstart
} elseif ($installSuccess -and $script:PluginInstallCancelled) {
    Write-Host " ╔══════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host " ║ ⚠ wiqd installed — plugin cancelled  ║" -ForegroundColor Yellow
    Write-Host " ╚══════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""

    Write-Host " ⚠  wiqd plugin install was cancelled by the user." -ForegroundColor Yellow
    Write-Host ""

    Write-WiqdQuickstart
} elseif ($installSuccess -and $script:PluginInstallFailed) {
    # The wiqd CLI installed and is fully usable — a failed plugin step is a
    # partial, not a fatal, outcome. Say so honestly instead of the full-success
    # banner, and repeat the per-host retry hint here (in the FINAL summary),
    # not only at the point of failure a screen-full of output ago.
    Write-Host " ╔══════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host " ║ ⚠ wiqd installed — plugin incomplete ║" -ForegroundColor Yellow
    Write-Host " ╚══════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""

    Write-Host " ⚠  wiqd plugin install did not complete for:" -ForegroundColor Yellow
    foreach ($failedHost in $script:FailedPluginHosts) {
        Write-Host "   - $failedHost" -ForegroundColor White
        Write-Host "     Run 'wiqd component plugin install --cli $failedHost' to retry" -ForegroundColor Gray
    }
    Write-Host ""

    Write-WiqdQuickstart
} else {
    Write-Host " ╔══════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host " ║  ⚠  wiqd installed — restart shell   ║" -ForegroundColor Yellow
    Write-Host " ╚══════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Close and reopen your terminal, then run:" -ForegroundColor White
    Write-Host "   wiqd --version" -ForegroundColor Cyan
    if ($eulaChoice -eq 'accepted') {
        Write-Host ""
        Write-Host " Note: you accepted the EULA during install but wiqd is not yet on PATH." -ForegroundColor Gray
        Write-Host " After restarting, run: wiqd eula accept wiqd" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($script:PluginInstallCancelled) {
    return 130
}

# A partial install (CLI on PATH, plugin step attempted-and-failed) must exit
# non-zero so CI and scripted installs can detect and act on it, even though
# nothing here aborts the run early — the CLI install itself always completes
# and the summary above already gave the user the full retry story.
if ($script:PluginInstallFailed) {
    # Under -PluginNonFatal (wiqd update), the CLI itself already updated
    # successfully; a plugin refresh blocked by an in-use agent must not be
    # reported as a failed update. Signal the distinct "CLI ok, plugin
    # deferred" code so `wiqd update` can report success with a
    # close-your-agents warning. Bootstrap/CI omit the flag and keep exit 1
    # for partial-install detection.
    if ($PluginNonFatal) { return 75 }
    return 1
}

return 0
}

# Single terminal call site. Invoke-WiqdInstall returns the 0/1/2/130 result code instead
# of calling exit, because under the `iex "& { $(irm ...) }"` one-liner an `exit` inside the
# block terminates the caller's interactive session. Record the code in $global:LASTEXITCODE
# (observable by scripted/CI callers in the surviving shell) and only truly `exit` when this
# is a real on-disk invocation (pwsh -File / CI / wiqd update), where exit sets the child
# process code without touching any interactive host.
try {
    # PowerShell returns EVERYTHING left on the success pipeline, not just the `return N`
    # value. Any stray uncaptured output inside Invoke-WiqdInstall's body would make the
    # result an array and corrupt the exit code, so collect the pipeline and take the last
    # element — `return N` is terminal, so the 0/1/2/130 code is always last — then coerce.
    $__out = @(Invoke-WiqdInstall)
} catch {
    # An unexpected terminating error still must not skip the exit-code contract; map it to
    # the documented user/upstream-error code and surface the message.
    Write-Host $_.Exception.Message -ForegroundColor Red
    $__out = @(1)
}
$__wiqdInstallResult = 0
if ($__out.Count -gt 0) {
    $__last = $__out[-1]
    if ($__last -is [int]) { $__wiqdInstallResult = $__last }
    elseif ($__last -is [string] -and $__last -match '^\d+$') { $__wiqdInstallResult = [int]$__last }
}
$global:LASTEXITCODE = $__wiqdInstallResult
# `exit` in the `iex "& { $(irm ...) }"` one-liner terminates the caller's interactive host.
# Only call exit for a real on-disk invocation (pwsh -File / CI / wiqd update), detected by a
# populated $PSCommandPath; otherwise leave $LASTEXITCODE set and fall off the end.
if (-not [string]::IsNullOrEmpty($PSCommandPath)) { exit $__wiqdInstallResult }
