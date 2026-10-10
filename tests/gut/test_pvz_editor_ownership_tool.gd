extends GutTest
## Covers pure formatting of editor-owned scenes without launching the GUI editor.

const EditorOwnershipTool = preload("res://addons/pvz_ai_tools/editor_ownership_tool.gd")


#region Dirty scene protection
func test_reports_unsaved_current_and_other_scenes() -> void:
	var open_paths: PackedStringArray = PackedStringArray([
		"res://content/scenes/main_level.tscn",
		"res://content/domains/npc/entities/district_npc.tscn",
	])
	var unsaved_paths: PackedStringArray = PackedStringArray([
		"res://content/scenes/main_level.tscn",
	])
	var report: Dictionary = EditorOwnershipTool.describe(
		open_paths,
		unsaved_paths,
		"res://content/scenes/main_level.tscn",
	)

	assert_true(report["current_scene_unsaved"])
	assert_true(report["has_unsaved_scenes"])
	assert_eq(report["unsaved_count"], 1)
	assert_eq((report["open_scenes"] as Array).size(), 2)
	assert_eq(report["unsaved_scenes"], ["res://content/scenes/main_level.tscn"])


func test_other_dirty_scene_is_not_silently_treated_as_safe_to_close() -> void:
	var report: Dictionary = EditorOwnershipTool.describe(
		PackedStringArray(["res://current.tscn", "res://other.tscn"]),
		PackedStringArray(["res://other.tscn"]),
		"res://current.tscn",
	)
	assert_false(report["current_scene_unsaved"])
	assert_true(report["has_unsaved_scenes"])
	assert_eq(report["unsaved_count"], 1)


func test_clean_and_unsaved_new_scene_are_distinct() -> void:
	var clean: Dictionary = EditorOwnershipTool.describe(
		PackedStringArray(["res://current.tscn"]),
		PackedStringArray(),
		"res://current.tscn",
	)
	assert_false(clean["has_unsaved_scenes"])
	assert_false(clean["current_scene_unsaved"])

	var new_unsaved: Dictionary = EditorOwnershipTool.describe(
		PackedStringArray([""]),
		PackedStringArray([""]),
		"",
	)
	assert_true(new_unsaved["has_unsaved_scenes"])
	assert_false(new_unsaved["current_scene_unsaved"])
#endregion
