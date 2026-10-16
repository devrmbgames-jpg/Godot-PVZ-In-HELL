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

    def test_result_classifies_completion_and_exact_terminal_resource_diagnostics(self) -> None:
        self.run_contract(r"""
foreach ($name in @('Get-GodotDiagnostics', 'Get-GodotValidationResult')) {
    $definition = $ast.Find({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $name
    }, $true)
    if ($null -eq $definition) { throw "Missing result contract: $name" }
    Invoke-Expression $definition.Extent.Text
}
$success = @('Tests                 2', 'Passing Tests         2', '---- All tests passed! ----')
$known = @('ERROR: 12 resources still in use at exit (run with --verbose for details).',
           '   at: clear (core/io/resource.cpp:822)')
foreach ($case in @(
    @{Out=$success; Err=@(); Action='GUT'; Functional='PASS'; Diagnostic='CLEAN'},
    @{Out=$success; Err=$known; Action='GUT'; Functional='PASS'; Diagnostic='KNOWN_ENGINE_LIMITATION'},
    @{Out=@('Changed-script parser: PASS (2 files, 0 failures)'); Err=$known;
      Action='ParseFiles'; Functional='PASS'; Diagnostic='KNOWN_ENGINE_LIMITATION'},
    @{Out=$success; Err=@('WARNING: 12 ObjectDB instances were leaked at exit (run with `--verbose` for details).',
      '   at: cleanup (core/object/object.cpp:2536)'); Action='GUT'; Functional='UNKNOWN'; Diagnostic='UNKNOWN'},
    @{Out=$success; Err=@('WARNING: live Node leaked'); Action='GUT'; Functional='FAIL'; Diagnostic='FAIL'},
    @{Out=$success; Err=@('WARNING: unexplained runtime state'); Action='GUT'; Functional='UNKNOWN'; Diagnostic='UNKNOWN'},
    @{Out=$success; Err=@('RID'); Action='GUT'; Functional='UNKNOWN'; Diagnostic='UNKNOWN'},
    @{Out=@(); Err=$known; Action='GUT'; Functional='UNKNOWN'; Diagnostic='UNKNOWN'},
    @{Out=@('Tests 2', 'Passing Tests 1', '---- All tests passed! ----'); Err=@();
      Action='GUT'; Functional='UNKNOWN'; Diagnostic='CLEAN'},
    @{Out=@('---- All tests passed! ----'); Err=@(); Action='GUT'; Functional='UNKNOWN'; Diagnostic='CLEAN'},
    @{Out=@('Import complete'); Err=$known; Action='Import'; Functional='UNKNOWN'; Diagnostic='UNKNOWN'},
    @{Out=$success; Err=@('ERROR: 12 resources still in use at exit (run with --verbose for details).',
      '   at: arbitrary_runtime_call (res://actor.gd:4)'); Action='GUT'; Functional='FAIL'; Diagnostic='FAIL'},
    @{Out=$success; Err=@($known + 'SCRIPT ERROR: Broken call'); Action='GUT'; Functional='FAIL'; Diagnostic='FAIL'},
    @{Out=$success; Err=@($known + 'ERROR: live RID pool corrupted'); Action='GUT'; Functional='FAIL'; Diagnostic='FAIL'}
)) {
    $result = Get-GodotValidationResult $case.Out $case.Err $case.Action 0
    if ($result.FunctionalStatus -ne $case.Functional -or $result.DiagnosticStatus -ne $case.Diagnostic) {
        throw ('Wrong classification: ' + ($case | ConvertTo-Json -Compress) + ' => ' + ($result | ConvertTo-Json -Compress))
    }
}
foreach ($mode in @('exit', 'timeout')) {
    $exitCode = if ($mode -eq 'exit') { 1 } else { 0 }
    $result = Get-GodotValidationResult $success $known 'GUT' $exitCode ($mode -eq 'timeout')
    if ($result.FunctionalStatus -ne 'FAIL') { throw "Accepted $mode failure" }
}
$result = Get-GodotValidationResult $success @() 'GUT' $null
if ($result.FunctionalStatus -ne 'UNKNOWN') { throw 'Missing native exit code became success' }
""")

    def test_result_keeps_expected_negative_contract_local_and_preserves_input(self) -> None:
        self.run_contract(r"""
foreach ($name in @('Get-GodotDiagnostics', 'Get-GodotValidationResult')) {
    $definition = $ast.Find({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $name
    }, $true)
    if ($null -eq $definition) { throw "Missing result contract: $name" }
    Invoke-Expression $definition.Extent.Text
}
$success = @('Tests 1', 'Passing Tests 1', '---- All tests passed! ----')
$confirmation = "[ExpectedError]Expected engine error containing 'ConfigFile parse error at user://slot'."
$native = 'ERROR: ConfigFile parse error at user://slot:2: EOF.'
$stdout = @($success + $confirmation)
$stderr = @($native, '   at: _parse (core/io/config_file.cpp:298)')
$before = @($stdout, $stderr) | ConvertTo-Json -Depth 4 -Compress
$result = Get-GodotValidationResult $stdout $stderr 'GUT' 0
if ($result.FunctionalStatus -ne 'PASS') { throw 'Expected-negative fixture rejected' }
if ((@($stdout, $stderr) | ConvertTo-Json -Depth 4 -Compress) -ne $before) { throw 'Raw input mutated' }
$result = Get-GodotValidationResult $stdout @($stderr + 'ERROR: different failure') 'GUT' 0
if ($result.FunctionalStatus -ne 'FAIL') { throw 'Expected fixture hid an unrelated error' }
$result = Get-GodotValidationResult $success $stderr 'GUT' 0
if ($result.FunctionalStatus -ne 'FAIL') { throw 'Unconfirmed error accepted' }
""")

    def test_real_gut_orphan_reports_cannot_pass_with_green_test_totals(self) -> None:
        self.run_contract(r"""
foreach ($name in @('Get-GodotDiagnostics', 'Get-GodotValidationResult')) {
    $definition = $ast.Find({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $name
    }, $true)
    Invoke-Expression $definition.Extent.Text
}
$success = @('Tests 2', 'Passing Tests 2', '---- All tests passed! ----')
$known = @('ERROR: 12 resources still in use at exit (run with --verbose for details).',
           '   at: clear (core/io/resource.cpp:822)')
foreach ($report in @('Orphans             1', '    [Orphans]  1 Orphans', '    [Orphans]  2 orphans')) {
    foreach ($stderr in @(@(), $known)) {
        $result = Get-GodotValidationResult @($success + $report) $stderr 'GUT' 0
        if ($result.FunctionalStatus -eq 'PASS' -or $result.DiagnosticStatus -eq 'CLEAN') {
            throw "Live orphan report accepted: $report"
        }
    }
}
""")

    def test_timeout_cleanup_targets_owned_pid_tree(self) -> None:
        self.run_contract(r"""
$definition = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Stop-GodotValidationProcess'
}, $true)
if ($null -eq $definition) { throw 'Missing owned process-tree cleanup' }
Invoke-Expression $definition.Extent.Text
$env:OS = 'Windows_NT'
$script:observedArguments = @()
function Get-CimInstance { @() }
function taskkill.exe {
    $script:observedArguments = @($args)
    $global:LASTEXITCODE = 0
}
Stop-GodotValidationProcess ([pscustomobject]@{Id=12345; HasExited=$false})
if (($script:observedArguments -join ' ') -ne '/PID 12345 /T /F') {
    throw 'Cleanup did not target exactly the owned process tree'
}
$script:observedArguments = @()
Stop-GodotValidationProcess ([pscustomobject]@{Id=12345; HasExited=$true})
if ($script:observedArguments.Count -gt 0) { throw 'Already exited root was terminated again' }
""")

    def test_changed_selection_includes_companion_and_excludes_vendor(self) -> None:
        self.run_contract(r"""
$assignment = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left.Extent.Text -eq '$selected' -and
    $node.Right.Extent.Text.Contains('$changed')
}, $true)
$changed = @('content/a.gd', 'addons/gecs/vendor.gd', 'content/a.gd', 'content/a.tscn')
$untracked = @('addons/pvz_ai_tools/new.gd', 'addons/project_entity_traits/new.gd',
               'addons/godot_ai/vendor.gd', 'content/b.gd')
Invoke-Expression $assignment.Extent.Text
if (($selected -join ',') -ne 'addons/project_entity_traits/new.gd,addons/pvz_ai_tools/new.gd,content/a.gd,content/b.gd') {
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

    def test_exact_expected_configfile_errors_require_successful_gut_and_matching_counts(self) -> None:
        self.run_contract(r"""
$function = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Get-GodotDiagnostics'
}, $true)
Invoke-Expression $function.Extent.Text
$prefix = 'ConfigFile parse error at user://isolated/slot.pvzh'
$confirmation = "[ExpectedError]Expected engine error containing '$prefix'.  "
$native = "ERROR: ${prefix}:1: Unexpected EOF."
$empty = @(Get-GodotDiagnostics @($confirmation) @($native) 'GUT' 0)
if ($empty.Count -ne 0) { throw 'Matching expected native diagnostic was rejected' }
foreach ($mode in @('ParseChanged', 'OfflineScript')) {
    $rejected = @(Get-GodotDiagnostics @($confirmation) @($native) $mode 0)
    if ($rejected.Count -eq 0) { throw "Non-GUT $mode accepted expected errors" }
}
$rejected = @(Get-GodotDiagnostics @($confirmation) @($native) 'GUT' 1)
if ($rejected.Count -eq 0) { throw 'Failing GUT accepted expected errors' }
foreach ($case in @(
    @{Out=@($confirmation); Err=@($native, $native)},
    @{Out=@($confirmation, $confirmation); Err=@($native)},
    @{Out=@(); Err=@($native)},
    @{Out=@($confirmation); Err=@()},
    @{Out=@($confirmation); Err=@('ERROR: ConfigFile parse error at user://different:1: EOF.')}
)) {
    $rejected = @(Get-GodotDiagnostics $case.Out $case.Err 'GUT' 0)
    if ($rejected.Count -eq 0) { throw 'Unmatched diagnostic/count/path was accepted' }
}
""")

    def test_expected_configfile_errors_do_not_hide_other_errors_or_script_diagnostics(self) -> None:
        self.run_contract(r"""
