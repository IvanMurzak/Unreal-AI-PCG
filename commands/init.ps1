#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initializes a new Unreal-MCP extension from this template by replacing placeholders,
    renaming the plugin/module, optionally wiring a gating engine plugin, and activating CI.

.DESCRIPTION
    Replaces placeholders in file content and in file/folder names, then activates the
    `*.yml-sample` GitHub workflows. Placeholders:
      - YOUR_EXTENSION_MODULE            the UE plugin + C++ module name (PascalCase, NO hyphens)
      - YOUR_EXTENSION_ID                the GetExtensionId() string (e.g. com.company.unreal-ai-feature)
      - YOUR_EXTENSION_DISPLAY_NAME      the human-facing name (e.g. "Unreal AI Niagara")
      - YOUR_TOOL_ID                     the sample tool id (kebab-case; default "hello-extension")
      - YOUR_GITHUB_USERNAME_REPOSITORY  "Owner/Repo" (e.g. "IvanMurzak/Unreal-AI-Niagara")
      - YOUR_FEATURE_PLUGIN / YOUR_FEATURE_MODULE   the gating engine plugin/module (optional)

    UE module names CANNOT contain '-'. The *repository* is conventionally named
    `Unreal-AI-<Feature>` (with hyphens); the UE plugin/module is the hyphen-free PascalCase
    form, e.g. repo `Unreal-AI-Niagara` -> module `UnrealAINiagara`.

.PARAMETER ExtensionModule
    The UE plugin + module name (PascalCase, no hyphens). E.g. "UnrealAINiagara".

.PARAMETER ExtensionId
    The GetExtensionId() value. Lowercase dotted/kebab. E.g. "com.company.unreal-ai-niagara".

.PARAMETER DisplayName
    The human-facing display name. E.g. "Unreal AI Niagara".

.PARAMETER GitHubRepository
    "Owner/Repository". E.g. "IvanMurzak/Unreal-AI-Niagara".

.PARAMETER FeaturePlugin
    Optional. The gating engine plugin/module your tools wrap (e.g. "Niagara"). When supplied,
    it is added to the .uplugin "Plugins" array and the feature-module dependencies are
    uncommented in the *.Build.cs. Omit to wire it by hand later.

.PARAMETER ToolId
    Optional. The sample tool id (kebab-case). Defaults to "hello-extension".

.EXAMPLE
    ./commands/init.ps1 -ExtensionModule "UnrealAINiagara" -ExtensionId "com.company.unreal-ai-niagara" -DisplayName "Unreal AI Niagara" -GitHubRepository "IvanMurzak/Unreal-AI-Niagara" -FeaturePlugin "Niagara"
#>

param(
    [Parameter(Mandatory = $true)] [string]$ExtensionModule,
    [Parameter(Mandatory = $true)] [string]$ExtensionId,
    [Parameter(Mandatory = $true)] [string]$DisplayName,
    [Parameter(Mandatory = $true)] [string]$GitHubRepository,
    [Parameter(Mandatory = $false)][string]$FeaturePlugin,
    [Parameter(Mandatory = $false)][string]$ToolId = "hello-extension"
)

$ErrorActionPreference = "Stop"

