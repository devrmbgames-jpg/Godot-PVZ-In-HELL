param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$BinDir = Join-Path $ProjectRoot ".bin"
$PidFile = Join-Path $BinDir ".godot-editor.pid"

if (-not (Test-Path -LiteralPath $BinDir)) {
    Write-Warning "[Godot] Missing .bin directory: $BinDir"
    exit 0
}

# Avoid launching a duplicate editor when VS Code reloads the workspace.
if (Test-Path -LiteralPath $PidFile) {
    $SavedPidText = (Get-Content -LiteralPath $PidFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($SavedPidText -match "^\d+$") {
        $SavedProcess = Get-Process -Id ([int]$SavedPidText) -ErrorAction SilentlyContinue
        if ($null -ne $SavedProcess -and $SavedProcess.ProcessName -match "(?i)godot") {
            Write-Host "[Godot] Project editor is already running (PID $SavedPidText)."
            exit 0
        }
    }
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
}

# Also detect a manually-started editor for this project.
try {
    $Existing = Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            $_.Name -match "(?i)^Godot.*\.exe$" -and
            $_.CommandLine -and
            $_.CommandLine.Contains($ProjectRoot)
        } |
        Select-Object -First 1

    if ($null -ne $Existing) {
        Set-Content -LiteralPath $PidFile -Value $Existing.ProcessId -NoNewline
        Write-Host "[Godot] Project editor is already running (PID $($Existing.ProcessId))."
        exit 0
    }
} catch {
    # Process discovery is only a duplicate-launch guard; failure is non-fatal.
}

$Candidates = @(
    Get-ChildItem -LiteralPath $BinDir -File -Filter "*.exe" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match "(?i)godot" -and
            $_.Name -notmatch "(?i)console"
        } |
        Sort-Object LastWriteTime -Descending
)

if ($Candidates.Count -eq 0) {
    Write-Warning "[Godot] No Godot editor executable found in $BinDir. Put a Godot 4.7+ Windows binary there and reopen VS Code."
    exit 0
}

$GodotExe = $Candidates[0]
if ($Candidates.Count -gt 1) {
    Write-Host "[Godot] Multiple editor binaries found; using newest: $($GodotExe.Name)"
}

if ($null -eq (Get-Command uvx.exe -ErrorAction SilentlyContinue) -and
    $null -eq (Get-Command uvx -ErrorAction SilentlyContinue)) {
    Write-Warning "[Godot AI] uvx is not available in PATH. Godot will open, but the MCP bridge cannot start until uv is installed and VS Code is restarted."
}

# Keep Godot AI's Codex mutations project-local instead of touching ~/.codex.
$env:CODEX_HOME = Join-Path $ProjectRoot ".codex"

# Keep this development integration local-only.
$env:GODOT_AI_DISABLE_TELEMETRY = "true"

$Arguments = @(
    "--editor",
    "--path",
    ('"' + $ProjectRoot + '"')
)

$Process = Start-Process -FilePath $GodotExe.FullName -ArgumentList $Arguments -WorkingDirectory $ProjectRoot -PassThru

Set-Content -LiteralPath $PidFile -Value $Process.Id -NoNewline
Write-Host "[Godot] Started $($GodotExe.Name) for this project (PID $($Process.Id))."
