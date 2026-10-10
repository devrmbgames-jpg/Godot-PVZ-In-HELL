[CmdletBinding()]
param(
    [ValidateSet("Version", "ParseChanged", "ParseFiles", "GUT", "Import", "OfflineScript")]
    [string]$Action = "ParseChanged",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotPath = "",
    [string[]]$Paths = @(),
    [string]$TestPath = "",
    [string]$ScriptPath = ""
)

# One real-Godot CLI runner for Codex and VS Code, independent of any MCP bridge.
# Offline editor/import modes refuse to run beside this project's GUI editor.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not (Test-Path -LiteralPath (Join-Path $root "project.godot") -PathType Leaf)) {
    throw "Not a Godot project: $root"
}

function Resolve-GodotBinary {
    param([string]$Explicit, [string]$ProjectDir)

    [string[]]$candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        $candidates += $Explicit
    } elseif (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $candidates += $env:GODOT_BIN
    } else {
        $binDir = Join-Path $ProjectDir ".bin"
        if (Test-Path -LiteralPath $binDir -PathType Container) {
            $preferred = @(
                "Godot_v4.7.1-stable_win64_console.exe",
                "Godot_v4.7.1-stable_win64.exe"
            )
            foreach ($name in $preferred) {
                $candidates += (Join-Path $binDir $name)
            }
            $candidates += @(Get-ChildItem -LiteralPath $binDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '(?i)^Godot.*(\.exe|\.x86_64)$' } |
                Sort-Object Name |
                Select-Object -ExpandProperty FullName)
        }
        foreach ($name in @("godot4", "godot", "godot.exe")) {
            $command = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($null -ne $command) {
                $candidates += $command.Source
            }
        }
    }

    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }
        $selected = (Resolve-Path -LiteralPath $candidate).Path
        if ($env:OS -eq "Windows_NT" -and
            $selected -match '(?i)\.exe$' -and
            $selected -notmatch '(?i)_console\.exe$') {
            $sibling = Join-Path (Split-Path -Parent $selected) (
                [IO.Path]::GetFileNameWithoutExtension($selected) + "_console.exe"
            )
            if (Test-Path -LiteralPath $sibling -PathType Leaf) {
                return $sibling
            }
        }
        return $selected
    }
    throw "Godot not found. Add pinned 4.7.1 to .bin, set GODOT_BIN, use -GodotPath, or put it in PATH."
}

