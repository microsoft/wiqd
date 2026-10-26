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
#   2. @microsoft/wiqd (npm global package — includes extension payloads)
#   3. Verify installation (`wiqd doctor` reconciles active managed Work IQ
#      and Eval generations; related commands retry if verification was incomplete)
#   4. Work IQ VS Code extension (optional)
#   5. wiqd plugin — installed only for the plugin host(s) already on PATH
#      (Copilot CLI and/or Claude Code). Never installs a host; skipped
#      gracefully when neither is present. Skip entirely with -SkipPlugin.
#
#
# -Force         Full reinstall, end-to-end. Bypasses every "already installed"
#                short-circuit:
#                  * Step 2 (wiqd CLI): reinstall even when the version matches.
#                                       Doctor separately reconciles
#                                       extension-managed Eval/Work IQ.
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
    [ValidateSet("latest", "preview", "dev", "alpha")]
    [string]$Channel,
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
$UpdateResultPath = [Environment]::GetEnvironmentVariable('WIQD_UPDATE_RESULT_PATH')
$script:InstallerVersionExplicit = $PSBoundParameters.ContainsKey('Version')
if ($Channel) {
    if ($script:InstallerVersionExplicit) { throw '-Channel and -Version cannot be combined.' }
    if ($Source -ne 'npm') { throw '-Channel requires -Source npm.' }
    $Version = $Channel.ToLowerInvariant()
    if ($Version -eq 'dev') { $Version = 'alpha' }
    $script:InstallerVersionExplicit = $true
}
$script:InstallerForceRequested = [bool]$Force

$script:InstallUrl = 'https://aka.ms/wiqd/install.ps1'

$MinNodeVersion = [version]"24.15.0"
$WiqdPackage = "@microsoft/wiqd"
$VSCodeExtensionId = "Microsoft.wiqd"

# The canonical public npm registry used only by explicit recovery paths and
# trusted copyable hints. Normal installer flows do not pin registry selection.
$script:PublicNpmRegistry = 'https://registry.npmjs.org/'

# Extra npm arguments appended to every global install. Empty by default, so a
# plain install honours whatever registry (corporate proxy, mirror) the machine
# is configured with. Declared here, in the shared area, so it is always an
# empty array in the 3P mirror where no setter ever runs.
$script:NpmRegistryArgs = @()

# The plugin step is a foreach over possibly-multiple hosts (copilot, claude),
# so "succeeded" (>=1 host installed cleanly) and "failed" (>=1 host errored)
# are tracked separately from $installSuccess. A host being ABSENT is a
# graceful skip, never a failure; only an attempted-and-errored install trips
# Failed/Succeeded/Skipped/Cancelled (+ FailedPluginHosts) drive the
# summary banners, the skills-list gate, and the final exit code.
$script:PluginInstallFailed = $false
$script:VSCodeInstallFailed = $false
$script:PluginInstallSucceeded = $false
$script:PluginNotices = @()
$script:PluginInstallSkipped = $false
$script:PluginInstallCancelled = $false
$script:FailedPluginHosts = @()


# Stamped by sync-version.ps1 — do not edit manually.
$script:WiqdVersion = "0.20.0"


# nvm4w ships npm.ps1 which uses $MyInvocation.InvocationName to parse args.
# When called via & inside another script, InvocationName mismatches the parsed
# command text, corrupting the first argument (e.g. "install" → "pm install").
# Resolve npm.cmd (bypasses the .ps1 wrapper) once and reuse everywhere.
$npmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npmCmd) { $npmCmd = Get-Command npm -ErrorAction SilentlyContinue }
$script:NpmExe = if ($npmCmd) { $npmCmd.Source } else { $null }
$script:LastNpmErrorCode = $null
$script:LastNpmRegistry = $null
$script:LastNpmMissingSpec = $null

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

    # The wrapped command's exit status is reported ONLY through the returned
    # object's ExitCode/Failed fields; a handled non-zero (e.g. an npm registry
    # probe for a version that legitimately does not exist) must never leak into
    # the caller's global $LASTEXITCODE. Otherwise a later bare `exit`, or a
    # GitHub Actions `pwsh` step that ends on this call, would inherit that stray
    # code and fail even though every assertion passed. Snapshot the pre-call
    # value and restore it, so Invoke-Native is transparent to $LASTEXITCODE.
    $entryLastExitCode = $global:LASTEXITCODE

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
        $global:LASTEXITCODE = $entryLastExitCode
    }
}

function Test-WiqdUpdaterProcess {
    param(
        [string]$Name,
        [string]$CommandLine
    )

    if ([System.IO.Path]::GetFileName($Name) -notmatch '^(?i:node(?:\.exe)?)$') { return $false }
    if ($CommandLine -notmatch '(?i:[\\/](?:bin[\\/]wiqd\.js|dist[\\/]wiqd-cli\.cjs)(?:"|''|\s|$))') {
        return $false
    }
    return $CommandLine -match '(?i)(?:^|\s)update(?:\s|$)'
}

function Get-WiqdAncestorProcesses {
    $ancestors = [System.Collections.Generic.List[object]]::new()
    if ($IsWindows) {
        try {
            $currentId = $PID
            for ($depth = 0; $depth -lt 4; $depth++) {
                $current = Get-CimInstance Win32_Process -Filter "ProcessId=$currentId" -ErrorAction Stop
                if (-not $current -or -not $current.ParentProcessId) { break }
                $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($current.ParentProcessId)" -ErrorAction Stop
                if (-not $parent) { break }
                $ancestors.Add([pscustomobject]@{
                    Name = [string]$parent.Name
                    CommandLine = [string]$parent.CommandLine
                })
                $currentId = [int]$parent.ProcessId
            }
        } catch {
            return @()
        }
        return $ancestors.ToArray()
    }

    $currentId = $PID
    for ($depth = 0; $depth -lt 4; $depth++) {
        $parentResult = Invoke-Native { & ps -o ppid= -p $currentId }
        if ($parentResult.Failed) { break }
        $parentText = ($parentResult.StdOut -join '').Trim()
        $parentId = 0
        if (-not [int]::TryParse($parentText, [ref]$parentId) -or $parentId -le 0) { break }
        $nameResult = Invoke-Native { & ps -o comm= -p $parentId }
        $commandResult = Invoke-Native { & ps -o command= -p $parentId }
        if ($nameResult.Failed -or $commandResult.Failed) { break }
        $ancestors.Add([pscustomobject]@{
            Name = ($nameResult.StdOut -join '').Trim()
            CommandLine = ($commandResult.StdOut -join ' ').Trim()
        })
        $currentId = $parentId
    }
    return $ancestors.ToArray()
}

function Test-LegacyWiqdUpdaterInvocation {
    param(
        [bool]$ForceRequested = $script:InstallerForceRequested,
        [bool]$VersionWasExplicit = $script:InstallerVersionExplicit,
        [string]$ResultPath = $UpdateResultPath,
        [object[]]$Ancestors
    )

    if (-not $ForceRequested -or -not $VersionWasExplicit -or -not [string]::IsNullOrEmpty($ResultPath)) {
        return $false
    }
    if ($null -eq $Ancestors) { $Ancestors = @(Get-WiqdAncestorProcesses) }
    return @($Ancestors | Where-Object {
        Test-WiqdUpdaterProcess -Name ([string]$_.Name) -CommandLine ([string]$_.CommandLine)
    }).Count -gt 0
}

# native-plugin:start
function Get-WiqdPluginHostPath {
    param([string]$Cli)
    $override = [Environment]::GetEnvironmentVariable("$($Cli.ToUpperInvariant())_PATH")
    if ($override) { return $override }
    $command = Get-Command $Cli -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    return $null
}

