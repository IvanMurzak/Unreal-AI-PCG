#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Prints the extension's current version (the single source of truth: the .uplugin VersionName).
#>
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

$uplugin = Get-ChildItem -Path $repoRoot -Recurse -Filter '*.uplugin' |
    Where-Object { $_.FullName -notmatch '[\\/](Binaries|Intermediate|Saved)[\\/]' } |
    Select-Object -First 1

if (-not $uplugin) { Write-Error "No .uplugin found under $repoRoot"; exit 1 }

$content = Get-Content $uplugin.FullName -Raw
if ($content -match '"VersionName":\s*"([^"]+)"') {
    Write-Output $Matches[1]
    exit 0
}
Write-Error "Could not find VersionName in $($uplugin.FullName)"
exit 1
