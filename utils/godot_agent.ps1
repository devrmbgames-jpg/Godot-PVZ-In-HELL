[CmdletBinding()]
param(
    [ValidateSet("Version", "ParseChanged", "ParseFiles", "GUT", "Import", "OfflineScript")]
    [string]$Action = "ParseChanged",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotPath = "",
    [string[]]$Paths = @(),
    [string]$TestPath = "",
    [string]$ScriptPath = "",
    [ValidateRange(0, 2147483)]
    [int]$TimeoutSeconds = 0
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
        if ($command -match '(?i)(?:^|\s)(?:--editor|-e)(?:\s|$)' -and
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
    $isVendoredAddon = $normalized.StartsWith("addons/") -and
        -not ($normalized.StartsWith("addons/pvz_ai_tools/") -or
              $normalized.StartsWith("addons/project_entity_traits/"))
    if (-not $normalized.EndsWith(".gd") -or $isVendoredAddon -or
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

function Get-GodotDiagnostics {
    param([string[]]$StdoutLines, [string[]]$StderrLines, [string]$Action, [int]$ExitCode)

    $ansi = '\x1B\[[0-?]*[ -/]*[@-~]'
    $output = @($StdoutLines | ForEach-Object { $_ -replace $ansi, '' })
    $errors = @($StderrLines | ForEach-Object { $_ -replace $ansi, '' })
    $expectedPattern = "^\[ExpectedError\]Expected engine error containing '(ConfigFile parse error at user://[^']+)'\.\s*$"
    $nativePattern = '^ERROR: (ConfigFile parse error at user://.+?):\d+:.*$'
    $accepted = @{}
    if ($Action -eq 'GUT' -and $ExitCode -eq 0) {
        $expectedCounts = @{}
        $nativeCounts = @{}
        foreach ($line in @($output + $errors)) {
            if ($line -match $expectedPattern) {
                $prefix = $Matches[1]
                $expectedCounts[$prefix] = 1 + [int]$expectedCounts[$prefix]
            }
        }
        foreach ($line in @($output + $errors)) {
            if ($line -match $nativePattern) {
                $prefix = $Matches[1]
                $nativeCounts[$prefix] = 1 + [int]$nativeCounts[$prefix]
            }
        }
        foreach ($prefix in $expectedCounts.Keys) {
            if ($expectedCounts[$prefix] -eq $nativeCounts[$prefix]) { $accepted[$prefix] = $true }
        }
    }
    foreach ($line in @($output + $errors)) {
        if (($line -match $expectedPattern -or $line -match $nativePattern) -and
            $accepted.ContainsKey($Matches[1])) { continue }
        if ($line -match 'SCRIPT ERROR|Parse Error|Assertion failed|(?i)\bERROR:' -and
            $line -notmatch '^ERROR: Failed to read the root certificate store\.$') { $line }
    }
}

function Get-GodotValidationResult {
    param(
        [string[]]$StdoutLines, [string[]]$StderrLines, [string]$Action,
        [Nullable[int]]$ExitCode, [bool]$TimedOut = $false
    )

    $ansi = '\x1B\[[0-?]*[ -/]*[@-~]'
    $output = @($StdoutLines | ForEach-Object { $_ -replace $ansi, '' })
    $errors = @($StderrLines | ForEach-Object { $_ -replace $ansi, '' })
    $complete = $false
    $requiresMarker = $Action -in @('GUT', 'ParseFiles', 'ParseChanged')
    if ($Action -eq 'GUT') {
        $markers = @($output | Where-Object { $_ -match '^---- All tests passed! ----\s*$' })
        $totals = @($output | Where-Object { $_ -match '^Tests\s+[1-9][0-9]*\s*$' })
        $passing = @($output | Where-Object { $_ -match '^Passing Tests\s+[1-9][0-9]*\s*$' })
        $complete = $markers.Count -eq 1 -and $totals.Count -eq 1 -and $passing.Count -eq 1
        if ($complete) {
            $totalCount = ($totals[0] -split '\s+')[-1]
            $passingCount = ($passing[0] -split '\s+')[-1]
            $complete = $totalCount -eq $passingCount
        }
    } elseif ($Action -in @('ParseFiles', 'ParseChanged')) {
        $markers = @($output | Where-Object {
            $_ -match '^Changed-script parser: PASS \([1-9][0-9]* files, 0 failures\)\s*$'
        })
        $complete = $markers.Count -eq 1
    }

    # Recognize only an exact engine shutdown message AND its native shutdown callsite.
    # ObjectDB summaries cannot distinguish retained scripts from live Nodes. Keep them UNKNOWN.
    # Unverified RID/StringName/PagedAllocator messages also remain actionable, never word-filtered.
    $remainingErrors = [Collections.Generic.List[string]]::new()
    $known = [Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $errors.Count; $index++) {
        if ($errors[$index] -match '^ERROR: [1-9][0-9]* resources still in use at exit \(run with --verbose for details\)\.$' -and
            $index + 1 -lt $errors.Count -and
            $errors[$index + 1] -match '^   at: clear \(core/io/resource\.cpp:[1-9][0-9]*\)$') {
            $known.Add($errors[$index])
            $index++
        } else {
            $remainingErrors.Add($errors[$index])
        }
    }

    $diagnostics = @(Get-GodotDiagnostics $output $remainingErrors.ToArray() $Action $ExitCode)
    $unknown = [Collections.Generic.List[string]]::new()
    $expectedConfigContext = $false
    foreach ($line in $remainingErrors) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($diagnostics -contains $line) { $expectedConfigContext = $false; continue }
        if ($line -match '^ERROR: ConfigFile parse error at user://.+?:\d+:.*$') {
            # The legacy exact/count-matched expected-negative contract already accepted this line.
            $expectedConfigContext = $true
            continue
        }
        if ($expectedConfigContext -and $line -match '^   at: _parse \(core/io/config_file\.cpp:\d+\)$') {
            $expectedConfigContext = $false
            continue
        }
        if ($line -eq 'ERROR: Failed to read the root certificate store.') { continue }
        $expectedConfigContext = $false
        $unknown.Add($line)
    }
    foreach ($line in $output) {
        if ($line -match '^WARNING:|^Leaked instance:|^Orphan StringName:' -or
            $line -match '(?i)^\s*(?:\[Orphans\]\s*)?[1-9][0-9]* Orphans\s*$') { $unknown.Add($line) }
    }
    $liveFailure = @($output + $errors | Where-Object {
        $_ -match '(?i)(leak.*\bNodes?\b|\bNodes?\b.*leak|use.after.free|double.free|\[Failed\]|---- [1-9][0-9]* failing tests ----)' -or
        $_ -match '^\s*Orphans\s+[1-9][0-9]*\s*$'
    }).Count -gt 0
    $diagnosticStatus = 'CLEAN'
    if ($diagnostics.Count -gt 0 -or $liveFailure) { $diagnosticStatus = 'FAIL' }
    elseif ($unknown.Count -gt 0 -or ($known.Count -gt 0 -and
        (-not $complete -or $null -eq $ExitCode -or $ExitCode -ne 0 -or $TimedOut))) { $diagnosticStatus = 'UNKNOWN' }
    elseif ($known.Count -gt 0) { $diagnosticStatus = 'KNOWN_ENGINE_LIMITATION' }

    $functionalStatus = 'PASS'
    if ($TimedOut -or ($null -ne $ExitCode -and $ExitCode -ne 0) -or $diagnosticStatus -eq 'FAIL') { $functionalStatus = 'FAIL' }
    elseif ($null -eq $ExitCode) { $functionalStatus = 'UNKNOWN' }
    elseif (($requiresMarker -and -not $complete) -or $diagnosticStatus -eq 'UNKNOWN') { $functionalStatus = 'UNKNOWN' }
    [pscustomobject]@{
        FunctionalStatus = $functionalStatus
        DiagnosticStatus = $diagnosticStatus
        DiagnosticDisposition = $(if ($diagnosticStatus -eq 'KNOWN_ENGINE_LIMITATION') { 'DEFERRED' } else { $diagnosticStatus })
        CompletionVerified = $complete
        TimedOut = $TimedOut
        Diagnostics = @($diagnostics)
        UnknownDiagnostics = @($unknown.ToArray())
        KnownShutdownDiagnostics = @($known.ToArray())
    }
}

function Stop-GodotValidationProcess {
    # Only the Start-Process result from this runner may enter this ownership boundary.
    param($Process)
    if ($Process.HasExited) { return }
    if ($env:OS -ne 'Windows_NT') { throw 'Bounded timeout cleanup requires Windows process-tree support.' }

    $children = [Collections.Generic.List[Diagnostics.Process]]::new()
    try {
        $records = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId)
        $ownedIds = [Collections.Generic.List[int]]::new()
        $ownedIds.Add($Process.Id)
        for ($index = 0; $index -lt $ownedIds.Count; $index++) {
            foreach ($record in $records) {
                if ($record.ParentProcessId -ne $ownedIds[$index] -or $ownedIds.Contains($record.ProcessId)) { continue }
                $ownedIds.Add($record.ProcessId)
                try {
                    $child = [Diagnostics.Process]::GetProcessById($record.ProcessId)
                    $null = $child.Handle
                } catch [ArgumentException] { continue }
                # An exited PID reused between enumeration and capture is not our child.
                if ($child.StartTime -lt $Process.StartTime) { $child.Dispose(); continue }
                $children.Add($child)
            }
        }
        $killOutput = @(& taskkill.exe /PID $Process.Id /T /F 2>&1)
        if ($LASTEXITCODE -ne 0 -and -not $Process.HasExited) {
            throw ('Owned validation tree cleanup failed: ' + ($killOutput -join ' '))
        }
        foreach ($child in $children) {
            if (-not $child.WaitForExit(10000)) { throw "Owned validation child did not exit: $($child.Id)" }
        }
    } finally {
        foreach ($child in $children) { $child.Dispose() }
    }
}

if ($TimeoutSeconds -gt 0 -and $env:OS -ne 'Windows_NT') {
    throw 'TimeoutSeconds requires Windows process-tree support; use the default 0 elsewhere.'
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
            Where-Object {
                $_ -match '\.gd$' -and
                ($_ -notmatch '^addons/' -or $_ -match '^addons/(pvz_ai_tools|project_entity_traits)/')
            } |
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
$resultPath = Join-Path $logDir "$label-$stamp.result.json"
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
$timedOut = $false
if ($TimeoutSeconds -gt 0) { $launch.Wait = $false }
$process = Start-Process @launch
if ($TimeoutSeconds -gt 0) {
    # Retain the native handle before waiting; Windows PowerShell can otherwise lose ExitCode.
    $null = $process.Handle
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { Stop-GodotValidationProcess $process }
    $process.WaitForExit()
}
$stdoutLines = @()
$stderrLines = @()
if (Test-Path -LiteralPath $stdout) { $stdoutLines = @(Get-Content -Encoding UTF8 -LiteralPath $stdout) }
if (Test-Path -LiteralPath $stderr) { $stderrLines = @(Get-Content -Encoding UTF8 -LiteralPath $stderr) }
$result = Get-GodotValidationResult $stdoutLines $stderrLines $Action $process.ExitCode $timedOut
[ordered]@{
    schema = 1
    action = $Action
    engine_version = ($versionOutput -join ' ')
    native_exit_code = $process.ExitCode
    stdout = $stdout
    stderr = $stderr
    result = $result
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
$failed = $result.FunctionalStatus -ne 'PASS'
if ($failed) {
    Write-Output "FAIL: $Action (exit $($process.ExitCode)); logs: $stdout ; $stderr"
    Write-Output "  Functional=$($result.FunctionalStatus); diagnostics=$($result.DiagnosticStatus); result: $resultPath"
    @($result.Diagnostics + $result.UnknownDiagnostics) | Select-Object -Unique -First 18 | ForEach-Object { Write-Output "  $_" }
    exit 1
}
Write-Output "PASS: $Action (Godot 4.7.1); logs: $stdout ; $stderr"
Write-Output "  Functional=PASS; diagnostics=$($result.DiagnosticStatus)/$($result.DiagnosticDisposition); result: $resultPath"
exit 0