function Invoke-WiqdPluginHost {
    param([string]$Cli, [string[]]$Arguments)
    $binary = Get-WiqdPluginHostPath $Cli
    if (-not $binary) { throw "$Cli is unavailable. Install the native host, then rerun the installer." }
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $binary
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $start.Arguments = $quoted
    if ([IO.Path]::GetExtension($binary) -in @('.cmd', '.bat')) {
        if ($binary -match '["%&|<>^!\r\n]') { throw 'Unsafe native host launcher path.' }
        $start.FileName = $env:ComSpec
        $start.Arguments = '/d /s /c ""' + $binary + '" ' + $quoted + '"'
    }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.Encoding]::UTF8
    $start.StandardErrorEncoding = [Text.Encoding]::UTF8
    $start.EnvironmentVariables['CI'] = 'true'
    $timeout = 60000
    $configured = [Environment]::GetEnvironmentVariable("WIQD_$($Cli.ToUpperInvariant())_TIMEOUT")
    if ($configured -and ((-not [int]::TryParse($configured, [ref]$timeout)) -or $timeout -le 0)) {
        throw "Invalid WIQD_$($Cli.ToUpperInvariant())_TIMEOUT. Use a positive number of milliseconds."
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    try {
        $started = $process.Start()
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(100)) {
            if ($timer.ElapsedMilliseconds -ge $timeout) {
                $failure = [TimeoutException]::new("Plugin setup failed:`n  $Cli $($Arguments -join ' ')`nError: $Cli timed out.`nLet other plugin operations finish, then rerun this installer.")
                $failure.Data['TimedOut'] = $true
                throw $failure
            }
        }
        $code = $process.ExitCode
        if ($code -in @(130, -1073741510)) { $code = 130 }
        return [pscustomobject]@{ ExitCode = $code; StdOut = $stdout.GetAwaiter().GetResult(); StdErr = $stderr.GetAwaiter().GetResult(); Command = "$Cli $($Arguments -join ' ')" }
    } finally {
        if ($started -and -not $process.HasExited) {
            if ($PSVersionTable.PSVersion.Major -ge 7) { $process.Kill($true) }
            else { Invoke-Native { & taskkill /PID $process.Id /T /F } | Out-Null }
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}

function Assert-WiqdPluginHostSuccess {
    param($Result, [string]$InventoryCli)
    if ($Result.ExitCode -ne 0) {
        $message = "Plugin setup failed:`n  $($Result.Command)`nError (exit $($Result.ExitCode)): $($Result.StdErr.Trim())`n$($Result.StdOut.Trim())"
        if ($Result.ExitCode -eq 130) { $message = "Plugin setup cancelled:`n  $($Result.Command)" }
        else {
            if ($InventoryCli) { $message += "`nCannot read $InventoryCli inventory. Inspect the native command output before retrying." }
            $message += "`nResolve the reported error, then rerun this installer."
        }
        $failure = [InvalidOperationException]::new($message)
        $failure.Data['ExitCode'] = if ($Result.ExitCode -eq 130) { 130 } else { 1 }
        $failure.Data['TimedOut'] = $Result.ExitCode -eq 124
        throw $failure
    }
}

function ConvertFrom-WiqdMarketplaceList {
    param([string]$Cli, [string]$Text)
    $Text = $Text.TrimStart([char]0xFEFF)
    if ($Text.Trim() -notmatch '^\[') { throw 'Expected JSON marketplace array.' }
    $entries = @($Text | ConvertFrom-Json -ErrorAction Stop)
    foreach ($entry in $entries) {
        if ($entry -isnot [pscustomobject] -or $entry.name -isnot [string] -or -not $entry.name.Trim() -or $entry.name -match '[\s@]') { throw 'Invalid JSON marketplace entry.' }
        if ($Cli -eq 'copilot') {
            if ($entry.source -isnot [string] -or -not $entry.source.Trim()) { throw 'Invalid Copilot JSON marketplace entry.' }
            if ($entry.source -cmatch '^([^:\s]+): (.*)$') { $kind = $Matches[1]; $source = $Matches[2] }
            else { $kind = 'Unknown'; $source = $entry.source }
        } elseif ($Cli -eq 'claude') {
            switch -CaseSensitive ($entry.source) {
                'github' { $kind = 'GitHub'; $source = $entry.repo }
                'directory' { $kind = 'Directory'; $source = $entry.path }
                'url' { $kind = 'URL'; $source = $entry.url }
                default {
                    if ($entry.source -isnot [string] -or -not $entry.source.Trim()) { throw 'Invalid Claude JSON marketplace source.' }
                    $values = @('repo', 'path', 'url' | ForEach-Object { if ($entry.PSObject.Properties[$_]) { $entry.$_ } })
                    if ($values.Count -ne 1) { throw 'Unreadable Claude JSON marketplace source.' }
                    $kind = $entry.source; $source = $values[0]
                }
            }
        } else { throw 'Unknown inventory host.' }
        if ($source -isnot [string] -or -not $source.Trim() -or $source -match '[\r\n\x00]') { throw 'Invalid JSON marketplace source.' }
        [pscustomobject]@{ name = $entry.name; kind = $kind; source = $source }
    }
}

function ConvertFrom-WiqdNativePluginList {
    param([string]$Cli, [string]$Text)
    $Text = $Text.TrimStart([char]0xFEFF)
    if ($Text.Trim() -notmatch '^\[') { throw "Expected $Cli JSON plugin array." }
    $entries = @($Text | ConvertFrom-Json -ErrorAction Stop)
    foreach ($entry in $entries) {
        if ($entry -isnot [pscustomobject] -or $entry.version -isnot [string] -or -not $entry.version.Trim()) { throw "Invalid $Cli JSON plugin inventory." }
        if ($Cli -eq 'claude') {
            if ($entry.id -isnot [string] -or -not $entry.id.Trim() -or ($entry.PSObject.Properties['scope'] -and $entry.scope -isnot [string]) -or ($entry.PSObject.Properties['enabled'] -and $entry.enabled -isnot [bool])) { throw 'Invalid Claude JSON plugin inventory.' }
            $entry
        } elseif ($Cli -eq 'copilot') {
            if ($entry.name -isnot [string] -or -not $entry.name.Trim() -or $entry.name -match '[\s@]' -or $entry.marketplace -isnot [string] -or $entry.marketplace -match '[\s@]' -or $entry.enabled -isnot [bool] -or @('installed', 'live', 'builtin', 'external') -cnotcontains $entry.source) { throw 'Invalid Copilot JSON plugin inventory.' }
            $id = $entry.name
            if ($entry.marketplace) { $id += '@' + $entry.marketplace }
            [pscustomobject]@{ id = $id; version = $entry.version; localMarketplace = $entry.source -ceq 'live'; enabled = $entry.enabled; nativeSource = $entry.source }
        } else { throw 'Unknown inventory host.' }
    }
}

function Test-WiqdUnsupportedClaudePluginList {
    param($Result)
    $pattern = '\A(?:error:\s*)?unknown (?:command [''"]list[''"]|option [''"]--json[''"])\s*\z'
    return $Result.ExitCode -eq 1 -and -not $Result.StdOut -and $Result.StdErr.Trim() -match $pattern
}

function ConvertFrom-WiqdLegacyInventory {
    param([string]$Cli, [string]$Text, [switch]$Marketplaces, [switch]$AllowNoMatch)
    if ($Marketplaces) { ConvertFrom-WiqdMarketplacePresence $Text; return }
    $text = $Text.TrimStart([char]0xFEFF) -replace '\x1b\[[0-9;]*m', ''
    $lines = @($text -split '\r?\n' | Where-Object { $_.Trim() })
    if (-not $lines.Count -and -not $AllowNoMatch) { throw 'Blank legacy inventory.' }
    $entries = @()
    $current = $null
    foreach ($line in $lines) {
        $entry = $line.Trim() -replace '^[•·❯*>-]\s+', ''
        if ($entry -cmatch '^([A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+|wiqd)(?=\s|$)') {
            $current = [pscustomobject]@{ id = $Matches[1]; inventorySource = 'text-presence' }
            $entries += $current
        } elseif ($entry -match '@wiqd(?=$|[^A-Za-z0-9_.-])') {
            throw 'Ambiguous marketplace consumer in text inventory.'
        } elseif ($Cli -eq 'claude' -and $current -and $entry -match '^Scope\s*:\s*(\S+)\s*$') {
            if ($current.scope -and $current.scope -cne $Matches[1]) { throw 'Conflicting Claude plugin scopes in text inventory.' }
            $current | Add-Member -NotePropertyName scope -NotePropertyValue $Matches[1] -Force
        } elseif ($Cli -ne 'claude' -or -not $current -or $line -notmatch '^\s+\S[^:]*:\s*.*$') {
            $current = $null
        }
    }
    if (-not $entries.Count -and ($AllowNoMatch -or $text.Trim() -match '^No plugins installed\.?$')) { return }
    if (-not $entries.Count) { throw 'No plugin identities found in text inventory.' }
    $entries
}

function ConvertFrom-WiqdMarketplacePresence {
    param([string]$Text)
    $text = $Text.TrimStart([char]0xFEFF) -replace '\x1b\[[0-9;]*m', ''
    $entries = @()
    $pending = ''
    foreach ($line in ($text -split '\r?\n')) {
        $entry = $line.Trim() -replace '^[•·❯*>-]\s+', ''
        if ($entry -match '^([A-Za-z0-9_.-]+)\s+\(Local:\s*(.+)\)$') {
            $entries += [pscustomobject]@{ name = $Matches[1]; kind = 'Local'; source = $Matches[2]; inventorySource = 'text-local' }
            $pending = ''
        } elseif ($entry -match '^([A-Za-z0-9_.-]+)$') {
            $pending = $Matches[1]
        } elseif ($pending -and $entry -match '^Source\s*:\s*Directory\s*\((.+)\)$') {
            $entries += [pscustomobject]@{ name = $pending; kind = 'Directory'; source = $Matches[1]; inventorySource = 'text-local' }
            $pending = ''
        } elseif ($entry) { $pending = '' }
    }
    if (@($entries | Where-Object { $_.source -match '[\x00-\x1f]' }).Count) { throw 'Invalid local marketplace source.' }
    foreach ($source in @('microsoft/wiqd', 'github/awesome-copilot')) {
        $pattern = '(?<![A-Za-z0-9_./:@\\+-])(?:(?:git\+)?https?://github\.com/|git@github\.com:)?' + [regex]::Escape($source) + '(?:\.git)?/?(?=$|[\s''"()<>,;])'
        if ($text -match $pattern) {
            $name = if ($source -eq 'microsoft/wiqd') { 'wiqd' } else { 'awesome-copilot' }
            $entries += [pscustomobject]@{ name = $name; kind = 'GitHub'; source = $source; inventorySource = 'text-presence' }
        }
    }
    if (-not $entries.Count -and $text.Trim() -match '^No marketplaces configured\.?$') { return }
    if (-not $entries.Count) { throw 'No known WIQD marketplace repository found in text inventory.' }
    $entries
}

function Get-WiqdNativeMarketplaceList {
    param([string]$Cli)
    $diagnostics = @()
    try {
        $result = Invoke-WiqdPluginHost $Cli @('plugin', 'marketplace', 'list', '--json')
        if ($result.ExitCode -ne 0 -and $result.ExitCode -notin @(124, 130)) {
            $diagnostics += "JSON inventory failed: $($result.Command) (exit $($result.ExitCode))`n$($result.StdErr.Trim())`n$($result.StdOut.Trim())"
            $result = Invoke-WiqdPluginHost $Cli @('plugin', 'marketplace', 'list')
            Assert-WiqdPluginHostSuccess $result $Cli
            try { ConvertFrom-WiqdMarketplacePresence $result.StdOut }
            catch { throw "$($result.Command): $($_.Exception.Message)`n$($result.StdOut)`n$($result.StdErr)" }
            return
        }
        Assert-WiqdPluginHostSuccess $result $Cli
        try { ConvertFrom-WiqdMarketplaceList $Cli $result.StdOut } catch { throw "$($result.Command): $($_.Exception.Message)`n$($result.StdOut)`n$($result.StdErr)" }
    } catch {
        foreach ($diagnostic in $diagnostics) { [Console]::Error.WriteLine($diagnostic) }
        throw
    }
}

function Get-WiqdStoredCopilotPlugins {
    $configRoot = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' }
    $registry = Join-Path $configRoot 'config.json'
    try {
        $file = Get-Item -LiteralPath $registry -Force -ErrorAction Stop
        if ($file.PSIsContainer -or $file.Length -gt 1048576) { throw 'Invalid registry file.' }
        $data = Get-Content -LiteralPath $registry -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($data -isnot [pscustomobject] -or $data.installed_plugins -isnot [array]) { throw 'Missing installed_plugins array.' }
        $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $entries = @(
            foreach ($record in $data.installed_plugins) {
                if ($record -isnot [pscustomobject] -or $record.name -isnot [string] -or -not $record.name.Trim() -or $record.name -match '[\s@]' -or $record.marketplace -isnot [string] -or $record.marketplace -match '[\s@]' -or $record.enabled -isnot [bool]) { throw 'Invalid registry entry.' }
                $id = $record.name
                if ($record.marketplace) { $id += '@' + $record.marketplace }
                if (-not $ids.Add($id)) { throw 'Duplicate registry identity.' }
                $entry = [ordered]@{ id = $id; enabled = $record.enabled; inventorySource = 'config' }
                if ($record.PSObject.Properties['version']) {
                    if ($record.version -isnot [string] -or -not $record.version.Trim()) { throw 'Invalid registry version.' }
                    $entry.version = $record.version
                }
                [pscustomobject]$entry
            }
        )
    } catch {
        # JSON parser diagnostics can contain authentication state from this file.
        throw 'Plugin setup failed: Cannot read a valid Copilot installed_plugins array from config.json. Check the Copilot configuration, then retry, or use -SkipPlugin to install only the CLI.'
    }
    $entries
}

function Get-WiqdNativePluginList {
    param([string]$Cli, [switch]$RequireNative, [switch]$AllowNoMatch)
    $diagnostics = @()
    try {
        $result = Invoke-WiqdPluginHost $Cli @('plugin', 'list', '--json')
        $jsonResult = $result
        if ($result.ExitCode -ne 0 -and $result.ExitCode -notin @(124, 130)) {
            $diagnostics += "JSON inventory failed: $($result.Command) (exit $($result.ExitCode))`n$($result.StdErr.Trim())`n$($result.StdOut.Trim())"
            $result = Invoke-WiqdPluginHost $Cli @('plugin', 'list')
            if ($result.ExitCode -eq 0) {
                try { ConvertFrom-WiqdLegacyInventory $Cli $result.StdOut -AllowNoMatch:$AllowNoMatch } catch { throw "$($result.Command): $($_.Exception.Message)`n$($result.StdOut)`n$($result.StdErr)" }
                return
            }
            if ($result.ExitCode -in @(124, 130)) { Assert-WiqdPluginHostSuccess $result $Cli }
        }
        if ($Cli -eq 'claude') {
            if (Test-WiqdUnsupportedClaudePluginList $jsonResult) {
                $registry = Join-Path $HOME '.claude/plugins/installed_plugins.json'
                if (-not (Test-Path -LiteralPath $registry)) { return }
                try {
                    $data = Get-Content -LiteralPath $registry -Raw | ConvertFrom-Json
                    if (-not $data.plugins -or $data.plugins -is [array] -or $data.plugins -isnot [pscustomobject]) { throw 'Invalid Claude plugin registry.' }
                    foreach ($property in $data.plugins.PSObject.Properties) {
                        if ($property.Value -isnot [array] -or $property.Value.Count -eq 0) { throw 'Incomplete Claude plugin registry.' }
                        foreach ($entry in $property.Value) {
                            if ($entry.version -isnot [string] -or $entry.scope -isnot [string]) { throw 'Incomplete Claude plugin registry.' }
                            [pscustomobject]@{ id = $property.Name; version = $entry.version; scope = $entry.scope }
                        }
                    }
                } catch { throw "$($result.Command): $($_.Exception.Message)`n$($result.StdErr)" }
                return
            }
        }
        if ($Cli -eq 'copilot' -and $result.ExitCode -ne 0 -and $result.ExitCode -notin @(124, 130) -and -not $RequireNative) {
            $diagnostics += "Native inventory failed: $($result.Command) (exit $($result.ExitCode))`n$($result.StdErr.Trim())`n$($result.StdOut.Trim())"
            Get-WiqdStoredCopilotPlugins
            return
        }
        Assert-WiqdPluginHostSuccess $result $Cli
        try { ConvertFrom-WiqdNativePluginList $Cli $result.StdOut } catch { throw "$($result.Command): $($_.Exception.Message)`n$($result.StdOut)`n$($result.StdErr)" }
    } catch {
        foreach ($diagnostic in $diagnostics) { [Console]::Error.WriteLine($diagnostic) }
        throw
    }
}

function Test-WiqdPluginSourcePath {
    param([string]$Source, [string]$Expected)
    try {
        $comparison = if ([IO.Path]::DirectorySeparatorChar -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
        return [string]::Equals([IO.Path]::GetFullPath($Source).TrimEnd([IO.Path]::DirectorySeparatorChar), [IO.Path]::GetFullPath($Expected).TrimEnd([IO.Path]::DirectorySeparatorChar), $comparison)
    }
    catch { return $false }
}

function Test-WiqdPublicPluginSource {
    param([string]$Source, [string]$Repository)
    $normalized = $Source.Trim().Replace('\', '/') -replace '^git\+', '' -replace '^https?://github\.com/', '' -replace '^git@github\.com:', '' -replace '\.git/?$', '' -replace '/$', ''
    if ($Repository) { return $normalized -eq $Repository }
    return $normalized -in @('microsoft/wiqd', 'github/awesome-copilot')
}

function Get-WiqdPluginTarget {
    param([string]$Cli, [switch]$Canonical)
    if ($Cli -eq 'copilot' -and -not $Canonical) {
        return [pscustomobject]@{ marketplace = 'awesome-copilot'; repository = 'github/awesome-copilot'; id = 'wiqd@awesome-copilot' }
    }
    if ($Cli -in @('copilot', 'claude')) {
        return [pscustomobject]@{ marketplace = 'wiqd'; repository = 'microsoft/wiqd'; id = 'wiqd@wiqd' }
    }
    throw 'Unknown plugin host.'
}

function Test-WiqdOwnedPluginSource {
    param([string]$Source)
    if ($env:WIQD_MARKETPLACE_DIR) { return $false }
    $root = Join-Path $HOME '.wiqd/marketplace/wiqd'
    if (-not (Test-WiqdPluginSourcePath $Source $root)) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $false }
        foreach ($relative in @('.github/plugin/plugin.json', '.claude-plugin/plugin.json')) {
            $manifest = Join-Path $root $relative
            $current = $manifest
            while ($current) {
                $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $false }
                $parent = [IO.Path]::GetDirectoryName($current)
                if ($parent -eq $current) { break }
                $current = $parent
            }
            if ((Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).name -cne 'wiqd') { return $false }
        }
        return $true
    } catch { return $false }
}

