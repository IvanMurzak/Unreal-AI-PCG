#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Bumps the extension version in lock-step across every file that records it.

.DESCRIPTION
    Updates, atomically:
      - the .uplugin "VersionName"            (the single source of truth; the release CI gate)
      - GetExtensionVersion() in the module   (return TEXT("x.y.z");)
      - extension.json "version"              (the install-catalog manifest)

    The .uplugin "Version" integer (the UE build number) is left alone — UE convention is to
    increment it manually only when you need a monotonic integer; the semver lives in VersionName.

.PARAMETER NewVersion
    The new semver (e.g. "0.2.0").

.PARAMETER WhatIf
    Preview changes without writing them.

.EXAMPLE
    ./commands/bump-version.ps1 -NewVersion "0.2.0"
#>
param(
    [Parameter(Mandatory = $true)][string]$NewVersion,
    [switch]$WhatIf
)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

if ($NewVersion -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9\.\-]+)?$') {
    Write-Error "Invalid semantic version: '$NewVersion' (expected major.minor.patch)"; exit 1
}

function Get-OneFile([string]$Filter) {
    Get-ChildItem -Path $repoRoot -Recurse -Filter $Filter |
        Where-Object { $_.FullName -notmatch '[\\/](Binaries|Intermediate|Saved|node_modules)[\\/]' } |
        Select-Object -First 1
}

$targets = @()

$uplugin = Get-OneFile '*.uplugin'
if ($uplugin) {
    $targets += @{ Path = $uplugin.FullName; Pattern = '("VersionName":\s*")[^"]+(")'; Replace = "`${1}$NewVersion`${2}"; Desc = ".uplugin VersionName" }
}

$module = Get-ChildItem -Path $repoRoot -Recurse -Filter '*Module.cpp' |
    Where-Object { $_.FullName -notmatch '[\\/](Binaries|Intermediate|Saved)[\\/]' } | Select-Object -First 1
if ($module) {
    $targets += @{ Path = $module.FullName; Pattern = '(GetExtensionVersion\(\)\s*const\s*override\s*\{\s*return\s*TEXT\(")[^"]+("\);)'; Replace = "`${1}$NewVersion`${2}"; Desc = "GetExtensionVersion()" }
}

$extJson = Join-Path $repoRoot 'extension.json'
if (Test-Path $extJson) {
    $targets += @{ Path = $extJson; Pattern = '("version":\s*")[^"]+(")'; Replace = "`${1}$NewVersion`${2}"; Desc = "extension.json version" }
}

$current = $null
if ($uplugin) {
    $c = Get-Content $uplugin.FullName -Raw
    if ($c -match '"VersionName":\s*"([^"]+)"') { $current = $Matches[1] }
}
Write-Host "Current version: $current" -ForegroundColor White
Write-Host "New version:     $NewVersion" -ForegroundColor White
Write-Host ""

$changed = 0
foreach ($t in $targets) {
    $content = Get-Content $t.Path -Raw
    $new = [regex]::Replace($content, $t.Pattern, $t.Replace)
    if ($new -ne $content) {
        Write-Host "  $($t.Desc): updated" -ForegroundColor Green
        if (-not $WhatIf) { Set-Content -Path $t.Path -Value $new -NoNewline }
        $changed++
    }
    else {
        Write-Host "  $($t.Desc): no match (pattern not found)" -ForegroundColor Yellow
    }
}

if ($WhatIf) {
    Write-Host "`nPreview only — re-run without -WhatIf to apply ($changed file(s) would change)." -ForegroundColor Cyan
}
elseif ($changed -gt 0) {
    Write-Host "`nVersion bumped to $NewVersion across $changed file(s). Remember to commit." -ForegroundColor Cyan
}
else {
    Write-Host "`nNo files changed." -ForegroundColor Yellow
}
