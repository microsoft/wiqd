# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#
# wiqd — Public feedback label provisioner
#
# Creates (or updates, via --force) the fixed set of labels that
# `wiqd feedback submit` applies to issues it creates. Safe to re-run: every
# label is created with --force, so an existing label is just updated in
# place rather than causing an error.
#
# Usage:
#   ./provision-labels.ps1                       # provisions microsoft/wiqd
#   ./provision-labels.ps1 -Repo owner/name       # provisions a different repo
#   ./provision-labels.ps1 -DryRun                # prints the plan, runs nothing
#
# Requires: gh (GitHub CLI), authenticated with repo-admin access to the
# target repo (`gh auth status`).

[CmdletBinding()]
param(
    [string]$Repo = 'microsoft/wiqd',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# PowerShell 7.3+ turns native-command stderr writes into a terminating
# NativeCommandError under $ErrorActionPreference = 'Stop'. Judge every gh
# call solely by its exit code (via Invoke-Native below), never by whether
# stderr produced output.
$PSNativeCommandUseErrorActionPreference = $false

function Write-Info { param($msg) Write-Host "  $msg" -ForegroundColor White }
function Write-Ok   { param($msg) Write-Host "  $msg" -ForegroundColor Green }
function Write-Err  { param($msg) Write-Host "  ERROR: $msg" -ForegroundColor Red }

# Wraps a native-command invocation so callers judge success by $LASTEXITCODE
# instead of being killed by PowerShell's NativeCommandError wrapper, and
# never by parsing/discarding stderr (no 2>$null anywhere in this script).
function Invoke-Native {
    param([Parameter(Mandatory)][scriptblock]$Command)

    $hadPrev = [bool](Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Local -ErrorAction SilentlyContinue)
    $prev = if ($hadPrev) { $PSNativeCommandUseErrorActionPreference } else { $null }
    $PSNativeCommandUseErrorActionPreference = $false

    try {
        $stdout = [System.Collections.Generic.List[string]]::new()
        $stderr = [System.Collections.Generic.List[string]]::new()

        & $Command 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $stderr.Add($_.Exception.Message)
            } elseif ($null -ne $_) {
                $stdout.Add($_.ToString())
            }
        }

        return [pscustomobject]@{
            StdOut   = $stdout.ToArray()
            StdErr   = $stderr.ToArray()
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

# The exact label set `wiqd feedback submit` passes to `gh issue create`
# (see packages/wiqd-ext-github/src/feedback-submit.ts). Keep this list in
# sync with that source if the CLI's label set ever changes.
$Labels = @(
    [pscustomobject]@{ Name = 'feedback';            Color = '006B75'; Description = 'Feedback submitted via wiqd feedback submit' }
    [pscustomobject]@{ Name = 'cli-submitted';        Color = '5319E7'; Description = 'Submitted automatically by the wiqd CLI' }
    [pscustomobject]@{ Name = 'bug';                  Color = 'D73A4A'; Description = 'Something is not working' }
    [pscustomobject]@{ Name = 'feature-request';      Color = '1D76DB'; Description = 'Request for a new feature or capability' }
    [pscustomobject]@{ Name = 'enhancement';          Color = 'A2EEEF'; Description = 'Improvement to existing functionality' }
    [pscustomobject]@{ Name = 'question';             Color = 'D876E3'; Description = 'Question about wiqd usage or behavior' }
    [pscustomobject]@{ Name = 'documentation';        Color = '0075CA'; Description = 'Improvement or correction to documentation' }
    [pscustomobject]@{ Name = 'performance';          Color = 'FBCA04'; Description = 'Performance or responsiveness issue' }
    [pscustomobject]@{ Name = 'sentiment:positive';   Color = '0E8A16'; Description = 'Positive sentiment reported with the feedback' }
    [pscustomobject]@{ Name = 'sentiment:negative';   Color = 'B60205'; Description = 'Negative sentiment reported with the feedback' }
)

Write-Host "`nwiqd feedback label provisioner" -ForegroundColor Cyan
Write-Info "Target repo: $Repo"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Err "GitHub CLI (gh) was not found on PATH. Install it from https://cli.github.com and re-run."
    exit 2
}

if ($DryRun) {
    Write-Info "Dry run: no changes will be made.`n"
    foreach ($label in $Labels) {
        Write-Info "  would create/update '$($label.Name)' (color #$($label.Color)): $($label.Description)"
    }
    exit 0
}

$authCheck = Invoke-Native { & gh auth status --hostname github.com }
if ($authCheck.Failed) {
    Write-Err "gh is not authenticated. Run 'gh auth login' first, then re-run this script."
    exit 1
}

$failureCount = 0
foreach ($label in $Labels) {
    $result = Invoke-Native {
        & gh label create $label.Name `
            --repo $Repo `
            --color $label.Color `
            --description $label.Description `
            --force
    }
    if ($result.Failed) {
        Write-Err "Failed to provision '$($label.Name)' (exit $($result.ExitCode)): $($result.StdErr -join ' ')"
        $failureCount = $failureCount + 1
    } else {
        Write-Ok "Provisioned '$($label.Name)'"
    }
}

if ($failureCount -gt 0) {
    Write-Err "$failureCount of $($Labels.Count) labels failed to provision."
    exit 1
}

Write-Host "`nAll $($Labels.Count) feedback labels are provisioned on $Repo.`n" -ForegroundColor Green
exit 0