function Test-WiqdPluginCache {
    param([string]$Cli)
    if ($Cli -eq 'copilot') {
        foreach ($marketplace in @('wiqd', 'awesome-copilot')) {
            if (Test-Path -LiteralPath (Join-Path $HOME ".copilot/installed-plugins/$marketplace/wiqd") -PathType Container) { return $true }
        }
        return $false
    }
    $cache = Join-Path $HOME '.claude/plugins/cache/wiqd/wiqd'
    return Test-Path -LiteralPath $cache -PathType Container
}

function Get-WiqdPluginInventory {
    param([switch]$AllowUnknown, [string]$InstallCli)
    $legacy = if ($env:WIQD_MARKETPLACE_DIR) { $env:WIQD_MARKETPLACE_DIR } else { Join-Path $HOME '.wiqd/marketplace/wiqd' }
    $hosts = if ($InstallCli) { @($InstallCli) } else { @('copilot', 'claude') }
    foreach ($cli in $hosts) {
        if (-not (Get-WiqdPluginHostPath $cli)) {
            if (Test-WiqdPluginCache $cli) { throw "$cli is unavailable but a WIQD plugin cache exists. Restore the host to inspect native plugin inventory before retrying." }
            continue
        }
        $readErrors = @()
        if (-not $AllowUnknown) { $markets = @(Get-WiqdNativeMarketplaceList $cli) }
        try { $plugins = @(Get-WiqdNativePluginList $cli -AllowNoMatch:($AllowUnknown -and $InstallCli -eq $cli)) } catch {
            if (-not $AllowUnknown -or $_.Exception.Data['ExitCode'] -eq 130 -or $_.Exception.Data['TimedOut']) { throw }
            $plugins = @(); $readErrors += $_.Exception.Message
        }
        if ($AllowUnknown -and $InstallCli -ceq $cli -and -not $readErrors.Count) {
            $wiqd = @($plugins | Where-Object { $_.id -ceq 'wiqd' -or $_.id -clike 'wiqd@*' })
            $legacyTarget = @($wiqd | Where-Object { $_.id -ceq 'wiqd@wiqd' })
            if ($legacyTarget.Count -eq 0) {
                $duplicate = @($wiqd | Where-Object { $_.id -ceq (Get-WiqdPluginTarget $cli).id }).Count -gt 1
                $publicError = if ($duplicate) { 'Requested WIQD plugin identity is duplicated.' } else { '' }
                $unknown = @($wiqd | Where-Object { $_.id -ceq 'wiqd' }).Count -gt 0
                $warnCoexistence = $cli -eq 'copilot' -and @($wiqd | Where-Object { $_.id -cne 'wiqd@awesome-copilot' }).Count -gt 0
                [pscustomobject]@{ cli = $cli; state = 'absent'; publicState = 'absent'; publicError = $publicError; destination = Get-WiqdPluginTarget $cli; canonical = $false; marketplaces = @(); plugins = $plugins; skipMarketplace = $cli -eq 'copilot'; inventoryUnknown = $unknown; warnCoexistence = $warnCoexistence }
                return
            }
        }
        if ($AllowUnknown) {
            try { $markets = @(Get-WiqdNativeMarketplaceList $cli) } catch {
                if ($_.Exception.Data['ExitCode'] -eq 130 -or $_.Exception.Data['TimedOut']) { throw }
                $markets = @(); $readErrors += $_.Exception.Message
            }
        }
        $destination = Get-WiqdPluginTarget $cli
        $wiqd = @($plugins | Where-Object { $_.id -ceq 'wiqd' -or $_.id -clike 'wiqd@*' })
        $legacyTarget = @($wiqd | Where-Object { $_.id -ceq 'wiqd@wiqd' })
        if ($readErrors.Count) {
            foreach ($message in $readErrors) { [Console]::Error.WriteLine($message) }
            $publicError = if ($cli -eq 'copilot' -and $legacyTarget.Count -gt 0) { 'Existing canonical Copilot WIQD deployment is not a unique enabled installed plugin with verified microsoft/wiqd provenance.' } else { '' }
            [pscustomobject]@{ cli = $cli; state = 'unknown'; publicState = 'unknown'; publicError = $publicError; destination = $destination; canonical = $false; marketplaces = $markets; plugins = $plugins; inventoryUnknown = $true }
            continue
        }
        $legacyBinding = @($markets | Where-Object { $_.name -ceq 'wiqd' })
        $canonical = $cli -ceq 'copilot' -and $wiqd.Count -eq 1 -and $legacyTarget.Count -eq 1 -and $legacyTarget[0].nativeSource -ceq 'installed' -and $legacyTarget[0].enabled -eq $true -and $legacyBinding.Count -eq 1 -and $legacyBinding[0].kind -ceq 'GitHub' -and (Test-WiqdPublicPluginSource $legacyBinding[0].source 'microsoft/wiqd')
        if ($canonical) { $destination = Get-WiqdPluginTarget $cli -Canonical }
        $relevant = @($markets | Where-Object { $_.name -ceq 'wiqd' -or $_.name -ceq $destination.marketplace -or @($wiqd | ForEach-Object { $_.id -replace '^wiqd@', '' }) -ccontains $_.name -or (Test-WiqdPublicPluginSource $_.source) -or (Test-WiqdPluginSourcePath $_.source $legacy) })
        $binding = @($markets | Where-Object { $_.name -ceq $destination.marketplace })
        $target = @($wiqd | Where-Object { $_.id -ceq $destination.id })
        $presenceOnly = @($markets | Where-Object { $_.inventorySource -ceq 'text-presence' }).Count -gt 0
        $local = @($relevant | Where-Object { $_.kind -in @('Local', 'Directory') -or (Test-WiqdPluginSourcePath $_.source $legacy) })
        $state = 'absent'
        $reason = ''
        $targetError = ''
        if ($binding.Count -gt 1 -or $target.Count -gt 1) { $targetError = 'Requested WIQD plugin or marketplace identity is duplicated.' }
        elseif ($binding.Count -eq 1) {
            if ($binding[0].kind -ceq 'GitHub' -and (Test-WiqdPublicPluginSource $binding[0].source $destination.repository)) { $state = 'selected' }
            else { $targetError = "marketplace '$($destination.marketplace)' points to $($binding[0].source | ConvertTo-Json -Compress)." }
        }
        if ($local.Count -gt 0) {
            $state = 'conflict'
            $reason = 'Local WIQD plugin ownership cannot be verified.'
            if ($local.Count -eq 1 -and $legacyBinding.Count -eq 1 -and $local[0].name -ceq 'wiqd' -and $local[0].kind -cin @('Local', 'Directory') -and $legacyTarget.Count -eq 1 -and (Test-WiqdOwnedPluginSource $local[0].source)) {
                if (@($plugins | Where-Object { $_.id -clike '*@wiqd' -and $_.id -cne 'wiqd@wiqd' }).Count -gt 0) { $reason = "Other plugins also use marketplace 'wiqd'." }
                elseif (@($plugins | Where-Object { $_.inventorySource -eq 'config' }).Count -gt 0) { $reason = 'Stored plugin inventory cannot verify all consumers; native inventory is required for local migration.' }
                else { $state = 'local'; if ($cli -eq 'claude') { $targetError = '' } }
            }
        }
        if (@($wiqd | Where-Object { $_.id -ceq 'wiqd' -or @($markets.name) -cnotcontains ($_.id -replace '^wiqd@', '') }).Count -gt 0) {
            $state = 'conflict'; $reason = 'WIQD plugin marketplace identity is missing or ambiguous.'
        }
        if ($cli -eq 'claude' -and @($target | Where-Object { $_.scope -cne 'user' }).Count -gt 0) {
            $targetError = 'Claude WIQD scope is not user or cannot be determined.'
            if ($state -eq 'local') { $state = 'conflict'; $reason = $targetError }
        }
        $publicState = $state
        $publicError = $targetError
        if ($cli -eq 'claude' -and $local.Count -eq 0 -and $target.Count -eq 1 -and $target[0].inventorySource -eq 'text-presence' -and -not $target[0].scope -and $binding.Count -eq 1 -and $binding[0].kind -ceq 'GitHub' -and (Test-WiqdPublicPluginSource $binding[0].source $destination.repository)) {
            $publicError = ''
        }
        if ($cli -eq 'copilot') {
            $publicError = ''
            if ($state -eq 'conflict' -and $local.Count -eq 1 -and $local[0].name -ceq $destination.marketplace) { $publicState = 'coexist' }
        }
        if ($legacyTarget.Count -gt 1) { $publicError = 'Existing canonical Copilot WIQD deployment is not a unique enabled installed plugin with verified microsoft/wiqd provenance. No plugin changes were made.' }
        elseif ($cli -eq 'claude' -and $legacyBinding.Count -gt 1) { $publicError = 'Requested WIQD plugin or marketplace identity is duplicated.' }
        $remote = $legacyBinding.Count -eq 1 -and $legacyBinding[0].kind -ceq 'GitHub' -and (Test-WiqdPublicPluginSource $legacyBinding[0].source 'microsoft/wiqd')
        if ($cli -eq 'copilot' -and ($legacyBinding.Count -gt 0 -or $legacyTarget.Count -gt 0) -and $state -ne 'local') {
            $publicState = 'coexist'
            if ($canonical) { $publicState = 'preserve' }
        } elseif ($cli -eq 'claude' -and $remote -and $legacyTarget.Count -eq 1 -and $legacyTarget[0].scope -ceq 'user' -and -not $publicError) { $publicState = 'preserve' }
        if ($cli -eq 'copilot' -and $legacyTarget.Count -gt 0 -and $state -ne 'local' -and -not $canonical -and -not $publicError) { $publicError = 'Existing canonical Copilot WIQD deployment is not a unique enabled installed plugin with verified microsoft/wiqd provenance. No plugin changes were made.' }
        $identityUnknown = @($wiqd | Where-Object { $_.id -ceq 'wiqd' -or ($_.id -cne 'wiqd@wiqd' -and @($markets.name) -cnotcontains ($_.id -replace '^wiqd@', '')) }).Count -gt 0
        if ($identityUnknown) { $publicState = 'conflict' }
        $inventoryUnknown = $false
        if ($AllowUnknown -and $identityUnknown -and -not $publicError) { $inventoryUnknown = $true }
        if ($wiqd.Count -gt 0 -and $presenceOnly -and $binding.Count -eq 0 -and $state -ne 'local' -and $publicState -notin @('preserve', 'conflict') -and -not $publicError) {
            if (-not $AllowUnknown) { throw "Cannot establish absence of the requested $cli marketplace from presence-only text inventory." }
            $inventoryUnknown = $true
        }
        $warnCoexistence = $publicState -eq 'coexist' -and -not ($cli -eq 'copilot' -and ($target.Count -eq 1 -or $remote))
        [pscustomobject]@{ cli = $cli; state = $state; publicState = $publicState; publicError = $publicError; warnCoexistence = $warnCoexistence; destination = $destination; canonical = $canonical; marketplaces = $markets; plugins = $plugins; reason = $reason; targetError = $targetError; inventoryUnknown = $inventoryUnknown }
    }
}

