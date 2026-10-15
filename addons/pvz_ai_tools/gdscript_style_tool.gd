@tool
extends RefCounted
## Inspect/apply only the project's pinned GDQuest EditorSettings; never format scripts.

const _CATEGORY: String = "gdquest_gdscript_formatter/"
const _EXPECTED_VERSION: String = "gdscript-formatter 0.26.2"


#region Pinned native formatter settings
## Synchronous calls retain no in-flight requests or editor objects between invocations.
func quiesce_for_script_swap() -> Dictionary:
	return { "ok": true }


## Only fixed native EditorSettings are accepted; these belong to the shared editor profile.
func configure(params: Dictionary, _context: McpCallContext) -> Dictionary:
	var action: String = String(params.get("action", "inspect"))
	if params.size() > 1 or not action in ["inspect", "apply"]:
		return { "error": "Expected action inspect or apply only." }
	if params.size() == 1 and not params.has("action"):
		return { "error": "Unknown style setting parameter." }
	var executable: String = ProjectSettings.globalize_path(
		(
			"res://.bin/gdscript-formatter.exe"
			if OS.has_feature("windows")
			else "res://.bin/gdscript-formatter"
		)
	)
	if not FileAccess.file_exists(executable):
		return { "error": "Pinned formatter binary is missing." }
	var output: Array[String] = []
	var exit_code: int = OS.execute(executable, PackedStringArray(["--version"]), output, true)
	if exit_code != 0 or output.is_empty() or output[0].strip_edges() != _EXPECTED_VERSION:
		return { "error": "Expected installed gdscript-formatter 0.26.2." }
	var expected: Dictionary[String, Variant] = {
		"formatter_path": executable,
		"use_spaces": false,
		"indent_size": 4,
		"format_on_save": false,
		"lint_on_save": true,
		"lint_line_length": 100,
		"lint_ignored_rules": "class-name",
		# The vendored addon still emits removed --safe in VERIFY_STRUCTURE mode.
		"format_mode": 0,
		"format_on_save_ignored_directories": PackedStringArray(["addons/"]),
	}
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var mismatches: Array[String] = []
	var current: Dictionary[String, Variant] = { }
	for option: String in expected:
		var setting_path: String = _CATEGORY + option
		if action == "apply":
			settings.set_setting(setting_path, expected[option])
		var configured: Variant = (
			settings.get_setting(setting_path)
			if settings.has_setting(setting_path)
			else null
		)
		current[option] = configured
		if configured != expected[option]:
			mismatches.append(option)
	# Native EditorSettings changes use the editor\'s normal persistence lifecycle.
	return {
		"data": {
			"ok": mismatches.is_empty(),
			"action": action,
			"settings": current,
			"mismatches": mismatches,
			"scripts_formatted": 0,
		},
	}
#endregion