# ---- validation ----------------------------------------------------------------------------
if ($ExtensionModule -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
    throw "ExtensionModule '$ExtensionModule' is not a valid UE module name. Use PascalCase, letters/digits/underscores only, NO hyphens (e.g. 'UnrealAINiagara')."
}
if ($ExtensionId -notmatch '^[a-z0-9]+([._-][a-z0-9]+)*$') {
    throw "ExtensionId '$ExtensionId' should be lowercase dotted/kebab (e.g. 'com.company.unreal-ai-niagara')."
}
if ($ToolId -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    throw "ToolId '$ToolId' must be kebab-case (^[a-z0-9]+(-[a-z0-9]+)*$) — the tool registry rejects anything else."
}
if ($GitHubRepository -notmatch '^[^/]+/[^/]+$') {
    throw "GitHubRepository '$GitHubRepository' must be 'Owner/Repository'."
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

# Content replacements. Sort by key length DESC when applying to avoid partial overlaps.
$Replacements = [ordered]@{
    "YOUR_EXTENSION_DISPLAY_NAME"     = $DisplayName
    "YOUR_GITHUB_USERNAME_REPOSITORY" = $GitHubRepository
    "YOUR_EXTENSION_MODULE"           = $ExtensionModule
    "YOUR_EXTENSION_ID"               = $ExtensionId
    "YOUR_TOOL_ID"                    = $ToolId
}
if (-not [string]::IsNullOrWhiteSpace($FeaturePlugin)) {
    # YOUR_FEATURE_MODULE is a prefix of YOUR_FEATURE_MODULEEditor, so one replace handles both.
    $Replacements["YOUR_FEATURE_MODULE"] = $FeaturePlugin
    $Replacements["YOUR_FEATURE_PLUGIN"] = $FeaturePlugin
}

# Directories never touched (build artifacts, VCS, scripts that reference placeholders by design).
$IgnoreDirs = @('.git', 'Binaries', 'Intermediate', 'Saved', 'DerivedDataCache', 'node_modules', '.vs', 'commands')

Write-Host "Initializing extension:" -ForegroundColor Cyan
Write-Host "  Module/Plugin : $ExtensionModule"
Write-Host "  Extension Id  : $ExtensionId"
Write-Host "  Display Name  : $DisplayName"
Write-Host "  Repository    : $GitHubRepository"
Write-Host "  Sample Tool   : $ToolId"
if (-not [string]::IsNullOrWhiteSpace($FeaturePlugin)) { Write-Host "  Feature Plugin: $FeaturePlugin" }
Write-Host ""

function Test-Ignored([string]$FullPath) {
    $rel = $FullPath.Substring($RepoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    foreach ($dir in $IgnoreDirs) {
        if ($rel -eq $dir -or $rel -like "$dir/*") { return $true }
    }
    return $false
}

$SortedKeys = $Replacements.Keys | Sort-Object { $_.Length } -Descending

# 1) Replace content in files.
Write-Host "Replacing placeholders in file content..." -ForegroundColor Yellow
$AllFiles = Get-ChildItem -Path $RepoRoot -Recurse -File | Where-Object { -not (Test-Ignored $_.FullName) }
foreach ($File in $AllFiles) {
    $content = Get-Content -Path $File.FullName -Raw
    if ($null -eq $content) { continue }
    $new = $content
    foreach ($key in $SortedKeys) { $new = $new.Replace($key, [string]$Replacements[$key]) }
    if ($new -ne $content) {
        Set-Content -Path $File.FullName -Value $new -NoNewline
        Write-Host "  Updated: $($File.FullName.Substring($RepoRoot.Length).TrimStart('\','/'))" -ForegroundColor Gray
    }
}

# 2) Rename files and directories (depth-first / longest path first) for YOUR_EXTENSION_MODULE.
Write-Host "Renaming files and folders..." -ForegroundColor Yellow
$Items = Get-ChildItem -Path $RepoRoot -Recurse | Where-Object { -not (Test-Ignored $_.FullName) } |
    Sort-Object -Property FullName -Descending
foreach ($Item in $Items) {
    if ($Item.Name -like "*YOUR_EXTENSION_MODULE*") {
        $newName = $Item.Name.Replace("YOUR_EXTENSION_MODULE", $ExtensionModule)
        Rename-Item -Path $Item.FullName -NewName $newName
        Write-Host "  Renamed: $($Item.Name) -> $newName" -ForegroundColor Gray
    }
}

# 2b) Rename the sample E2E check file to match the sample tool id (its name is the literal
#     "hello-extension", not a placeholder, so the content pass above did not touch the filename).
$SampleE2E = Join-Path $RepoRoot 'Tests/e2e/tools/hello-extension.e2e.ps1'
if ((Test-Path $SampleE2E) -and ($ToolId -ne 'hello-extension')) {
    $NewE2E = Join-Path $RepoRoot "Tests/e2e/tools/$ToolId.e2e.ps1"
    Rename-Item -Path $SampleE2E -NewName "$ToolId.e2e.ps1"
    Write-Host "  Renamed: hello-extension.e2e.ps1 -> $ToolId.e2e.ps1" -ForegroundColor Gray
}

# 3) Wire the gating engine plugin (optional).
$uplugin = Get-ChildItem -Path $RepoRoot -Recurse -Filter '*.uplugin' |
    Where-Object { -not (Test-Ignored $_.FullName) } | Select-Object -First 1
if (-not [string]::IsNullOrWhiteSpace($FeaturePlugin) -and $uplugin) {
    Write-Host "Wiring gating engine plugin '$FeaturePlugin'..." -ForegroundColor Yellow
    $u = Get-Content $uplugin.FullName -Raw
    $coreBlock = @"
    {
      "Name": "UnrealMCP",
      "Enabled": true
    }
"@
    $withFeature = @"
    {
      "Name": "UnrealMCP",
      "Enabled": true
    },
    {
      "Name": "$FeaturePlugin",
      "Enabled": true
    }
"@
    if ($u.Contains($coreBlock) -and -not $u.Contains("`"Name`": `"$FeaturePlugin`"")) {
        $u = $u.Replace($coreBlock, $withFeature)
        Set-Content -Path $uplugin.FullName -Value $u -NoNewline
        Write-Host "  Added '$FeaturePlugin' to .uplugin Plugins array" -ForegroundColor Gray
    }

    # Uncomment the feature-module dependencies in the Build.cs (now token-substituted to the real name).
    $buildCs = Get-ChildItem -Path $RepoRoot -Recurse -Filter '*.Build.cs' |
        Where-Object { -not (Test-Ignored $_.FullName) } | Select-Object -First 1
    if ($buildCs) {
        $b = Get-Content $buildCs.FullName -Raw
        $b = $b.Replace("// `"$FeaturePlugin`",", "`"$FeaturePlugin`",")
        $b = $b.Replace("// `"${FeaturePlugin}Editor`",", "`"${FeaturePlugin}Editor`",")
        Set-Content -Path $buildCs.FullName -Value $b -NoNewline
        Write-Host "  Uncommented feature-module deps in $($buildCs.Name)" -ForegroundColor Gray
    }

    # Record the gating engine plugin in extension.json's "enginePlugins" (the catalog hint the
    # install-extension resolver enables in the .uproject alongside this extension).
    $extJson = Join-Path $RepoRoot 'extension.json'
    if (Test-Path $extJson) {
        $j = Get-Content $extJson -Raw
        $j = [regex]::Replace($j, '("enginePlugins":\s*)\[\s*\]', "`${1}[`"$FeaturePlugin`"]")
        Set-Content -Path $extJson -Value $j -NoNewline
        Write-Host "  Set extension.json enginePlugins -> [`"$FeaturePlugin`"]" -ForegroundColor Gray
    }
}

# 4) Activate the *.yml-sample workflows.
Write-Host "Activating CI workflows (*.yml-sample -> *.yml)..." -ForegroundColor Yellow
$Samples = Get-ChildItem -Path (Join-Path $RepoRoot '.github/workflows') -Filter '*.yml-sample' -ErrorAction SilentlyContinue
foreach ($s in $Samples) {
    $target = $s.FullName -replace '\.yml-sample$', '.yml'
    Move-Item -Path $s.FullName -Destination $target -Force
    Write-Host "  Activated: $($s.Name) -> $([System.IO.Path]::GetFileName($target))" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Build against a UE project that has the UnrealMCP plugin available (see README.md)."
if ([string]::IsNullOrWhiteSpace($FeaturePlugin)) {
    Write-Host "  2. (optional) Wire your gating engine plugin: add it to the .uplugin 'Plugins' array and"
    Write-Host "     uncomment the feature-module deps in $ExtensionModule.Build.cs."
}
Write-Host "  3. Implement your tools in $ExtensionModule/Source/$ExtensionModule/Private/${ExtensionModule}Module.cpp."
Write-Host "  4. Bump versions in lock-step with ./commands/bump-version.ps1 -NewVersion x.y.z"
