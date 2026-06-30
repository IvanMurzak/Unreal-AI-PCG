#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tracks the Unreal-MCP core (the contract this extension builds against).

.DESCRIPTION
    Fetches the latest published Unreal-MCP version from GitHub releases (falling back to tags) and
    records it as `minCoreVersion` in extension.json — the compatibility floor the unreal-mcp-cli
    `install-extension` resolver reads to pick a build compatible with the user's installed core
    (design note 'Unreal extensions architecture' §5 compat contract).

    It does NOT pin a version inside the .uplugin: a UE plugin dependency `{ "Name": "UnrealMCP" }`
    carries no version, and the extension always compiles against whatever UnrealMCP is present.
    The recorded floor is advisory metadata for the install catalog, not a build-time pin.

.PARAMETER CoreRepository
    The core repo to query. Defaults to "IvanMurzak/Unreal-MCP".

.PARAMETER WhatIf
    Preview without writing.

.EXAMPLE
    ./commands/update-core.ps1
#>
param(
    [string]$CoreRepository = "IvanMurzak/Unreal-MCP",
    [switch]$WhatIf
)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$extJson = Join-Path $repoRoot 'extension.json'

if (-not (Test-Path $extJson)) { Write-Error "extension.json not found at $extJson"; exit 1 }

function Get-LatestCoreVersion([string]$Repo) {
    $headers = @{ "User-Agent" = "PowerShell"; "Accept" = "application/vnd.github+json" }
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers -TimeoutSec 30
        return ($rel.tag_name -replace '^v', '')
    }
    catch {
        Write-Host "  No published release; checking tags..." -ForegroundColor Gray
        $tags = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/tags" -Headers $headers -TimeoutSec 30
        if ($tags.Count -eq 0) { throw "No releases or tags found in $Repo" }
        return ($tags[0].name -replace '^v', '')
    }
}

Write-Host "Querying latest $CoreRepository version..." -ForegroundColor Cyan
$latest = Get-LatestCoreVersion $CoreRepository
Write-Host "  Latest core version: $latest" -ForegroundColor White

$content = Get-Content $extJson -Raw
if ($content -match '"minCoreVersion":\s*"([^"]+)"') {
    $current = $Matches[1]
    Write-Host "  Current minCoreVersion: $current" -ForegroundColor White
    if ($current -eq $latest) {
        Write-Host "Already up to date." -ForegroundColor Green
        exit 0
    }
}

$new = [regex]::Replace($content, '("minCoreVersion":\s*")[^"]+(")', "`${1}$latest`${2}")
if ($WhatIf) {
    Write-Host "Preview: would set minCoreVersion -> $latest (re-run without -WhatIf to apply)." -ForegroundColor Cyan
}
else {
    Set-Content -Path $extJson -Value $new -NoNewline
    Write-Host "Updated extension.json minCoreVersion -> $latest. Remember to commit." -ForegroundColor Green
}