function Test-ProjectEditorOpen {
    param([string]$ProjectDir)

    if ($env:OS -ne "Windows_NT") {
        # Refuse an unsafe offline mutation if the platform cannot verify editor ownership.
        $openGodot = @(Get-Process -Name "godot*" -ErrorAction SilentlyContinue)
        return $openGodot.Count -gt 0
    }

    try {
        $processes = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" -ErrorAction Stop)
    } catch {
        throw "Cannot verify Godot Editor ownership; refusing offline mutation: $($_.Exception.Message)"
    }
    foreach ($candidate in $processes) {
        $command = [string]$candidate.CommandLine
        if ($command -match '(?i)(?:^|\s)--editor(?:\s|$)' -and
            $command.IndexOf($ProjectDir, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }
    return $false
}

function Normalize-ResourcePath {
    param([string]$Path)
    $normalized = $Path.Replace('\', '/')
    if ($normalized.StartsWith("res://")) {
        $normalized = $normalized.Substring(6)
    }
    if (-not $normalized.EndsWith(".gd") -or $normalized.StartsWith("addons/") -or
        $normalized.Contains("..") -or $normalized.StartsWith("/")) {
        throw "Expected one project-owned res://*.gd script: $Path"
    }
    $candidate = Join-Path $root $normalized
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Script not found: $normalized"
    }
    return "res://$normalized"
}

$godot = Resolve-GodotBinary -Explicit $GodotPath -ProjectDir $root
if ($Action -eq "Version") {
    & $godot --version
    exit $LASTEXITCODE
}

$versionOutput = @(& $godot --version)
if ($LASTEXITCODE -ne 0 -or -not (($versionOutput -join " ") -match '^4\.7\.1(\.|$)')) {
    throw "This project requires Godot 4.7.1, got: $($versionOutput -join ' ')"
}

$arguments = @("--headless", "--path", ('"' + $root + '"'))
$label = $Action.ToLowerInvariant()
switch ($Action) {
    "ParseChanged" {
        Push-Location $root
        try {
            $changed = @(& git diff --name-only --diff-filter=ACMR HEAD --)
            if ($LASTEXITCODE -ne 0) { throw "git diff failed" }
            $untracked = @(& git ls-files --others --exclude-standard)
            if ($LASTEXITCODE -ne 0) { throw "git ls-files failed" }
        } finally {
            Pop-Location
        }
        $selected = @($changed + $untracked |
            Where-Object { $_ -match '\.gd$' -and $_ -notmatch '^addons/' } |
            Sort-Object -Unique)
        if ($selected.Count -eq 0) {
            Write-Output "NO_CHANGES: no changed project-owned GDScript files to parse."
            exit 0
        }
        $pathsToParse = @($selected | ForEach-Object { Normalize-ResourcePath $_ })
        $arguments += @("--script", "res://utils/parse_gdscript.gd", "--")
        $arguments += $pathsToParse
    }
    "ParseFiles" {
        if ($Paths.Count -eq 0) { throw "ParseFiles requires -Paths." }
        $pathsToParse = @($Paths | ForEach-Object { Normalize-ResourcePath $_ })
        $arguments += @("--script", "res://utils/parse_gdscript.gd", "--")
        $arguments += $pathsToParse
    }
    "GUT" {
        if ([string]::IsNullOrWhiteSpace($TestPath)) {
            throw "GUT requires -TestPath res://tests/gut/name.gd."
        }
        $testScript = Normalize-ResourcePath $TestPath
        if (-not $testScript.StartsWith("res://tests/gut/")) {
            throw "GUT must use a focused res://tests/gut/*.gd script."
        }
        $arguments += @("--script", "res://addons/gut/gut_cmdln.gd", "-gtest=$testScript", "-gexit")
    }
    "Import" {
        if (Test-ProjectEditorOpen -ProjectDir $root) {
            throw "BLOCKED: close this project's GUI editor before headless import (no forced termination)."
        }
        $arguments += @("--editor", "--import")
    }
    "OfflineScript" {
        if (Test-ProjectEditorOpen -ProjectDir $root) {
            throw "BLOCKED: close this project's GUI editor before offline scene migration."
        }
        if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
            throw "OfflineScript requires -ScriptPath res://utils/name.gd."
        }
        # CLI scripts must extend SceneTree/MainLoop, NOT EditorScript.
        $script = Normalize-ResourcePath $ScriptPath
        $arguments += @("--editor", "--script", $script)
    }
}

$logDir = Join-Path $root ".artifacts/godot_agent"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmssfff")
$stdout = Join-Path $logDir "$label-$stamp.stdout.log"
$stderr = Join-Path $logDir "$label-$stamp.stderr.log"
$launch = @{
    FilePath = $godot
    ArgumentList = [string[]]$arguments
    WorkingDirectory = $root
    RedirectStandardOutput = $stdout
    RedirectStandardError = $stderr
    Wait = $true
    PassThru = $true
}
if ($env:OS -eq "Windows_NT") {
    $launch.WindowStyle = "Hidden"
}
$process = Start-Process @launch
$lines = @()
if (Test-Path -LiteralPath $stdout) { $lines += @(Get-Content -LiteralPath $stdout) }
if (Test-Path -LiteralPath $stderr) { $lines += @(Get-Content -LiteralPath $stderr) }
$diagnostics = @($lines | Where-Object {
    ($_ -match 'SCRIPT ERROR|Parse Error|Assertion failed|(?i)\bERROR:') -and
    ($_ -notmatch '^ERROR: Failed to read the root certificate store\.$')
})
$failed = $process.ExitCode -ne 0 -or $diagnostics.Count -gt 0
if ($Action -in @("ParseFiles", "ParseChanged") -and
    -not ($lines -match 'Changed-script parser: PASS')) {
    $failed = $true
}
if ($failed) {
    Write-Output "FAIL: $Action (exit $($process.ExitCode)); logs: $stdout ; $stderr"
    $diagnostics | Select-Object -Unique -First 18 | ForEach-Object { Write-Output "  $_" }
    exit 1
}
Write-Output "PASS: $Action (Godot 4.7.1); logs: $stdout ; $stderr"
exit 0