function Get-WiqdPluginRecovery {
    param($Current, [switch]$AfterUninstall)
    $cli = $Current.cli
    $destination = Get-WiqdPluginTarget $cli
    $legacy = if ($env:WIQD_MARKETPLACE_DIR) { $env:WIQD_MARKETPLACE_DIR } else { Join-Path $HOME '.wiqd/marketplace/wiqd' }
    $wiqd = @($Current.plugins | Where-Object { $_.id -ceq 'wiqd' -or $_.id -clike 'wiqd@*' })
    $markets = @($Current.marketplaces | Where-Object { $_.name -ceq 'wiqd' -or $_.name -ceq $destination.marketplace -or @($wiqd | ForEach-Object { $_.id -replace '^wiqd@', '' }) -ccontains $_.name -or (Test-WiqdPublicPluginSource $_.source) -or (Test-WiqdPluginSourcePath $_.source $legacy) })
    $plugins = @($Current.plugins | Where-Object { $_.id -ceq 'wiqd' -or $_.id -clike 'wiqd@*' -or @($markets.name) -ccontains ($_.id -replace '^.*@', '') })
    $lines = @()
    foreach ($market in $markets) { $lines += "Marketplace: $($market.name | ConvertTo-Json -Compress) ($($market.source | ConvertTo-Json -Compress))" }
    $lines += "Affected plugins: $(if ($plugins.Count) { (@($plugins | ForEach-Object { $_.id | ConvertTo-Json -Compress }) -join ', ') } else { 'none' })"
    $lines += 'Inspect the current setup:'
    $lines += "  $cli plugin list --json"
    $lines += "  $cli plugin marketplace list --json"
    $lines += 'Only the verified WIQD-owned local marketplace with WIQD as its sole plugin can be migrated.'
    $lines += 'Other plugins and marketplaces are preserved. Keep your local source files.'
    $lines += 'Resolve the reported ownership or binding issue, then retry; use -SkipPlugin to install only the CLI.'
    $lines -join "`n"
}

function Get-WiqdCanonicalPluginRefusal {
    param($Current)
    "Cannot install WIQD: Existing canonical Copilot WIQD deployment is not a unique enabled installed plugin with verified microsoft/wiqd provenance. No plugin changes were made. Existing state was not replaced.`n$(Get-WiqdPluginRecovery $Current)"
}

function Assert-WiqdPluginInventory {
    param([object[]]$Inventory, [bool]$Internal, [string]$Cli)
    foreach ($entry in $Inventory) {
        if (-not $Internal -and $entry.cli -ne $Cli) { continue }
        $state = if ($Internal) { $entry.state } else { $entry.publicState }
        $targetError = if ($Internal) { '' } else { $entry.publicError }
        if ($state -eq 'conflict' -or $targetError) {
            if (-not $Internal -and $entry.cli -eq 'copilot' -and @($entry.plugins | Where-Object { $_.id -ceq 'wiqd@wiqd' }).Count -gt 0) { throw (Get-WiqdCanonicalPluginRefusal $entry) }
            $destination = if ($entry.destination) { $entry.destination } else { Get-WiqdPluginTarget $entry.cli }
            if ($targetError) { throw "Cannot install WIQD: $targetError Expected $($destination.repository). Existing state was not replaced.`n$(Get-WiqdPluginRecovery $entry)" }
            throw "Cannot replace the existing WIQD plugin setup in $($entry.cli).`nReason: $($entry.reason)`n$(Get-WiqdPluginRecovery $entry)"
        }
    }
}

function Invoke-WiqdPluginMutation {
    param([string]$Cli, [string[]]$Arguments)
    for ($attempt = 0; $attempt -lt 3; $attempt += 1) {
        $result = Invoke-WiqdPluginHost $Cli $Arguments
        if ($result.ExitCode -in @(0, 124, 130) -or $result.StdErr -notmatch '(?i)EBUSY|EPERM|EACCES|being used by another process|resource busy|file.*locked') { break }
        if ($attempt -lt 2) { Start-Sleep -Milliseconds (200 * [Math]::Pow(2, $attempt)) }
    }
    Assert-WiqdPluginHostSuccess $result
}

function Move-WiqdLegacyPlugin {
    param($Current, [bool]$Internal, [ref]$MigrationStarted)
    $fresh = if ($Internal) { @(Get-WiqdPluginInventory) } else { @(Get-WiqdPluginInventory -InstallCli $Current.cli) }
    $changed = "Plugin configuration changed during setup ($($Current.cli)).`nThis migration stopped before uninstalling the old local WIQD plugin.`nLet other plugin operations finish, then rerun this installer."
    try { Assert-WiqdPluginInventory $fresh $Internal $Current.cli } catch { throw $changed }
    $rechecked = @($fresh | Where-Object { $_.cli -eq $Current.cli })
    if ($rechecked.Count -ne 1 -or $rechecked[0].state -ne 'local' -or (ConvertTo-Json -InputObject $rechecked[0] -Depth 20 -Compress) -cne (ConvertTo-Json -InputObject $Current -Depth 20 -Compress)) { throw $changed }
    [Console]::Error.WriteLine("Migrating the old local WIQD plugin 'wiqd@wiqd' in $($Current.cli)...")
    [Console]::Error.WriteLine("Uninstalling the old local plugin 'wiqd@wiqd'...")
    $MigrationStarted.Value = $true
    Invoke-WiqdPluginMutation $Current.cli @('plugin', 'uninstall', 'wiqd@wiqd')
    if ($Internal) {
        try {
            $remaining = @(Get-WiqdNativePluginList $Current.cli -RequireNative)
            $sources = @(Get-WiqdNativeMarketplaceList $Current.cli)
        } catch {
            if ($_.Exception.Data['ExitCode'] -eq 130) { throw }
            throw "Migration of the old local WIQD plugin 'wiqd@wiqd' stopped in $($Current.cli).`nCurrent plugin state: unknown.`n$($_.Exception.Message)`nThe installer has not removed the old marketplace.`nCheck the current setup:`n  $($Current.cli) plugin list --json`n  $($Current.cli) plugin marketplace list --json`nResolve the reported error, then rerun this installer."
        }
        $owned = @($Current.marketplaces | Where-Object { $_.name -ceq 'wiqd' })
        $consumers = @($remaining | Where-Object { $_.id -clike '*@wiqd' })
        $retainedLivePlugin = $Current.cli -ceq 'copilot' -and $consumers.Count -eq 1 -and $consumers[0].id -ceq 'wiqd@wiqd' -and $consumers[0].localMarketplace -eq $true -and $consumers[0].enabled -eq $false
        $reasons = @()
        if ($consumers.Count -gt 0 -and -not $retainedLivePlugin) { $reasons += "Plugins still reference marketplace 'wiqd'." }
        if ((ConvertTo-Json -InputObject $sources -Depth 20 -Compress) -cne (ConvertTo-Json -InputObject $Current.marketplaces -Depth 20 -Compress)) { $reasons += 'Marketplace registrations changed during setup.' }
        if (-not (Test-WiqdOwnedPluginSource $owned[0].source)) { $reasons += 'The old local source can no longer be verified as WIQD-owned.' }
        if ($reasons.Count) {
            $targets = @($remaining | Where-Object { $_.id -ceq 'wiqd@wiqd' })
            $state = if ($targets.Count -eq 0) { 'uninstalled' } elseif ($targets.Count -eq 1 -and $targets[0].enabled -eq $false) { 'disabled' } else { 'still installed' }
            $currentState = [pscustomobject]@{ cli = $Current.cli; plugins = $remaining; marketplaces = $sources }
            throw "Migration of the old local WIQD plugin 'wiqd@wiqd' stopped in $($Current.cli).`nCurrent plugin state: $state.`nReason: $($reasons -join ' ')`nThe installer has not removed the old marketplace.`n$(Get-WiqdPluginRecovery $currentState -AfterUninstall)"
        }
    }
    [Console]::Error.WriteLine("Removing the old local marketplace 'wiqd' in $($Current.cli)...")
    $result = Invoke-WiqdPluginHost $Current.cli @('plugin', 'marketplace', 'remove', 'wiqd')
    Assert-WiqdPluginHostSuccess $result
}