$function = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Get-GodotDiagnostics'
}, $true)
Invoke-Expression $function.Extent.Text
$confirmation = "[ExpectedError]Expected engine error containing 'ConfigFile parse error at user://slot'."
$native = 'ERROR: ConfigFile parse error at user://slot:2: EOF.'
$escape = [char]27
$colored = "${escape}[34m[ExpectedError]${escape}[0m" + $confirmation.Substring(15)
if (@(Get-GodotDiagnostics @($colored) @($native) 'GUT' 0).Count -ne 0) {
    throw 'ANSI expected-error marker did not match'
}
foreach ($unexpected in @('SCRIPT ERROR: Broken call', 'Parse Error: Invalid type',
                         'ERROR: Unexpected object', 'Assertion failed')) {
    $diagnostics = @(Get-GodotDiagnostics @($confirmation) @($native, $unexpected) 'GUT' 0)
    if ($diagnostics.Count -ne 1 -or $diagnostics[0] -ne $unexpected) {
        throw 'An unexpected diagnostic was hidden'
    }
}
$generic = "[ExpectedError]Expected engine error containing 'Unexpected object'."
if (@(Get-GodotDiagnostics @($generic) @('ERROR: Unexpected object') 'GUT' 0).Count -eq 0) {
    throw 'An arbitrary expected-error marker bypassed the runner'
}
""")

    def test_counts_cover_both_streams_before_combined_stream_suppression(self) -> None:
        self.run_contract(r"""
$function = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Get-GodotDiagnostics'
}, $true)
Invoke-Expression $function.Extent.Text
$confirmation = "[ExpectedError]Expected engine error containing 'ConfigFile parse error at user://slot'."
$native = 'ERROR: ConfigFile parse error at user://slot:2: EOF.'
foreach ($case in @(
    @{Out=@($confirmation, $native); Err=@($native)},
    @{Out=@($confirmation); Err=@($native, $confirmation)}
)) {
    if (@(Get-GodotDiagnostics $case.Out $case.Err 'GUT' 0).Count -eq 0) {
        throw 'An uncounted diagnostic/marker in the other stream was suppressed'
    }
}
if (@(Get-GodotDiagnostics @($native) @($confirmation) 'GUT' 0).Count -ne 0) {
    throw 'Exactly matched reversed streams did not pass'
}
""")


if __name__ == "__main__":
    unittest.main()
