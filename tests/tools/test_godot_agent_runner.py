"""Execute the runner's PowerShell contracts without importing or opening Godot."""
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell")


@unittest.skipUnless(POWERSHELL, "PowerShell host unavailable")
class GodotAgentRunnerTests(unittest.TestCase):
    def run_contract(self, body: str) -> None:
        script = r"""
$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path (Get-Location) 'utils/godot_agent.ps1'),
    [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw ($parseErrors.Message -join '; ') }
""" + body
        result = subprocess.run(
            [POWERSHELL, "-NoProfile", "-NonInteractive", "-Command", script],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_runner_parses_with_native_powershell(self) -> None:
        self.run_contract("")

    def test_changed_selection_includes_companion_and_excludes_vendor(self) -> None:
        self.run_contract(r"""
$assignment = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left.Extent.Text -eq '$selected' -and
    $node.Right.Extent.Text.Contains('$changed')
}, $true)
$changed = @('content/a.gd', 'addons/gecs/vendor.gd', 'content/a.gd', 'content/a.tscn')
$untracked = @('addons/pvz_ai_tools/new.gd', 'addons/godot_ai/vendor.gd', 'content/b.gd')
Invoke-Expression $assignment.Extent.Text
if (($selected -join ',') -ne 'addons/pvz_ai_tools/new.gd,content/a.gd,content/b.gd') {
    throw ('Incorrect changed-script selection: ' + ($selected -join ','))
}
""")

    def test_offline_guard_recognizes_both_editor_flags_and_foreign_project(self) -> None:
        self.run_contract(r"""
$guard = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Test-ProjectEditorOpen'
}, $true)
Invoke-Expression $guard.Extent.Text
$env:OS = 'Windows_NT'
function Get-CimInstance { @([pscustomobject]@{CommandLine=$script:fakeCommand}) }
foreach ($flag in @('--editor', '-e')) {
    $script:fakeCommand = 'Godot.exe --path "D:\project" ' + $flag
    if (-not (Test-ProjectEditorOpen -ProjectDir 'D:\project')) {
        throw ('Missed editor flag: ' + $flag)
    }
}
$script:fakeCommand = 'Godot.exe --path "D:\foreign" --editor'
if (Test-ProjectEditorOpen -ProjectDir 'D:\project') { throw 'Foreign editor blocked project' }
$script:fakeCommand = 'Godot.exe --path "D:\project" --headless'
if (Test-ProjectEditorOpen -ProjectDir 'D:\project') { throw 'Headless process treated as editor' }
""")

    def test_offline_guard_refuses_unverifiable_process_state(self) -> None:
        self.run_contract(r"""
$guard = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Test-ProjectEditorOpen'
}, $true)
Invoke-Expression $guard.Extent.Text
$env:OS = 'Windows_NT'
function Get-CimInstance { throw 'Process metadata unavailable' }
try {
    Test-ProjectEditorOpen -ProjectDir 'D:\project'
} catch {
    if ($_.Exception.Message -like 'Cannot verify Godot Editor ownership;*') { exit 0 }
    throw
}
throw 'Unverifiable ownership did not block offline mutation'
""")


if __name__ == "__main__":
    unittest.main()
