@tool
extends RefCounted
## Native, bounded removal of vanished diagnostic dialogue copies from translation sources.

const _KEY: String = "internationalization/locale/translations_pot_files"
const _SNAPSHOTS: PackedStringArray = [
	"direct_traits_baseline",
	"retention_baseline_snapshot",
	"retention_current_snapshot",
	"retention_first_checkpoint",
]
const _DIALOGUES: PackedStringArray = [
	"content/domains/customers/dialogue/customer_prototype.dialogue",
	"content/domains/customers/dialogue/customer_service.dialogue",
	"content/domains/npc/dialogue/npc_street.dialogue",
]


#region Native operation
## No retained requests or editor objects; safe to hot-swap between synchronous calls.
func quiesce_for_script_swap() -> Dictionary:
	return { "ok": true }


## Only preview/apply of the fixed diagnostic catalog is allowed; no arbitrary settings.
## Apply saves ProjectSettings before pruning DMCache; no removals means no save.
func configure(params: Dictionary, _context: McpCallContext) -> Dictionary:
	var action: String = String(params.get("action", "preview"))
	if params.size() != 1 or not params.has("action") or action not in ["preview", "apply"]:
		return { "error": "Expected only action preview or apply." }
	if not Engine.is_editor_hint():
		return { "error": "Translation-source cleanup requires the native editor." }
	var original: Variant = ProjectSettings.get_setting(_KEY, PackedStringArray())
	if not original is PackedStringArray:
		return { "error": "Translation sources must retain PackedStringArray type." }
	var sources: PackedStringArray = original
	var existing: PackedStringArray = []
	for source: String in sources:
		if FileAccess.file_exists(source):
			existing.append(source)
	var retained: PackedStringArray = retained_sources(sources, existing)
	var removed: PackedStringArray = []
	for source: String in sources:
		if not retained.has(source):
			removed.append(source)
	if action == "apply" and not removed.is_empty():
		ProjectSettings.set_setting(_KEY, retained)
		var save_error: Error = ProjectSettings.save()
		if save_error != OK:
			ProjectSettings.set_setting(_KEY, sources)
			return { "error": "Could not save native translation sources.", "code": save_error }
		# Prevent a later native localization update from reintroducing vanished copies.
		for source: String in removed:
			DMCache.move_file_path(source, "")
	return {
		"data": {
			"action": action,
			"removed": removed,
			"retained": retained,
			"type": "PackedStringArray",
			"saved": action == "apply" and not removed.is_empty(),
		}
	}
#endregion


#region Fixed catalog filter
## Retain authored/custom sources and existing files; prune only vanished known copies.
static func retained_sources(
	sources: PackedStringArray,
	existing: PackedStringArray,
) -> PackedStringArray:
	var removable: PackedStringArray = []
	for snapshot: String in _SNAPSHOTS:
		for dialogue: String in _DIALOGUES:
			removable.append("res://.bin/%s/%s" % [snapshot, dialogue])
	var retained: PackedStringArray = []
	for source: String in sources:
		if not removable.has(source) or existing.has(source):
			retained.append(source)
	return retained
#endregion