function Invoke-WiqdPublicInventoryFallback {
    param([string]$Cli, $Current)
    $destination = Get-WiqdPluginTarget $Cli
    $warning = 'Warning: Could not inspect existing WIQD plugins. Legacy migration was skipped. Attempting installation from the selected marketplace; duplicate active plugins may exist. Inspect host plugin settings before use.'
    if ($Cli -eq 'claude' -and $Current -and -not $Current.inventoryUnknown) {
        $warning = 'Warning: Existing Claude WIQD setup was not migrated. Attempting native marketplace registration from microsoft/wiqd and plugin installation. If a command fails, fix the reported cause and rerun this installer.'
    }
    if ($Cli -eq 'copilot' -and $Current -and @($Current.plugins | Where-Object { $_.id -ceq 'wiqd@wiqd' }).Count -gt 0) {
        throw (Get-WiqdCanonicalPluginRefusal $Current)
    }
    $targets = @($Current.plugins | Where-Object { $_.id -ceq $destination.id })
    if ($targets.Count -gt 1) { throw 'Requested WIQD plugin identity is duplicated.' }
    if ($Cli -eq 'claude' -and @($targets | Where-Object { $_.scope -and $_.scope -cne 'user' }).Count -gt 0) { throw 'Claude WIQD scope is not user. Existing state was not replaced.' }
    [Console]::Error.WriteLine($warning)
    if ($Cli -eq 'claude') { Invoke-WiqdPluginMutation $Cli @('plugin', 'marketplace', 'add', $destination.repository) }
    $verb = if ($Cli -eq 'copilot' -and $targets.Count -eq 1) { 'update' } else { 'install' }
    Invoke-WiqdPluginMutation $Cli @('plugin', $verb, $destination.id)
    $hostLabel = if ($Cli -eq 'copilot') { 'Copilot' } else { 'Claude' }
    $result = if ($verb -eq 'update') { 'updated' } else { 'installed' }
    [pscustomobject]@{ ExitCode = 0; Failed = $false; Combined = @("WIQD plugin $result (${Cli}): $($destination.id). Check $hostLabel plugin settings for duplicate WIQD plugins.", $warning) }
}

function Invoke-WiqdPluginHelper {
    param([string[]]$Arguments)
    $warnings = @()
    $allowMigrationSkip = $false
    $migrationStarted = $false
    try {
        if (-not $Arguments -or $Arguments.Count -eq 0) {
            return [pscustomobject]@{ ExitCode = 2; Failed = $true; Combined = @('Expected install [--cli copilot|claude], check, or migrate.') }
        }
        $operation = $Arguments[0]
        $cli = 'copilot'
        $allowMigrationSkip = $operation -cin @('check', 'migrate') -and $Arguments.Count -eq 2 -and $Arguments[1] -ceq '--allow-migration-skip'
        if ($operation -notin @('install', 'check', 'migrate') -or ($Arguments.Count -ne 1 -and -not $allowMigrationSkip -and -not ($operation -eq 'install' -and $Arguments.Count -eq 3 -and $Arguments[1] -ceq '--cli' -and $Arguments[2] -cin @('copilot', 'claude')))) {
            return [pscustomobject]@{ ExitCode = 2; Failed = $true; Combined = @('Expected install [--cli copilot|claude], check, or migrate.') }
        }
        if ($Arguments.Count -eq 3) { $cli = $Arguments[2] }
        if ($operation -eq 'install') {
            foreach ($probe in @(@('--version'), @('plugin', 'marketplace', '--help'))) {
                $result = Invoke-WiqdPluginHost $cli $probe
                Assert-WiqdPluginHostSuccess $result
            }
        }
        $installCli = if ($operation -eq 'install') { $cli } else { '' }
        try { $inventory = @(Get-WiqdPluginInventory -AllowUnknown:($operation -eq 'install') -InstallCli $installCli) } catch {
            if ($operation -ne 'install' -or $_.Exception.Data['ExitCode'] -eq 130 -or $_.Exception.Data['TimedOut']) { throw }
            [Console]::Error.WriteLine($_.Exception.Message)
            return Invoke-WiqdPublicInventoryFallback $cli
        }
        if ($operation -eq 'install') {
            $current = @($inventory | Where-Object { $_.cli -eq $cli }) | Select-Object -First 1
            $destination = if ($current.canonical) { Get-WiqdPluginTarget $cli -Canonical } else { Get-WiqdPluginTarget $cli }
            $selected = @($current.plugins | Where-Object { $_.id -ceq $destination.id })
            if ($selected.Count -gt 1) { throw 'Requested WIQD plugin identity is duplicated.' }
            if ($cli -eq 'claude' -and @($selected | Where-Object { $_.scope -and $_.scope -cne 'user' }).Count -gt 0) { throw 'Claude WIQD scope is not user. Existing state was not replaced.' }
            if ($current.inventoryUnknown) { return Invoke-WiqdPublicInventoryFallback $cli $current }
            if ($cli -eq 'claude' -and $selected.Count -eq 1 -and $current.state -ne 'local' -and $current.publicState -ne 'preserve' -and ($current.state -ne 'selected' -or $current.publicError)) {
                return Invoke-WiqdPublicInventoryFallback $cli $current
            }
        }
        $internal = $operation -ne 'install'
        Assert-WiqdPluginInventory $inventory $internal $cli
        $targets = @($inventory | Where-Object { $_.state -eq 'local' -and ($internal -or $_.cli -eq $cli) })
        foreach ($current in $targets) {
            $result = Invoke-WiqdPluginHost $current.cli @('plugin', 'marketplace', '--help')
            Assert-WiqdPluginHostSuccess $result
        }
        if ($operation -ne 'check') {
            foreach ($current in $targets) { Move-WiqdLegacyPlugin $current $internal ([ref]$migrationStarted) }
        }
        if ($operation -eq 'install') {
            $current = @($inventory | Where-Object { $_.cli -eq $cli }) | Select-Object -First 1
            $destination = if ($current.canonical) { Get-WiqdPluginTarget $cli -Canonical } else { Get-WiqdPluginTarget $cli }
            if ($current.publicState -eq 'preserve' -or ($cli -eq 'claude' -and $current.state -eq 'selected' -and -not $current.publicError -and @($current.plugins | Where-Object { $_.id -ceq 'wiqd@wiqd' }).Count -eq 1)) {
                if ($cli -eq 'copilot') {
                    [Console]::Error.WriteLine('Updating WIQD from microsoft/wiqd in copilot...')
                    Invoke-WiqdPluginMutation $cli @('plugin', 'update', 'wiqd@wiqd')
                    return [pscustomobject]@{ ExitCode = 0; Failed = $false; Combined = @('WIQD plugin ready (copilot): wiqd@wiqd from microsoft/wiqd.') }
                }
                [Console]::Error.WriteLine('Updating WIQD from microsoft/wiqd in claude...')
                Invoke-WiqdPluginMutation $cli @('plugin', 'update', 'wiqd@wiqd')
                return [pscustomobject]@{ ExitCode = 0; Failed = $false; Combined = @('WIQD plugin ready (claude): wiqd@wiqd from microsoft/wiqd.') }
            }
            $warnings = @()
            if ($targets.Count -eq 0 -and $cli -eq 'copilot' -and @($current.plugins | Where-Object { $_.id -ceq 'wiqd@wiqd' }).Count -eq 1 -and @($current.plugins | Where-Object { $_.id -ceq 'wiqd@awesome-copilot' }).Count -eq 1) {
                [Console]::Error.WriteLine('Warning: Both wiqd@wiqd and wiqd@awesome-copilot are installed in Copilot; duplicate active plugins may coexist. Check Copilot plugin settings.')
            } elseif ($current.warnCoexistence) {
                $warnings += "Warning: Other WIQD plugins in $cli are left untouched; duplicate active plugins may coexist. Inspect host plugin settings."
            }
            foreach ($warning in $warnings) { [Console]::Error.WriteLine($warning) }
            if ($cli -eq 'claude') {
                Invoke-WiqdPluginMutation $cli @('plugin', 'marketplace', 'add', $destination.repository)
            }
            $verb = if ($targets.Count -eq 0 -and @($current.plugins | Where-Object { $_.id -ceq $destination.id }).Count -gt 0) { 'update' } else { 'install' }
            $progress = if ($verb -eq 'update') { 'Updating' } else { 'Installing' }
            [Console]::Error.WriteLine("$progress WIQD from $($destination.repository) in ${cli}...")
            Invoke-WiqdPluginMutation $cli @('plugin', $verb, $destination.id)
            return [pscustomobject]@{ ExitCode = 0; Failed = $false; Combined = @("WIQD plugin ready ($cli): $($destination.id) from $($destination.repository).") + $warnings }
        }
        return [pscustomobject]@{ ExitCode = 0; Failed = $false; Combined = @(); Inventory = $inventory }
    } catch {
        $code = if ($_.Exception.Data['ExitCode'] -eq 130) { 130 } else { 1 }
        if ($allowMigrationSkip -and -not $migrationStarted -and $code -ne 130 -and -not $_.Exception.Data['TimedOut']) { $code = 3 }
        return [pscustomobject]@{ ExitCode = $code; Failed = $true; Combined = @($_.Exception.Message) + $warnings }
    }
}
# native-plugin:end


function Get-SafeRegistryLabel {
    param([string]$Registry)

    if ([string]::IsNullOrWhiteSpace($Registry)) { return "configured npm registry" }
    try {
        $uri = [uri]$Registry
        if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https') -or -not $uri.Host) {
            return "configured npm registry"
        }
        $port = if ($uri.IsDefaultPort) { "" } else { ":$($uri.Port)" }
        return "$($uri.Scheme)://$($uri.IdnHost)$port"
    } catch {
        return "configured npm registry"
    }
}

