[CmdletBinding()]
param(
	[string]$Name = "hazards",
	[switch]$All,
	[switch]$List,
	[string]$GodotPath,
	[int]$Frames = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

## Runs project headless smoke scenes and validates their standard completion output.

function Get-PreferredGodotExecutable([string]$CandidatePath) {
	if (-not (Test-Path -LiteralPath $CandidatePath -PathType Leaf)) {
		throw "Godot executable was not found: $CandidatePath"
	}

	if ($env:OS -eq "Windows_NT" -and $CandidatePath -match "(?i)\.exe$") {
		[string]$consolePath = [System.IO.Path]::Combine(
			[System.IO.Path]::GetDirectoryName($CandidatePath),
			"$([System.IO.Path]::GetFileNameWithoutExtension($CandidatePath))_console.exe"
		)
		if (Test-Path -LiteralPath $consolePath -PathType Leaf) {
			return $consolePath
		}
	}

	return $CandidatePath
}

function Get-SettingsGodotPath([string]$SettingsPath) {
	if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
		return ""
	}

	try {
		[object]$settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
		[object]$property = $settings.PSObject.Properties["godotTools.editorPath.godot4"]
		if ($null -ne $property -and $property.Value -is [string]) {
			return $property.Value
		}
	} catch {
		Write-Warning "Could not read .vscode/settings.json: $($_.Exception.Message)"
	}

	return ""
}

function Resolve-GodotExecutable([string]$ExplicitPath, [string]$RepositoryRoot) {
	[string[]]$pathCandidates = @()
	if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
		$pathCandidates += $ExplicitPath
	} elseif (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
		$pathCandidates += $env:GODOT_BIN
	} else {
		foreach ($commandName in @("godot4", "godot")) {
			[object]$command = Get-Command -Name $commandName -CommandType Application -ErrorAction SilentlyContinue
			if ($null -ne $command) {
				$pathCandidates += $command.Source
				break
			}
		}

		if ($pathCandidates.Count -eq 0) {
			[string]$settingsPath = Join-Path $RepositoryRoot ".vscode/settings.json"
			[string]$settingsGodotPath = Get-SettingsGodotPath $settingsPath
			if (-not [string]::IsNullOrWhiteSpace($settingsGodotPath)) {
				$pathCandidates += $settingsGodotPath
			}
		}
	}

	if ($pathCandidates.Count -eq 0) {
		throw "Godot was not found. Use -GodotPath, set GODOT_BIN, add Godot to PATH, or configure .vscode/settings.json."
	}

	return Get-PreferredGodotExecutable $pathCandidates[0]
}

function Get-SmokeScenes([string]$SmokeDirectory) {
	if (-not (Test-Path -LiteralPath $SmokeDirectory -PathType Container)) {
		return @()
	}

	return @(Get-ChildItem -LiteralPath $SmokeDirectory -Filter "*_smoke.tscn" -File | Sort-Object Name)
}

function Get-SmokeName([System.IO.FileInfo]$Scene) {
	return [System.IO.Path]::GetFileNameWithoutExtension($Scene.Name) -replace "_smoke$", ""
}

function Test-IgnoredCertificateStoreError([string]$Line) {
	return $Line -match "^ERROR: Failed to read the root certificate store\.$"
}

function Test-SmokeLog([string[]]$LogLines) {
	[string[]]$failures = @()
	if (-not ($LogLines -match "(?m)(?:^PASS(?:\s|:|$)|\bsmoke PASS\s*$)")) {
		$failures += "PASS line was not found"
	}

	foreach ($line in $LogLines) {
		if ($line -match "(?i)SCRIPT ERROR|Parse Error|Assertion failed") {
			$failures += $line
			continue
		}

		if ($line -match "(?i)\bERROR:" -and -not (Test-IgnoredCertificateStoreError $line)) {
			$failures += $line
		}
	}

	return $failures
}

[string]$repositoryRoot = Split-Path -Parent $PSScriptRoot
[string]$smokeDirectory = Join-Path $repositoryRoot "tests/smoke"
[string]$artifactDirectory = Join-Path $repositoryRoot "tests/artifacts"
[System.IO.FileInfo[]]$scenes = @(Get-SmokeScenes $smokeDirectory)

if ($List) {
	foreach ($scene in $scenes) {
		Write-Output (Get-SmokeName $scene)
	}
	exit 0
}

if ($PSBoundParameters.ContainsKey("Frames") -and $Frames -lt 1) {
	throw "-Frames must be at least 1."
}

[System.IO.FileInfo[]]$selectedScenes = @()
if ($All) {
	$selectedScenes = $scenes
} else {
	$selectedScenes = @($scenes | Where-Object { (Get-SmokeName $_) -ieq $Name })
}

if ($selectedScenes.Count -eq 0) {
	[string]$availableNames = ($scenes | ForEach-Object { Get-SmokeName $_ }) -join ", "
	throw "No smoke scene matched '$Name'. Available: $availableNames"
}

[string]$godot = Resolve-GodotExecutable $GodotPath $repositoryRoot
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
[bool]$allPassed = $true

foreach ($scene in $selectedScenes) {
	[string]$smokeName = Get-SmokeName $scene
	[int]$frameBudget = if ($PSBoundParameters.ContainsKey("Frames")) { $Frames } elseif ($smokeName -eq "cart_transport") { 2400 } else { 360 }
	[string]$timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
	[string]$logPath = Join-Path $artifactDirectory "$smokeName-$timestamp.log"
	[string]$scenePath = $scene.FullName

	[string]$stdoutPath = "$logPath.stdout"
	[string]$stderrPath = "$logPath.stderr"
	[hashtable]$launch = @{
		FilePath = $godot
		ArgumentList = @("--headless", "--fixed-fps", "60", "--path", ('"' + $repositoryRoot + '"'), ('"' + $scenePath + '"'), "--quit-after", $frameBudget)
		RedirectStandardOutput = $stdoutPath
		RedirectStandardError = $stderrPath
		Wait = $true
		PassThru = $true
	}
	if ($env:OS -eq "Windows_NT") {
		$launch.WindowStyle = "Hidden"
	}
	# Native file redirects avoid Windows PowerShell turning stderr into terminating ErrorRecords.
	[System.Diagnostics.Process]$process = Start-Process @launch
	[int]$exitCode = $process.ExitCode
	[string[]]$nativeLines = @(Get-Content -LiteralPath @($stdoutPath, $stderrPath))
	[System.IO.File]::WriteAllLines($logPath, $nativeLines, [System.Text.Encoding]::UTF8)
	Remove-Item -LiteralPath @($stdoutPath, $stderrPath)
	[string[]]$logLines = @(Get-Content -LiteralPath $logPath)
	[string[]]$failures = @(Test-SmokeLog $logLines)
	if ($exitCode -ne 0) {
		$failures += "Godot exited with code $exitCode"
	}

	if ($failures.Count -eq 0) {
		Write-Output "PASS $smokeName ($logPath)"
	} else {
		$allPassed = $false
		Write-Output "FAIL $smokeName ($logPath)"
		$failures | Select-Object -Unique | ForEach-Object { Write-Output "  $_" }
	}
}

if (-not $allPassed) {
	exit 1
}
