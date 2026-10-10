[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$EditorPid,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Evidence,
    [switch]$Restart
)

# Owner-approved emergency recovery for a CONFIRMED project.godot modal.
# A generic MCP error, unresponsive socket or stale PID is NOT confirmation.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT") {
    throw "This guarded process-recovery command requires Windows/CIM."
}
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $root "project.godot") -PathType Leaf)) {
    throw "Refusing: selected directory is not a Godot project: $root"
}
if ($Evidence.Trim().Length -lt 12) {
    throw "Provide concrete evidence of a blocked project.godot external-change dialog."
}

$processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $EditorPid" -ErrorAction Stop
if ($null -eq $processInfo) {
    throw "Godot PID $EditorPid is gone. No process was terminated."
}
$binary = [System.IO.Path]::GetFileName([string]$processInfo.ExecutablePath)
$command = [string]$processInfo.CommandLine
if ($binary -notmatch '(?i)^Godot[^\\/]*\.exe$') {
    throw "Refusing: PID $EditorPid is not a Godot executable ($binary)."
}
if ($command -notmatch '(?i)(?:^|\s)--editor(?:\s|$)') {
    throw "Refusing: PID $EditorPid does not have the --editor argument."
}
if ($command.IndexOf($root, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "Refusing: PID $EditorPid does not identify this project in its command line."
}

$logDir = Join-Path $root ".artifacts\godot_agent"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logPath = Join-Path $logDir "editor-recovery.jsonl"
$record = [ordered]@{
    utc = [DateTime]::UtcNow.ToString("o")
    project = $root
    pid = $EditorPid
    binary = $binary
    reason = "confirmed_project_godot_external_change_modal"
    evidence = $Evidence.Trim()
    consequence = "Forced termination may discard unsaved editor work"
    restart = [bool]$Restart
    outcome = "requested"
}

if (-not $PSCmdlet.ShouldProcess("Godot Editor PID $EditorPid ($root)", "Force-stop blocked editor; unsaved work may be lost")) {
    Write-Output "NOT_RUN: recovery was not approved (or -WhatIf); no process killed."
    return
}

# Always leave an audit record even if Stop-Process itself fails.
($record | ConvertTo-Json -Compress -Depth 4) | Add-Content -LiteralPath $logPath -Encoding UTF8
try {
    $target = Get-Process -Id $EditorPid -ErrorAction Stop
    Stop-Process -InputObject $target -Force -ErrorAction Stop
    if (-not $target.WaitForExit(8000)) {
        throw "Godot PID $EditorPid did not terminate after Stop-Process."
    }
    $record.outcome = "stopped"
} catch {
    $record.outcome = "failed"
    $record.error = $_.Exception.Message
    ($record | ConvertTo-Json -Compress -Depth 4) | Add-Content -LiteralPath $logPath -Encoding UTF8
    throw
}

$pidFile = Join-Path $root ".bin\.godot-editor.pid"
if (Test-Path -LiteralPath $pidFile) {
    $pidText = (Get-Content -LiteralPath $pidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($pidText -eq [string]$EditorPid) {
        Remove-Item -LiteralPath $pidFile -Force
    }
}
($record | ConvertTo-Json -Compress -Depth 4) | Add-Content -LiteralPath $logPath -Encoding UTF8
Write-Output "STOPPED: verified Godot Editor PID $EditorPid. Evidence recorded: $logPath"
Write-Warning "The editor was force-stopped; any unsaved work in it may have been lost."

if ($Restart) {
    & (Join-Path $PSScriptRoot "start-godot.ps1") -ProjectRoot $root
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Godot Editor restart failed with exit code $LASTEXITCODE."
    }
}
