# Licensed under the Apache License, Version 2.0.
<#
.SYNOPSIS
    Stops the Unreal processes (UnrealEditor / UnrealEditor-Cmd, UBT, ShaderCompileWorker, ...)
    that this repository's CI started against its own host project, plus their descendants.

.DESCRIPTION
    A job that is cancelled or loses its runner can leave UnrealEditor-Cmd.exe running for hours,
    holding the plugin DLLs open. This script finds every process whose command line references
    THIS repository's host project dir (forward- or back-slashed) and stops it together with its
    descendant tree.

    Only this repository's processes can match: the host dir is per repository (see
    docs/agents/ci.md "Host project isolation"), and each repository runs at most one job per
    machine. Another repository's job never references this host, so it is never touched.

    Best effort: it never fails the job (always exits 0).
#>
param(
    [Parameter(Mandatory = $true)] [string] $HostDir,
    [int] $WaitSeconds = 30
)

$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($HostDir)) { exit 0 }
$back = [IO.Path]::GetFullPath($HostDir).TrimEnd('\')
$fwd = $back.Replace('\', '/')

$all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
$byParent = $all | Group-Object ParentProcessId -AsHashTable -AsString

# Never stop this script's own process chain.
$ancestors = @{}
$cur = $PID
for ($i = 0; $i -lt 32 -and $cur; $i++) {
    $ancestors[[int]$cur] = $true
    $p = $all | Where-Object ProcessId -EQ $cur | Select-Object -First 1
    if (-not $p) { break }
    $cur = $p.ParentProcessId
}

$targets = @{}
$queue = [Collections.Generic.Queue[object]]::new()
foreach ($p in $all) {
    $cl = $p.CommandLine
    if ($cl -and ($cl.IndexOf($back, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                  $cl.IndexOf($fwd, [StringComparison]::OrdinalIgnoreCase) -ge 0)) {
        $queue.Enqueue($p)
    }
}
while ($queue.Count -gt 0) {
    $p = $queue.Dequeue()
    $id = [int]$p.ProcessId
    if ($ancestors.ContainsKey($id) -or $targets.ContainsKey($id)) { continue }
    $targets[$id] = $p
    foreach ($c in @($byParent["$id"])) {
        # A child created before its "parent" is a pid-reuse artefact, not a descendant.
        if ($c -and $c.CreationDate -ge $p.CreationDate) { $queue.Enqueue($c) }
    }
}

if ($targets.Count -eq 0) {
    Write-Host "No leftover processes reference $back."
    exit 0
}
foreach ($p in $targets.Values) {
    Write-Host "Stopping leftover pid $($p.ProcessId) $($p.Name) (started $($p.CreationDate))"
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}
$deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
do {
    $alive = @($targets.Keys | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
    if ($alive.Count -eq 0) { break }
    Start-Sleep -Seconds 1
} while ([DateTime]::UtcNow -lt $deadline)
if ($alive.Count -gt 0) {
    Write-Host "::warning::Could not stop pid(s) $($alive -join ', ') referencing $back within $WaitSeconds s."
} else {
    Write-Host "Stopped $($targets.Count) leftover process(es) referencing $back."
}
exit 0