function Protect-NpmDiagnostic {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $safe = $Text -replace '(?i)(https?://)[^/@\s]+@', '$1'
    $safe = $safe -replace '(?i)([?&](?:access_token|token|auth|password|passwd|apikey|api_key)=)[^&\s]+', '$1[REDACTED]'
    $safe = $safe -replace "$([char]27)\[[0-9;?]*[ -/]*[@-~]", ''
    $safe = $safe -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
    if ($safe.Length -gt 8192) { return $safe.Substring($safe.Length - 8192) }
    return $safe
}

function Protect-InstallerDiagnostic {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $safe = $Text -replace '(?i)(https?://)[^/@\s]+@', '$1'
    $safe = $safe -replace '(?i)([?&](?:access_token|token|auth|password|passwd|apikey|api_key)=)[^&\s]+', '$1[REDACTED]'
    $safe = $safe -replace "$([char]27)\[[0-9;?]*[ -/]*[@-~]", ''
    $safe = $safe -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
    $safe = $safe -replace '(?i)\b(Authorization\s*[:=]\s*(?:Bearer|Basic)\s+)\S+', '$1<REDACTED>'
    $safe = $safe -replace '(?i)\b(access[_-]?token|token|auth|password|passwd|secret|apikey|api_key)\s*[:=]\s*(?:"[^"]*"|''[^'']*''|[^\s,;]+)', '$1=<REDACTED>'
    $safe = $safe -replace '(?i)\bhttps?://[^\s<>"'']+', '<URL>'
    $safe = $safe -replace '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b', '[EMAIL]'
    $safe = $safe -replace '\b[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\b', '[GUID]'
    $safe = $safe -replace '(?i)\b[A-Z]:\\(?:[^\\<>:"|?*\r\n\s]+\\?)+', '<PATH>'
    $safe = $safe -replace '(?<![:/\w])/(?:home|Users|root|var|tmp|etc)/[^\s:;"]+', '<PATH>'
    if ($safe.Length -gt 4096) { return "…" + $safe.Substring($safe.Length - 4095) }
    return $safe
}

