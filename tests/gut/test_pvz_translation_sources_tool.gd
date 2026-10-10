extends GutTest
## Diagnostic cleanup preserves authored translation sources and rejects arbitrary mutations.

const TOOL: Script = preload("res://addons/pvz_ai_tools/translation_sources_tool.gd")
## The pinned private scanner is invoked reflectively only at this regression-test boundary.
const DIALOGUE_CACHE: Script = preload("res://addons/dialogue_manager/utilities/dialogue_cache.gd")
const STALE: String = (
	"res://.bin/retention_baseline_snapshot/" + "content/domains/npc/dialogue/npc_street.dialogue"
)


#region Fixed source filtering
func test_missing_diagnostic_copy_is_removed_but_custom_sources_are_retained() -> void:
	var authored: String = "res://content/domains/npc/dialogue/npc_street.dialogue"
	var unknown: String = "res://" + ".bin/foreign/content/domains/npc/dialogue/npc_street.dialogue"
	var translation: String = "res://content/ui/main_menu.tscn"
	var sources: PackedStringArray = [authored, STALE, unknown, translation]
	var retained: PackedStringArray = TOOL.retained_sources(sources, PackedStringArray())
	assert_eq(retained, PackedStringArray([authored, unknown, translation]))
	assert_eq(sources.size(), 4, "Pure preview does not mutate the caller's source array")


func test_existing_diagnostic_copy_is_retained_and_filter_is_idempotent() -> void:
	var sources: PackedStringArray = [STALE]
	var existing: PackedStringArray = [STALE]
	assert_eq(TOOL.retained_sources(sources, existing), sources)
	var removed: PackedStringArray = TOOL.retained_sources(sources, PackedStringArray())
	assert_true(removed.is_empty())
	assert_eq(TOOL.retained_sources(removed, existing), removed)


func test_unknown_parameters_and_actions_reject_before_editor_mutation() -> void:
	var handler: RefCounted = TOOL.new()
	for params: Dictionary in [
		{ },
		{ "action": "write" },
		{ "key": "autoload/X" },
		{ "action": "apply", "key": "other" },
	]:
		assert_true((handler.configure(params, null) as Dictionary).has("error"))
#endregion


#region Native scanner regression
## Exercise the pinned scanner, which does not honor Godot's .gdignore files.
func test_native_scanner_skips_tmp_copies_and_keeps_ordinary_dialogue() -> void:
	var fixture_root: String = "user://gut_pvz_translation_scan_%d" % OS.get_process_id()
	var hidden_root: String = fixture_root + "/.tmp"
	assert_eq(DirAccess.make_dir_recursive_absolute(hidden_root), OK)
	var ordinary: String = fixture_root + "/ordinary.dialogue"
	var copied: String = hidden_root + "/copied.dialogue"
	for path: String in [ordinary, copied]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		assert_not_null(file)
		if file == null:
			return
		file.store_string("Scanner fixture only")
		file.close()
	var scanned: PackedStringArray = DIALOGUE_CACHE.call(
		"_get_dialogue_files_in_filesystem", fixture_root,
	)
	assert_eq(scanned, PackedStringArray([ordinary]))
	for path: String in [ordinary, copied, hidden_root, fixture_root]:
		assert_eq(DirAccess.remove_absolute(path), OK)


## The same scan used by a fresh editor cannot reintroduce preserved project snapshots.
func test_project_scan_excludes_the_relocated_diagnostic_catalog() -> void:
	var scanned: PackedStringArray = DIALOGUE_CACHE.call("_get_dialogue_files_in_filesystem")
	var configured: Variant = ProjectSettings.get_setting(
		"internationalization/locale/translations_pot_files",
	)
	assert_true(configured is PackedStringArray)
	if not configured is PackedStringArray:
		return
	var sources: PackedStringArray = configured
	assert_true(scanned.has("res://content/domains/npc/dialogue/npc_street.dialogue"))
	for path: String in scanned:
		assert_false(path.begins_with("res://.artifacts/godot_agent/"))
		assert_false(path.begins_with("res://.bin/"))
		assert_true(sources.has(path), "Fresh-process settings retain every authored dialogue")
	for path: String in sources:
		assert_false(path.begins_with("res://.artifacts/godot_agent/"))
		assert_false(path.begins_with("res://.bin/"))
#endregion
