#!/usr/bin/env pwsh
<#
.SYNOPSIS
    End-to-end tool-invocation harness for this extension (one-test-per-tool convention).

.DESCRIPTION
    For each check under Tests/e2e/tools/*.e2e.ps1, invokes the named MCP tool through the running
    project's local MCP server via `unreal-mcp-cli run-tool` (or `run-system-tool`) and asserts a
    well-formed result. This is the cross-dependency on the install/CLI layer described in the design
    note §7: CI boots a headless editor, installs THIS extension with `unreal-mcp-cli install-extension`,
    then runs this harness against the live server.

    Each check file returns a hashtable:
      @{ Tool = "hello-extension"; System = $false; Input = '{"name":"CI"}';
         ExpectError = $false; Assert = { param($Out) ... } }
    - Tool        : the tool id to invoke.
    - System      : $true to use `run-system-tool` instead of `run-tool`.
    - Input       : optional JSON string passed as --input.
    - ExpectError : $true when the tool is EXPECTED to return a tool-level error for this input
                    (e.g. a defensive handler rejecting a bad path). A non-zero CLI exit or an
                    error-shaped payload is then the PASS condition — the Assert still runs against
                    the captured output, so a MUTATING tool can be round-trip-checked WITHOUT
                    seeding a project asset. $false (default): a non-zero exit fails the check.
    - Assert      : optional scriptblock receiving the parsed JSON (or the raw output string when
                    the payload is not JSON); throw to fail.

.PARAMETER ProjectDir
    The Unreal project directory whose local MCP server is running (resolves URL + token).

.PARAMETER Cli
    The unreal-mcp-cli invocation. Default: "unreal-mcp-cli". Use e.g. "npx unreal-mcp-cli" or an
    absolute path to a local build.

.EXAMPLE
    ./Tests/e2e/Run-ToolChecks.ps1 -ProjectDir "C:/path/to/UEProject"
#>
param(
    [Parameter(Mandatory = $true)][string]$ProjectDir,
    [string]$Cli = "unreal-mcp-cli"
)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsDir = Join-Path $scriptDir 'tools'

$checks = Get-ChildItem -Path $toolsDir -Filter '*.e2e.ps1' -ErrorAction SilentlyContinue
if (-not $checks) { Write-Error "No tool checks found under $toolsDir"; exit 1 }

# Split the CLI invocation into exe + leading args (supports "npx unreal-mcp-cli").
$cliParts = $Cli -split '\s+'
$cliExe = $cliParts[0]
$cliLead = @($cliParts[1..($cliParts.Length - 1)])

$failures = 0
foreach ($checkFile in $checks) {
    $check = & $checkFile.FullName
    $tool = $check.Tool
    $verb = if ($check.System) { 'run-system-tool' } else { 'run-tool' }
    $expectError = [bool]$check.ExpectError
    Write-Host "==> [$verb] $tool$(if ($expectError) { ' (expect error)' })" -ForegroundColor Cyan

    $args = @($cliLead + @($verb, $tool, '--path', $ProjectDir))
    if ($check.Input) { $args += @('--input', $check.Input) }

    try {
        $out = & $cliExe @args 2>&1
        $exit = $LASTEXITCODE
        $text = ($out | Out-String).Trim()

        # A non-zero exit is a hard failure UNLESS the check expects a tool-level error, in which
        # case the captured error payload is handed to the Assert below (run-tool surfaces a
        # tool-level failure either as a non-zero exit or as an isError payload on a 200).
        if ($exit -ne 0 -and -not $expectError) { throw "CLI exited $exit. Output:`n$text" }
        if ($exit -eq 0 -and $expectError -and -not $check.Assert) {
            throw "expected a tool-level error but the call succeeded. Output:`n$text"
        }

        # Hand the Assert a parsed object when possible, else the raw text.
        $parsed = $null
        try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $text }
        if (-not $expectError -and $parsed -is [string]) {
            throw "tool output is not valid JSON (a well-formed success is required). Output:`n$text"
        }

        if ($check.Assert) { & $check.Assert $parsed }
        Write-Host "    PASS" -ForegroundColor Green
    }
    catch {
        Write-Host "    FAIL: $($_.Exception.Message)" -ForegroundColor Red
        $failures++
    }
}

Write-Host ""
if ($failures -gt 0) { Write-Error "$failures tool check(s) failed."; exit 1 }
Write-Host "All tool checks passed." -ForegroundColor Green
