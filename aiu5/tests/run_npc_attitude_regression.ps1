# Runs the 0.10.0 regression probes against one fresh isolated directory per test.
# Usage: pwsh -File tests/run_npc_attitude_regression.ps1 -Root <isolated-dir> [-Only name]
param(
    [string]$Root = "",
    [string]$Only = "",
    [string]$Godot = "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference = "Continue"
$godot = $Godot
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$script:failed = $false
if ($Root -eq "") {
    $Root = Join-Path $project (".runtime\npc-attitude-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
New-Item -ItemType Directory -Force -Path $Root | Out-Null
$log = Join-Path $Root "regression.log"
function Run-Probe([string]$name, [string]$target, [string]$kind) {
    if ($Only -ne "" -and $Only -ne $name) { return }
    $dir = Join-Path $Root $name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $env:AIU5_PROBE_DIRECTORY = $dir
    $env:AIU5_SKILLS_VISUAL_DIR = $dir
    $env:AIU5_CAPTURE = "false"
    $arguments = @("--headless", "--path", $project)
    if ($kind -eq "scene") { $arguments += ($target) } else { $arguments += @("--script", $target) }
    $started = Get-Date
    $output = & $godot @arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    $seconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    $ok = ($code -eq 0) -and ($output -notmatch "SCRIPT ERROR|ERROR:") -and ($output -match "_OK")
    if (-not $ok) { $script:failed = $true }
    $marker = if ($ok) { "OK" } else { "FAIL" }
    $record = "{0}`t{1}`t{2}`t{3}s`t{4}`t{5}" -f $marker, $name, $code, $seconds, $target, $dir
    Add-Content -Path $log -Value $record
    Add-Content -Path (Join-Path $dir "output.txt") -Value $output
    Write-Output $record
    $tail = ($output -split "`r?`n" | Where-Object { $_ -match "OK|FAILED|ERROR|SCRIPT ERROR|checks=" } | Select-Object -Last 6) -join " | "
    if ($tail -ne "") { Write-Output ("    " + $tail) }
}
Run-Probe "npc_attitude" "res://tests/npc_attitude_probe.tscn" "scene"
Run-Probe "npc_completion" "res://tests/npc_completion_probe.tscn" "scene"
Run-Probe "world_completion" "res://tests/world_completion_probe.tscn" "scene"
Run-Probe "onboarding" "res://tests/onboarding_probe.tscn" "scene"
Run-Probe "animals" "res://tests/animals_weapon_probe.tscn" "scene"
Run-Probe "tribes_final" "res://tests/tribes_final_probe.tscn" "scene"
Run-Probe "romance" "res://tests/romance_probe.tscn" "scene"
Run-Probe "branches" "res://tests/branches_smoke.tscn" "scene"
Run-Probe "village" "res://tests/village_smoke.gd" "script"
Run-Probe "magic" "res://tests/magic_smoke.gd" "script"
Run-Probe "livestock" "res://tests/livestock_smoke.gd" "script"
Run-Probe "weapon" "res://tests/weapon_smoke.gd" "script"
# Rendering probes run separately with a real GPU; headless image calls are not evidence.
Run-Probe "crafting_clock" "res://tests/crafting_clock_probe.tscn" "scene"
Write-Output ("REGRESSION_LOG=" + $log)

if ($script:failed) { exit 1 }
