param(
    [string]$GodotPath,
    [string]$Label = "milestone",
    [switch]$TestLevel
)

$ErrorActionPreference = "Stop"
function Invoke-NativeLogged([string]$Program, [string[]]$Arguments, [string]$Log) {
    # Explicitly wait even for the exported Windows GUI executable.
    $quotedArguments = @($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $process = Start-Process -FilePath $Program -ArgumentList $quotedArguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $Log -RedirectStandardError "$Log.stderr"
    return $process.ExitCode
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$branch = (& git -C $repositoryRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne "dev") {
    throw "Windows QA export is allowed only on dev; current branch: $branch"
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $repositoryRoot ".bin/Godot_v4.7.1-stable_win64_console.exe"
}
$godot = (Resolve-Path -LiteralPath $GodotPath).Path
$commit = (& git -C $repositoryRoot rev-parse --short HEAD).Trim()
$dirty = -not [string]::IsNullOrWhiteSpace((& git -C $repositoryRoot status --porcelain --untracked-files=normal | Out-String))
$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss'Z'")
$safeLabel = $Label -replace '[^a-zA-Z0-9_-]', '-'
$buildName = "$stamp-$commit-$safeLabel"
$exportRoot = Join-Path $repositoryRoot ".export"
$buildRoot = Join-Path $exportRoot "windows/$buildName"
if (Test-Path -LiteralPath $buildRoot) {
    throw "Build directory already exists: $buildRoot"
}
New-Item -ItemType Directory -Path $buildRoot | Out-Null
$executable = Join-Path $buildRoot "PVZInHell.exe"
$exportLog = Join-Path $buildRoot "export.log"
$startupLog = Join-Path $buildRoot "startup.log"
$startupConsoleLog = Join-Path $buildRoot "startup-console.log"
$menuStartupLog = Join-Path $buildRoot "menu-startup.log"
$menuStartupConsoleLog = Join-Path $buildRoot "menu-startup-console.log"
$preset = if ($TestLevel) { "Windows QA Test Level" } else { "Windows QA" }
$launcherName = if ($TestLevel) { "TEST_LEVEL.cmd" } else { "LATEST.cmd" }
$pointerName = if ($TestLevel) { "test_level.txt" } else { "latest.txt" }
$scenePath = if ($TestLevel) { "res://content/scenes/primitive_test_level.tscn" } else { "res://content/scenes/main_level.tscn" }

Write-Host "Exporting Windows QA: $buildName"
$exportCode = Invoke-NativeLogged $godot @("--headless", "--path", $repositoryRoot, "--export-debug", $preset, $executable) $exportLog
if ($exportCode -ne 0 -or -not (Test-Path -LiteralPath $executable)) {
    Get-Content -LiteralPath $exportLog -Tail 20
    throw "Windows export failed ($exportCode); see $exportLog"
}
Write-Host "Checking exported startup (headless, 120 frames)"
$startupProgram = $executable
$consoleWrapper = Join-Path $buildRoot "PVZInHell.console.exe"
if (Test-Path -LiteralPath $consoleWrapper) {
    $startupProgram = $consoleWrapper
}
Write-Host "Checking exported main menu (headless, 120 frames)"
$menuStartupCode = Invoke-NativeLogged $startupProgram @("--headless", "--quit-after", "120", "--log-file", $menuStartupLog) $menuStartupConsoleLog
if (-not (Test-Path -LiteralPath $menuStartupLog)) {
    throw "Exported main menu produced no engine log; see $menuStartupConsoleLog"
}
$menuStartupErrors = @(Get-Content -LiteralPath $menuStartupLog | Where-Object {
    $_ -match 'SCRIPT ERROR:|ERROR:|ObjectDB instances leaked|resources still in use' -and
    $_ -notmatch 'ERROR: Failed to read the root certificate store\.'
})
if ($menuStartupCode -ne 0 -or $menuStartupErrors -or -not (Select-String -LiteralPath $menuStartupLog -SimpleMatch "QA menu: res://content/ui/main_menu.tscn; target=$scenePath" -Quiet)) {
    Get-Content -LiteralPath $menuStartupLog -Tail 25
    throw "Exported main menu startup check failed ($menuStartupCode); see $menuStartupLog"
}
$startupCode = Invoke-NativeLogged $startupProgram @("--headless", "--quit-after", "120", "--log-file", $startupLog, "--", "--qa-startup-level") $startupConsoleLog
if (-not (Test-Path -LiteralPath $startupLog)) {
    throw "Exported startup produced no engine log; see $startupConsoleLog"
}
$startupErrors = @(Get-Content -LiteralPath $startupLog | Where-Object {
    $_ -match 'SCRIPT ERROR:|ERROR:|ObjectDB instances leaked|resources still in use' -and
    $_ -notmatch 'ERROR: Failed to read the root certificate store\.'
})
if ($startupCode -ne 0 -or $startupErrors) {
    Get-Content -LiteralPath $startupLog -Tail 25
    throw "Exported startup check failed ($startupCode); see $startupLog"
}
if (-not (Select-String -LiteralPath $startupLog -SimpleMatch "QA level: $scenePath;" -Quiet)) {
    throw "Exported startup did not confirm the expected scene: $scenePath; see $startupLog"
}
$version = (& $godot --version | Out-String).Trim()
$info = [ordered]@{
    branch = $branch
    commit = $commit
    working_tree_dirty = $dirty
    label = $Label
    built_at_utc = [DateTime]::UtcNow.ToString("o")
    godot = $version
    preset = $preset
    scene = $scenePath
    executable = "PVZInHell.exe"
    startup_scene = "res://content/ui/main_menu.tscn"
    menu_headless_startup_frames = 120
    menu_headless_startup = "PASS"
    headless_startup_frames = 120
    headless_startup = "PASS"
    external_certificate_store_warning = [bool](Select-String -LiteralPath $startupLog -Pattern 'Failed to read the root certificate store' -Quiet)
    player_qa = "PENDING"
    save_profile = "QA (separate from editor/game progress)"
}
$encoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $buildRoot "build_info.json"), ($info | ConvertTo-Json), $encoding)
$launcher = "@echo off`r`nstart `"PVZ In Hell QA`" `"%~dp0windows\$buildName\PVZInHell.exe`"`r`n"
[System.IO.File]::WriteAllText((Join-Path $exportRoot $launcherName), $launcher, [System.Text.Encoding]::ASCII)
[System.IO.File]::WriteAllText((Join-Path $exportRoot $pointerName), "windows/$buildName/PVZInHell.exe`n", $encoding)
Write-Host "PASS: $executable"
Write-Host "Launcher: $(Join-Path $exportRoot $launcherName)"
