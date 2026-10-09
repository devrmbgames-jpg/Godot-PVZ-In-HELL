extends Node
## One-shot debug runtime teardown for ObjectDB inspection without quitting Godot.
## Autoload *nodes* cannot be freed at runtime; they remain inert while their
## runtime child nodes and known project-owned registries are released.

const DRAIN_FRAMES: int = 2

var _started: bool = false


func purge_runtime() -> void:
	if _started:
		return
	if not OS.is_debug_build() or Engine.is_editor_hint():
		push_error("kill game is only supported in a debug game runtime")
		queue_free()
		return
	_started = true

	var tree: SceneTree = get_tree()
	var root: Window = tree.root
	tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Phase 1: release gameplay while the Autoload services still exist.
	# In PVZ main_level's PREDELETE runs World.purge and releases ECS.world.
	if is_instance_valid(tree.current_scene):
		tree.unload_current_scene()
	for child: Node in root.get_children():
		if child == self or _is_autoload(child) or child.is_queued_for_deletion():
			continue
		child.queue_free()
	await _drain(tree)

	# An independent World may survive outside the unloaded current scene.
	var remaining_world: World = ECS.world
	if is_instance_valid(remaining_world):
		remaining_world.purge(false)
	ECS.world = null
	ECS.entity_preprocessors.clear()
	ECS.entity_postprocessors.clear()
	if is_instance_valid(remaining_world) and not remaining_world.is_queued_for_deletion():
		if remaining_world.is_inside_tree():
			remaining_world.queue_free()
		else:
			remaining_world.free()

	# Phase 2: stop every Autoload and release its owned runtime children.
	# Freeing the Autoload itself is explicitly unsupported by Godot.
	var autoload_names: PackedStringArray = []
	for child: Node in root.get_children():
		if child == self:
			continue
		if not _is_autoload(child):
			if not child.is_queued_for_deletion():
				child.queue_free()
			continue
		autoload_names.append(String(child.name))
		child.process_mode = Node.PROCESS_MODE_DISABLED
		child.set_process(false)
		child.set_physics_process(false)
		child.set_process_input(false)
		child.set_process_unhandled_input(false)
		child.set_process_unhandled_key_input(false)
		child.set_process_shortcut_input(false)
		for owned: Node in child.get_children():
			if not owned.is_queued_for_deletion():
				owned.queue_free()

	# These console registries contain Callables and references to debug objects.
	# Only clear them after the active console command/scene has completed.
	Console.console_commands.clear()
	Console.command_parameters.clear()
	Console.console_cvars.clear()
	Console.console_history.clear()

	await _drain(tree)
	print("DEBUG KILL GAME PURGE COMPLETE")
	print("Autoload shells kept (required by Godot): ", ", ".join(autoload_names))
	print("ObjectDB objects=", int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		" resources=", int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		" nodes=", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		" orphan_nodes=", int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	print("Take ObjectDB Snapshot in the editor debugger; the game process remains running.")
	queue_free()


func _drain(tree: SceneTree) -> void:
	for _frame: int in DRAIN_FRAMES:
		await tree.process_frame


## Keep only active Autoload nodes in /root; normal scene children are removable.
func _is_autoload(node: Node) -> bool:
	return (
		is_instance_valid(node)
		and node.get_parent() == get_tree().root
		and ProjectSettings.has_setting("autoload/%s" % String(node.name))
	)
