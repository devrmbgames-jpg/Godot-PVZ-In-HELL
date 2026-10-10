extends GutTest
## Diagnostic cleanup preserves authored translation sources and rejects arbitrary mutations.

const TOOL: Script = preload("res://addons/pvz_ai_tools/translation_sources_tool.gd")
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