function ConvertTo-SafePowerShellLiteral {
    param([string]$Value)

    # CR/LF is literal inside single quotes, but printing it would forge extra
    # recovery-log lines. Returning no command avoids changing the target path.
    if ($Value -match "[`r`n]") { return $null }

    $safe = $Value -replace "$([char]27)\][^$([char]7)]*(?:$([char]7)|$([char]27)\\)", ''
    $safe = $safe -replace "$([char]27)\[[0-9;?]*[ -/]*[@-~]", ''
    $safe = $safe -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
    return "'" + $safe.Replace("'", "''") + "'"
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
        [string]$DisplayName = "wiqd",
        [string]$Registry,
        [string]$RegistryScope,
        [switch]$SuppressFailureDiagnostics
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
    # Shared registry arguments are empty for normal installer flows. The
    # explicit parameters remain available for callers that deliberately need
    # to target a registry.
    $resolvedPackages = @(
        foreach ($packageSpec in $Packages) {
            if ($packageSpec -match '\.tgz$' -and (Test-Path -LiteralPath $packageSpec)) {
                (Resolve-Path -LiteralPath $packageSpec).Path
            } else {
                $packageSpec
            }
        }
    )
    $npmArgs = @("install", "-g") + $resolvedPackages + @($script:NpmRegistryArgs) + @("--loglevel=error")
    if ($Registry) {
        $npmArgs += @("--registry", $Registry)
        # A scoped package resolves through its `@scope:registry` config, which
        # takes precedence over the generic --registry flag. Pin the scope too,
        # otherwise the attempt silently resolves against the user's scoped
        # registry while we report (and record) the one we passed to --registry.
        if ($RegistryScope) {
            $npmArgs += @("--${RegistryScope}:registry=$Registry")
        }
    }

    $script:LastNpmErrorCode = $null
    $script:LastNpmRegistry = $Registry
    $script:LastNpmMissingSpec = $null
    $npmWorkingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("wiqd-npm-" + [Guid]::NewGuid().ToString("N"))
    $locationPushed = $false
    try {
        New-Item -ItemType Directory -Path $npmWorkingDirectory -Force | Out-Null
        Push-Location -LiteralPath $npmWorkingDirectory
        $locationPushed = $true
        $r = Invoke-Native { & $script:NpmExe @npmArgs }
    } finally {
        if ($locationPushed) { Pop-Location }
        Remove-Item -LiteralPath $npmWorkingDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    $npmOutput = $r.StdOut

    if ($r.ExitCode -ne 0) {
        # Capture the npm error code (e.g. E404) before any classification so the
        # auto-mode caller can offer an actionable registry-retry / recovery hint.
        $npmError = $r.StdErr -join "`n"
        if ($npmError -match '(?i)\bnpm\s+(?:error|ERR!)\s+code\s+(E[A-Z0-9]+)\b') {
            $script:LastNpmErrorCode = $Matches[1].ToUpperInvariant()
        }
        # npm has used both legacy and current wording for the unresolved spec.
        # Capture either form so dependency failures are not blamed on the root.
        if ($npmError -match "(?i)(?:404\s+)?(?:The requested resource\s+)?'([^']+)'(?:\s+is\s+not\s+in\s+this\s+registry|\s+could\s+not\s+be\s+found)") {
            $script:LastNpmMissingSpec = $Matches[1].Trim()
        }
        # Classify an EEXIST file conflict distinctly from a network/registry
        # failure (R35). npm aborts the whole global install with EEXIST when a
        # launcher target already exists but isn't owned by the installing
        # package — a purely LOCAL problem the GitHub fallback can't fix (it
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
        # GitHub fallback can't fix. Lead with the npm-recommended remedy
        # (point npm at a user-writable prefix), offer elevation as the
        # alternative, and stop. Change nothing. npm itself discourages
        # `sudo npm install -g`, so re-running as Administrator is the fallback,
        # not the headline.
        $hasPermissionCode = $combined -match '(?im)^\s*npm\s+(?:error|ERR!)\s+code\s+(?:EACCES|EPERM)\s*$'
        $hasFilesystemPath = $combined -match '(?im)^\s*npm\s+(?:error|ERR!)\s+path\s+.+$'
        if ($hasPermissionCode -and $hasFilesystemPath) {
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
        if ($SuppressFailureDiagnostics) {
            return $false
        }

        Write-Warn "npm install failed for $DisplayName"

        # A hidden DevUI server (this bug's historical root cause) can hold an
        # OS-level lock on files under its own install directory, which then
        # surfaces here as an opaque npm `EBUSY`/"resource busy or locked"
        # dump instead of a clear cause. Detect that specific shape and ADD
        # the fix to the raw npm error rather than replacing it: an EBUSY
        # anywhere else under the wiqd install (an editor, antivirus, a
        # running LSP) is a different problem, and swallowing npm's own output
        # would make it strictly harder to diagnose than before.
        $combinedOutput = ($r.Combined + $r.StdErr) -join "`n"
        $isDevUiLock = ($combinedOutput -match '(?i)EBUSY|resource busy or locked') -and
            ($combinedOutput -match '(?i)wiqd-ext-devui')

        if ($isDevUiLock) {
            Write-Hint "A running Work IQ DevUI process is using these files, so the install could not replace them."
            Write-Hint "Stop it first — press Ctrl+C in its console window, or run:  wiqd devui stop"
            Write-Hint "If neither works (a server started before this fix has no window and no stop support),"
            Write-Hint "end the 'node' process listening on port 7317 via Task Manager, or reboot."
            Write-Hint "Then re-run this install."
        }
        if ($r.StdErr.Count -gt 0) {
            Write-Hint (Protect-NpmDiagnostic ($r.StdErr -join ' '))
        }
        # Only the trusted public constant is safe to embed in a copyable command.
        $isPublicRegistry = $Registry -and $Registry.TrimEnd('/') -eq $script:PublicNpmRegistry.TrimEnd('/')
        $registryHint = if ($isPublicRegistry) { " --registry $script:PublicNpmRegistry" } else { "" }
        Write-Hint "Re-run 'npm install -g $($Packages -join ' ')$registryHint' to see the full npm error output."
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
# Severity is row-owned, NOT taken from doctor's status: a missing REQUIRED
# lifecycle backend is fatal and the caller must stop the install; a missing OPTIONAL dep
# (eval/workiq/EULA) degrades gracefully and only warns. Returns $true to
# continue, $false when a required dependency is missing (caller exits 1).
# Fails closed with the canonical reinstall hint when the probe is unavailable
# or its JSON can't be parsed because the required lifecycle backend cannot be verified.
function Show-DependencyStatus {
    # Ordered display rows. `Keys` maps onto the doctor check `name`s: the
    # healthy workiq probe is named "workiq --json", but a missing one collapses
    # to "workiq", so both names are accepted for the workiq row. Optional rows
    # use `ExtensionId` when doctor omits their check; emitted failures use
    # doctor's own trimmed message.
    $optionalRows = @(
        @{ Keys = @('runevals');                Label = 'runevals';    Required = $false; OkWord = 'Installed'; Note = '(optional - needed for `wiqd agent eval`)'; ExtensionId = 'microsoft.eval';   ReRun = $true; FirstUseCommand = 'wiqd agent eval'; OverrideEnv = 'M365_COPILOT_EVAL_PATH' }
        @{ Keys = @('workiq --json', 'workiq'); Label = 'workiq';      Required = $false; OkWord = 'Installed'; Note = '(optional - needed for `wiqd agent` commands)'; ExtensionId = 'microsoft.workiq'; ReRun = $true; FirstUseCommand = 'wiqd agent list'; OverrideEnv = 'WORKIQ_PATH' }
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

    $extensionsCheck = @($checks | Where-Object { [string]$_.name -eq 'Extensions' }) | Select-Object -First 1
    $coreActive = $false
    $coreInactive = $false
    if (($null -ne $extensionsCheck) -and ([string]$extensionsCheck.status -ne 'error') -and ([string]$extensionsCheck.message -match '(?:^|;\s*)\d+ active \(([^)]*)\)')) {
        $activeIds = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() })
        $coreActive = $activeIds -ccontains 'microsoft.wiqd.core'
    }
    if (($null -ne $extensionsCheck) -and ([string]$extensionsCheck.message -match '(?:^|;\s*)\d+ inactive \(([^)]*)\)')) {
        $inactiveIds = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() })
        $coreInactive = $inactiveIds -ccontains 'microsoft.wiqd.core'
    }
    if (-not $coreActive) {
        if ($coreInactive) {
            Write-Err "Lifecycle backend extension is inactive."
            Write-Hint "Re-run: wiqd ext add microsoft.wiqd.core"
            return $false
        }
        Write-Err "Could not determine the active lifecycle backend from wiqd doctor."
        Write-Hint "Run 'wiqd doctor' and ensure microsoft.wiqd.core is active."
        return $false
    }

    $backendRow = @{ Keys = @('Extensions'); Label = 'fx-core'; Required = $true; OkWord = 'Active'; Note = '(required for `wiqd agent` commands)'; ReRun = $true; ActiveExtensionId = 'microsoft.wiqd.core' }
    $rows = @($backendRow) + $optionalRows

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
        if ($row.ActiveExtensionId) {
            $activeIds = @()
            if (($null -ne $check) -and ([string]$check.status -ne 'error') -and ([string]$check.message -match '(?:^|;\s*)\d+ active \(([^)]*)\)')) {
                $activeIds = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() })
            }
            $isOk = $activeIds -ccontains $row.ActiveExtensionId
        } else {
            $isOk = ($null -ne $check) -and ([string]$check.status -eq 'ok')
        }
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
        $lead = if (($null -eq $item.Check) -and $row.ExtensionId) {
            "Extension check unavailable ($($row.ExtensionId) is inactive)."
        } elseif ($null -eq $item.Check) {
            "Required doctor check unavailable."
        } else {
            Get-ShortDoctorMessage $item.Check
        }
        Write-Host "   $icon $label $lead" -ForegroundColor $color
        if ($row.ReRun) {
            $repair = if (($null -ne $item.Check) -and $row.FirstUseCommand) {
                if ([string]$item.Check.status -eq 'error') {
                    switch ([string]$item.Check.remediation) {
                        'clear-managed-override' {
                            "clear or correct $($row.OverrideEnv), then run wiqd doctor"
                        }
                        'reinstall-host' {
                            'npm uninstall -g @microsoft/wiqd, then re-run this installer'
                        }
                        'managed-install-diagnostics' {
                            'wiqd doctor --verbose'
                        }
                        default {
                            'wiqd doctor'
                        }
                    }
                } else {
                    [string]$row.FirstUseCommand
                }
            } elseif (($null -eq $item.Check) -and $row.ExtensionId) {
                "wiqd ext add $($row.ExtensionId)"
            } else {
                'npm install -g @microsoft/wiqd'
            }
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

    $installed = Install-NpmGlobalPackages `
        -Packages @($packageSpec) `
        -DisplayName "$packageSpec from npm registry"
    if (-not $installed -and $script:LastNpmErrorCode -eq "E404") {
        if ($script:LastNpmMissingSpec -and $script:LastNpmMissingSpec -ne $packageSpec) {
            Write-Warn "A dependency ($script:LastNpmMissingSpec) of $packageSpec was not found using your npm configuration."
        } else {
            Write-Warn "$packageSpec was not found using your npm configuration."
        }
    }
    return $installed
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

    if ($Channel -or $Version -eq 'alpha') {
        if ($Source -notin @('npm', 'auto')) { throw 'Alpha/channel installation requires npm.' }
        $directory = Join-Path ([IO.Path]::GetTempPath()) ("wiqd-npm-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        try {
            Push-Location -LiteralPath $directory
            try {
                $result = Invoke-Native { & $script:NpmExe view "$Package@$Version" version --json --loglevel=error }
                if ($result.Failed) { throw "Unable to resolve npm channel '$Version'. Check your registry and retry." }
                $resolved = ($result.StdOut -join "`n") | ConvertFrom-Json
                if ($resolved -isnot [string] -or $resolved -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
                    throw "npm channel '$Version' did not resolve to one concrete version."
                }
                if ($Version -eq 'alpha' -and $resolved -notmatch '^\d+\.\d+\.\d+-alpha\.') {
                    throw "npm alpha channel points to non-alpha version '$resolved'."
                }
                return $resolved
            } finally { Pop-Location }
        } finally { Remove-Item -LiteralPath $directory -Recurse -Force }
    }
    # Explicit version or dist-tag requested — resolve it to a concrete version via
    # the registry (R30) so the up-to-date comparison never diffs a moving tag (e.g.
    # "preview") against an installed concrete version. Falls back to the literal
    # (leading 'v' stripped) if the registry can't be reached.
    if ($Version -and $Version -ne "latest") {
        if ($Source -in @("npm", "auto")) {
            try {
                $npmWorkingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("wiqd-npm-" + [Guid]::NewGuid().ToString("N"))
                $locationPushed = $false
                try {
                    New-Item -ItemType Directory -Path $npmWorkingDirectory -Force | Out-Null
                    Push-Location -LiteralPath $npmWorkingDirectory
                    $locationPushed = $true
                    $r = Invoke-Native { & $script:NpmExe view "$Package@$Version" version --loglevel=error }
                } finally {
                    if ($locationPushed) { Pop-Location }
                    Remove-Item -LiteralPath $npmWorkingDirectory -Recurse -Force
                }
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

        # Remove the .ps1 shim wiqd's own postinstall writes over npm's — an
        # unsigned .ps1 is refused under the Restricted and AllSigned execution
        # policies, and because PATHEXT already selected it PowerShell errors
        # outright rather than falling back to npm's .cmd. Any later
        # `npm install -g @microsoft/wiqd` re-creates it.
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

function Write-WiqdQuickstart {
    $copilotPresent = Test-CommandExists 'copilot'
    $claudePresent = Test-CommandExists 'claude'
    $pluginReady = $script:PluginInstallSucceeded -and -not $script:PluginInstallFailed -and -not $script:PluginInstallCancelled -and -not $script:PluginInstallSkipped
    Write-Host " Quick Start:" -ForegroundColor Cyan
    Write-Host "   wiqd plugin create --name my-plugin            Create a new plugin" -ForegroundColor White
    Write-Host "   cd my-plugin                                  Enter the plugin project" -ForegroundColor White
    Write-Host "   wiqd plugin validate                          Validate your plugin" -ForegroundColor White
    Write-Host "   wiqd plugin provision --env local              Provision to your tenant (local env)" -ForegroundColor White
    Write-Host ""
    foreach ($notice in $script:PluginNotices) { Write-Host $notice -ForegroundColor Yellow }
    if ($pluginReady -and ($copilotPresent -or $claudePresent)) {
        Write-Host " Start a new host session to use the WIQD plugin." -ForegroundColor Cyan
        if ($copilotPresent) {
            Write-Host " Or with Copilot CLI (interactive mode):" -ForegroundColor Cyan
            Write-Host "   copilot -i `"create a new standalone plugin`"" -ForegroundColor White
            Write-Host "   copilot -i `"validate my plugin`"" -ForegroundColor White
            Write-Host "   copilot -i `"provision my plugin in the local environment`"" -ForegroundColor White
            Write-Host ""
        } else {
            Write-Host " Open Claude Code to use the WIQD plugin." -ForegroundColor Cyan
            Write-Host ""
        }
    } elseif (-not $script:PluginInstallCancelled) {
        if (-not $copilotPresent -and -not $claudePresent) {
            Write-Host " First install Copilot CLI or Claude Code." -ForegroundColor Cyan
        }
        Write-Host " Manual plugin setup (choose the host needing setup):" -ForegroundColor Cyan
        Write-Host " Resolve any reported errors or source conflicts first." -ForegroundColor Yellow
        Write-Host " Copilot (Awesome Copilot):" -ForegroundColor Cyan
        Write-Host "   copilot plugin install wiqd@awesome-copilot" -ForegroundColor White
        Write-Host " Copilot alternative:" -ForegroundColor Cyan
        Write-Host "   copilot plugin marketplace add microsoft/wiqd" -ForegroundColor White
        Write-Host "   copilot plugin install wiqd@wiqd" -ForegroundColor White
        Write-Host " Claude Code:" -ForegroundColor Cyan
        Write-Host "   claude plugin marketplace add microsoft/wiqd" -ForegroundColor White
        Write-Host "   claude plugin install wiqd@wiqd" -ForegroundColor White
        Write-Host ""
    }
    Write-Host " Documentation:" -ForegroundColor Cyan
    Write-Host "   https://aka.ms/wiqd/docs" -ForegroundColor White
    Write-Host ""
}



function Save-WiqdInstallProvenance {
    param([string]$HomeDirectory = $HOME)

    $url = 'https://aka.ms/wiqd/install.ps1'
    $arguments = @()
    $temporaryPath = $null
    try {
        $directory = Join-Path $HomeDirectory '.wiqd'
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
        $temporaryPath = Join-Path $directory ('.install-method.' + [guid]::NewGuid().ToString('N') + '.tmp')
        $marker = @{
            version = 1
            method = 'bootstrap'
            vscodeEdition = if ($Insiders) { 'insiders' } else { 'stable' }
            installer = @{ url = $url; args = $arguments }
        }
        [System.IO.File]::WriteAllText($temporaryPath, ($marker | ConvertTo-Json -Depth 3), [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::Move($temporaryPath, (Join-Path $directory 'install-method.json'), $true)
        return $true
    } catch {
        Write-Err "Could not save install provenance. Re-run your intended installer: $_"
        return $false
    } finally {
        if ($temporaryPath -and [System.IO.File]::Exists($temporaryPath)) {
            [System.IO.File]::Delete($temporaryPath)
        }
    }
}

function Test-WiqdUpdateResultPath {
    param(
        [string]$Path = $UpdateResultPath,
        [string]$HomeDirectory = $HOME
    )

    if ([string]::IsNullOrEmpty($Path)) { return $false }
    try {
        $expectedDirectory = [System.IO.Path]::GetFullPath((Join-Path $HomeDirectory '.wiqd')).TrimEnd('\', '/')
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        if (-not [string]::Equals([System.IO.Path]::GetDirectoryName($fullPath).TrimEnd('\', '/'), $expectedDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
        if ([System.IO.Path]::GetFileName($fullPath) -notmatch '^\.update-result\.[0-9a-f]{32}\.json$') {
            return $false
        }
        return -not (Test-Path -LiteralPath $fullPath)
    } catch {
        return $false
    }
}

function Set-WiqdUpdateResult {
    param(
        [ValidateSet('success', 'failed', 'skipped', 'not-available')]
        [string]$Status,
        [ValidateSet('installed', 'already-installed', 'bundled-vsix-not-found', 'install-failed', 'requested', 'cli-not-found')]
        [string]$Reason,
        [string]$Path = $UpdateResultPath,
        [string]$HomeDirectory = $HOME
    )

    if (-not (Test-WiqdUpdateResultPath -Path $Path -HomeDirectory $HomeDirectory)) {
        Write-Err 'The wiqd update result path is invalid or untrusted.'
        return $false
    }
    try {
        $payload = @{
            version = 1
            extension = @{
                status = $Status
                edition = if ($Insiders) { 'insiders' } else { 'stable' }
                reason = $Reason
            }
        } | ConvertTo-Json -Depth 3 -Compress
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($payload)
            $stream.Write($bytes, 0, $bytes.Length)
        } finally {
            $stream.Dispose()
        }
        return $true
    } catch {
        Write-Err "Could not save the wiqd update result: $_"
        return $false
    }
}

# A real install is always EXECUTED (iex "& { $(irm …) }"), never dot-sourced —
# only this repo's test harness dot-sources this file to import its functions.
# Gate on BOTH the explicit opt-in AND dot-source context; an externally-set
# WIQD_INSTALLER_TEST_MODE on a real (executed) install is inert. No shippable
# sentinel value to discover or abuse.
if ($env:WIQD_INSTALLER_TEST_MODE -and $MyInvocation.InvocationName -eq '.') { return }

# The entire imperative install program is wrapped in a function that RETURNS
# its result code instead of calling `exit`. Under the canonical
# `iex "& { $(irm ...) }"` one-liner, the block runs inside the caller's
# interactive host — an `exit` anywhere in this body would terminate the
# user's whole PowerShell session instead of just this install run. The single
# terminal call site (at the very end of this file) is the only place that
# ever calls `exit`, and only when this is a real on-disk invocation.
function Invoke-WiqdInstall {
    if ($UpdateResultPath -and -not (Test-WiqdUpdateResultPath)) {
        Write-Err 'The wiqd update result path is invalid or untrusted.'
        return 1
    }


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
    $white   = Fg 243 244 246
    $dim     = Fg 110 116 130
    $bold    = "$e[1m"

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
    Write-Host "   ${purple}▸${reset} ${bold}${white}Work IQ Dev Tools${reset}  ${dim}v${script:WiqdVersion}$reset"
    Write-Host "     ${dim}github.com/microsoft/wiqd${reset}"
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
        if ($script:LastNpmErrorCode -eq "E404") {
            $safeLastRegistry = Get-SafeRegistryLabel $script:LastNpmRegistry
            $isPublicRegistry = $script:LastNpmRegistry -and $script:LastNpmRegistry.TrimEnd('/') -eq $script:PublicNpmRegistry.TrimEnd('/')
            if ($script:LastNpmMissingSpec -and $script:LastNpmMissingSpec -ne "$WiqdPackage@$targetVersion") {
                Write-Hint "A dependency ($script:LastNpmMissingSpec) was not found in $safeLastRegistry."
            } else {
                Write-Hint "$WiqdPackage@$targetVersion was not found in $safeLastRegistry."
            }
            if ($isPublicRegistry) {
                Write-Hint "After it is published, run 'npm install -g $WiqdPackage@$targetVersion --registry $script:PublicNpmRegistry'."
            } else {
                Write-Hint "After it becomes available, re-run this installer to use your configured registry."
            }
        } else {
            Write-Hint "Check your network connection and that npm can reach the registry, then re-run."
        }
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
# Eval and Work IQ are managed by their extension
# payloads and intentionally stay off PATH. Doctor reconciles active owners here;
# related commands retry the same lifecycle if this verification was incomplete.

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
    if ($r.ExitCode -eq 130) { return 130 }
    $wiqdCheck = if ($r.StdOut.Count -gt 0) { $r.StdOut[0] } else { $null }
    if ($r.ExitCode -eq 0 -and $wiqdCheck) {
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

# A missing REQUIRED dependency (the fx-core backend) is fatal: stop before the VS Code /
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

if (-not (Save-WiqdInstallProvenance)) {
    return 1
}

# ─────────────────────────────────────────────
# Step 4: VS Code Extension (optional)
# ─────────────────────────────────────────────

if (-not $SkipVSCode) {
    $stepNum = 4
    $vscodePartialFailure = $false

    $codeCmd = if ($Insiders) { "code-insiders" } else { "code" }
    $codeName = if ($Insiders) { "VS Code Insiders" } else { "VS Code" }

    Write-Step $stepNum $totalSteps "Installing $codeName extension..."

    if (Test-CommandExists $codeCmd) {
        $rootResult = Invoke-Native { & $script:NpmExe root -g --loglevel=error }
        $npmRoot = if ($rootResult -and -not $rootResult.Failed) {
            ($rootResult.StdOut -join "`n").Trim()
        } else {
            $null
        }
        $vsixPath = if ($npmRoot) {
            Join-Path $npmRoot (Join-Path $WiqdPackage 'vsix/wiqd.vsix')
        } else {
            $null
        }

        if (-not $vsixPath -or -not (Test-Path -LiteralPath $vsixPath -PathType Leaf)) {
            if ($UpdateResultPath) {
                if (-not (Set-WiqdUpdateResult -Status 'failed' -Reason 'bundled-vsix-not-found')) { return 1 }
            }
            $vscodePartialFailure = $true
            $script:VSCodeInstallFailed = $true
            Write-Warn "Could not find the bundled VS Code extension."
            Write-Warn "Setup warning: VS Code extension"
            $rootDiagnostic = Protect-InstallerDiagnostic ($rootResult.Combined -join "`n")
            if ($rootDiagnostic) {
                foreach ($line in ($rootDiagnostic -split "`r?`n")) {
                    Write-Warn "  $line"
                }
            }
            Write-Hint "Reinstall $WiqdPackage, then re-run this installer."
        } else {
            # Check if already installed (skip the short-circuit when -Force is
            # set so the bundled VSIX is re-applied).
            $listResult = Invoke-Native { & $codeCmd --list-extensions }
            if ($listResult.ExitCode -eq 130) { return 130 }
            $extensions = $listResult.StdOut
            if (($extensions -match $VSCodeExtensionId) -and -not $Force) {
                Write-Ok "Work IQ extension already installed in $codeName"
                if ($UpdateResultPath -and -not (Set-WiqdUpdateResult -Status 'success' -Reason 'already-installed')) { return 1 }
            } else {
                if (($extensions -match $VSCodeExtensionId) -and $Force) {
                    Write-Info "Reinstalling Work IQ extension in $codeName (-Force)..."
                }
                $installResult = Invoke-Native {
                    & $codeCmd --install-extension $vsixPath --force
                }
                if (-not $installResult.Failed) {
                    Write-Ok "Work IQ extension installed in $codeName"
                    if ($UpdateResultPath -and -not (Set-WiqdUpdateResult -Status 'success' -Reason 'installed')) { return 1 }
                } else {
                    if ($installResult.ExitCode -in @(130, -1073741510)) {
                        return 130
                    }
                    if ($UpdateResultPath) {
                        if (-not (Set-WiqdUpdateResult -Status 'failed' -Reason 'install-failed')) { return 1 }
                    }
                    $vscodePartialFailure = $true
                    $script:VSCodeInstallFailed = $true
                    Write-Warn "Could not install extension."
                    Write-Warn "Setup warning: VS Code extension"
                    $installDiagnostic = Protect-InstallerDiagnostic ($installResult.Combined -join "`n")
                    if ($installDiagnostic) {
                        foreach ($line in ($installDiagnostic -split "`r?`n")) {
                            Write-Warn "  $line"
                        }
                    }
                    $quotedVsixPath = ConvertTo-SafePowerShellLiteral $vsixPath
                    if ($null -eq $quotedVsixPath) {
                        Write-Hint "Manual install command unavailable because the bundled VSIX path contains a line break. Reinstall @microsoft/wiqd in a path without line breaks, then retry."
                    } else {
                        Write-Hint "Install manually: $codeCmd --install-extension $quotedVsixPath --force"
                    }
                }
            }
        }
    } else {
        Write-Warn "$codeName not found — skipping extension install"
        $script:VSCodeInstallFailed = $true
        Write-Warn "Setup warning: VS Code extension"
        Write-Hint "Install $codeName from https://code.visualstudio.com/"
        if ($UpdateResultPath -and -not (Set-WiqdUpdateResult -Status 'not-available' -Reason 'cli-not-found')) { return 1 }
    }
} elseif ($UpdateResultPath -and -not (Set-WiqdUpdateResult -Status 'skipped' -Reason 'requested')) {
    return 1
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
        # Detect which supported host(s) are already on PATH. The shared
        # The embedded installer helper inventories every
        # host, proves and migrates WIQD's legacy local marketplace, rejects
        # unsafe local state, and installs the selected remote profile.
        # Keeping that logic in one handler gives PowerShell, Bash, and update
        # identical safety checks. If neither host is present, skip gracefully.
        $pluginHosts = @()
        if (Test-CommandExists 'copilot') { $pluginHosts += 'copilot' }
        if (Test-CommandExists 'claude') { $pluginHosts += 'claude' }

        if ($pluginHosts.Count -eq 0) {
            Write-Info "No Copilot CLI or Claude Code detected — skipping plugin install."
            Write-Hint "Install one, then rerun this same WIQD installer."
        } else {
            foreach ($pluginHost in $pluginHosts) {
                try {
                    $pluginInstallArgs = @('install', '--cli', $pluginHost)
                        $pluginResult = Invoke-WiqdPluginHelper -Arguments $pluginInstallArgs
                    $pluginOutput = $pluginResult.Combined
                    $pluginExitCode = $pluginResult.ExitCode
                    $script:PluginNotices += @($pluginOutput | Where-Object { $_ -match 'duplicate active plugins may coexist' })
                    if ($pluginExitCode -eq 0) {
                        if (-not $pluginResult.Preserved) { Write-Ok "wiqd plugin setup completed for $pluginHost" }
                        $script:PluginInstallSucceeded = $true
                        $pluginDetail = ($pluginOutput | Out-String).Trim()
                        if ($pluginDetail) {
                            [Console]::Error.WriteLine($pluginDetail)
                        }
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
                        Write-Hint "Fix the reported cause, then rerun this same WIQD installer."
                        $script:PluginInstallFailed = $true
                        $script:FailedPluginHosts += $pluginHost
                    }
                } catch {
                    Write-Warn "Could not install wiqd plugin for ${pluginHost}: $_"
                    Write-Hint "Fix the reported cause, then rerun this same WIQD installer."
                    $script:PluginInstallFailed = $true
                    $script:FailedPluginHosts += $pluginHost
                }
            }
        }
    } else {
        Write-Warn "Skipping plugin install — wiqd CLI not verified on PATH"
        Write-Hint "Restart your terminal, then rerun this same WIQD installer."
    }
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

Write-Host ""
# The full-success banner requires BOTH the CLI-on-PATH probe AND a clean
# plugin step — a plugin failure must never be masked by "success" text, even
# though the CLI itself is fully usable (see the elseif branch below).
if ($installSuccess -and -not $script:PluginInstallFailed -and -not $script:PluginInstallCancelled -and -not $script:VSCodeInstallFailed) {
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

    Write-Host " WIQD CLI installed; plugin setup incomplete for: $($script:FailedPluginHosts -join ', ')." -ForegroundColor Yellow
    Write-Host " Follow the recovery steps above, then rerun this installer." -ForegroundColor Gray
    Write-Host ""

    Write-WiqdQuickstart
} elseif ($installSuccess -and $script:VSCodeInstallFailed) {
    Write-Warn "WIQD CLI installed; VS Code extension setup incomplete."
    Write-Hint "Follow the recovery steps above, then rerun this installer."
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

if (-not $installSuccess) {
    return 1
}
if ($script:PluginInstallFailed) {
    Write-Warn "Setup warning: plugin"
}
if ($script:PluginInstallFailed -or $script:VSCodeInstallFailed) {
    return 3
}

return 0
}

# Single terminal call site. Invoke-WiqdInstall returns its result code instead
# of calling exit, because under the `iex "& { $(irm ...) }"` one-liner an `exit` inside the
# block terminates the caller's interactive session. Record the code in $global:LASTEXITCODE
# (observable by scripted/CI callers in the surviving shell) and only truly `exit` when this
# is a real on-disk invocation (pwsh -File / CI / wiqd update), where exit sets the child
# process code without touching any interactive host.
try {
    # PowerShell returns EVERYTHING left on the success pipeline, not just the `return N`
    # value. Any stray uncaptured output inside Invoke-WiqdInstall's body would make the
    # result an array and corrupt the exit code, so collect the pipeline and take the last
    # element — `return N` is terminal, so the result code is always last — then coerce.
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
