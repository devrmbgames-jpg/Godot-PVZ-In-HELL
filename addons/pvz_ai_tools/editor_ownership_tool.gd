@tool
extends RefCounted
## Read-only live editor ownership/dirty-scene guard for scene-authoring agents.


## Reports the current scene, every open scene and unsaved editor scene.
## A blank scene path represents a scene not yet saved to a file.
func inspect(_params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var current_scene: String = String(scene_root.scene_file_path) if scene_root != null else ""
	var open_paths: PackedStringArray = EditorInterface.get_open_scenes()
	var unsaved_paths: PackedStringArray = EditorInterface.get_unsaved_scenes()

	var report: Dictionary = describe(open_paths, unsaved_paths, current_scene)
	report["ok"] = true
	report["editor_connected"] = true
	return { "data": report }


## Pure formatting lets non-editor GUT tests cover the safety contract.
static func describe(
	open_paths: PackedStringArray,
	unsaved_paths: PackedStringArray,
	current_scene: String,
) -> Dictionary:
	var open_scenes: Array[String] = []
	for open_path: String in open_paths:
		open_scenes.append(open_path)
	var unsaved_scenes: Array[String] = []
	for unsaved_path: String in unsaved_paths:
		unsaved_scenes.append(unsaved_path)

	return {
		"current_scene": current_scene,
		"open_scenes": open_scenes,
		"unsaved_scenes": unsaved_scenes,
		"current_scene_unsaved": (
			unsaved_paths.has(current_scene) if not current_scene.is_empty() else false
		),
		"has_unsaved_scenes": not unsaved_paths.is_empty(),
		"unsaved_count": unsaved_paths.size(),
		"note": "Read-only editor-side scene state; plugins may have additional unsaved external data.",
	}
