"""Smoke completion must not hide native engine warnings or errors."""
from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("powershell"), "Windows PowerShell is required")
class SmokeLogGateTests(unittest.TestCase):
    def test_native_diagnostics_override_completion_line(self) -> None:
        script = r"""
$ErrorActionPreference = "Stop"
$tokens = $null
$parseErrors = $null
$syntax = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path (Get-Location) "utils/run_smoke.ps1"), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw "Smoke runner has invalid PowerShell syntax" }
$functions = $syntax.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -in @("Test-SmokeLog", "Test-IgnoredCertificateStoreError")
}, $true)
foreach ($function in $functions) { Invoke-Expression $function.Extent.Text }
$cases = @(
    @{ Name = "clean"; Lines = @("Physics smoke PASS"); Failed = $false },
    @{ Name = "warning"; Lines = @("Physics smoke PASS", "WARNING: ObjectDB instances leaked"); Failed = $true },
    @{ Name = "error"; Lines = @("Physics smoke PASS", "ERROR: resources still in use"); Failed = $true },
    @{ Name = "script"; Lines = @("Physics smoke PASS", "SCRIPT ERROR: Assertion failed"); Failed = $true },
    @{ Name = "incomplete"; Lines = @("Engine startup"); Failed = $true }
)
foreach ($case in $cases) {
    $failures = @(Test-SmokeLog $case.Lines)
    if (($failures.Count -gt 0) -ne $case.Failed) { throw ("Wrong gate outcome: " + $case.Name) }
    Write-Output ("PASS " + $case.Name)
}
"""
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", script],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("PASS "), 5, result.stdout)


if __name__ == "__main__":
    unittest.main()
