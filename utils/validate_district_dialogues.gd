extends SceneTree
## Сверяет исходники трёх диалогов района с native compiler и импортированными ресурсами.

const DIALOGUE_PATHS: Array[String] = [
	"res://content/domains/customers/dialogue/customer_service.dialogue",
	"res://content/domains/customers/dialogue/customer_prototype.dialogue",
	"res://content/domains/npc/dialogue/npc_street.dialogue",
]


#region Source и импортированный результат
func _init() -> void:
	_validate.call_deferred()


func _validate() -> void:
	var failures: int = 0
	for source_path: String in DIALOGUE_PATHS:
		if not FileAccess.file_exists(source_path):
			failures += 1
			push_error("Dialogue source missing: " + source_path)
			continue
		var result: DMCompilerResult = DMCompiler.compile_string(
			FileAccess.get_file_as_string(source_path),
			source_path,
		)
		if not result.errors.is_empty():
			failures += 1
			push_error("Dialogue compiler: %d errors in %s" % [result.errors.size(), source_path])
			continue
		var imported: DialogueResource = load(source_path) as DialogueResource
		if imported == null:
			failures += 1
			push_error("Dialogue import missing: " + source_path)
			continue
		var matches: bool = (
			imported.cues == result.cues and imported.first_cue == result.first_cue
			and imported.lines == result.lines and imported.using_states == result.using_states
			and imported.character_names == result.character_names
		)
		if not matches:
			failures += 1
			push_error("Dialogue imported data differs from current source: " + source_path)
		else:
			print("Dialogue source/import: PASS ", source_path)
		DialogueResourceLifecycle.release_runtime_references(imported)
	print("District dialogue acceptance: %d checked, %d failed" % [DIALOGUE_PATHS.size(), failures])
	quit(1 if failures > 0 else 0)
#endregion
