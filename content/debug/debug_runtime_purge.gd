extends Node
## One-shot debug runtime teardown for ObjectDB inspection without quitting Godot.
## Autoload *nodes* cannot be freed at runtime; they remain inert while their
## runtime child nodes and known project-owned registries are released.

const DRAIN_FRAMES: int = 2

var _started: bool = false
var _quitting: bool = false
var _exit_controls_ready: bool = false


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
	_show_exit_ui()
	if not root.close_requested.is_connected(_request_quit):
		root.close_requested.connect(_request_quit)
	set_process_input(true)


## Stay outside gameplay and outside disabled Autoloads so input still works.
## This intentionally creates a few UI objects AFTER memory metrics are printed.
func _show_exit_ui() -> void:
	if _exit_controls_ready:
		return
	_exit_controls_ready = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "RuntimePurgeExitOverlay"
	canvas.layer = 100
	add_child(canvas)

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.035, 0.045, 0.060, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title: Label = Label.new()
	title.text = "DEBUG: Runtime purged"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var instructions: Label = Label.new()
	instructions.text = "1. Take ObjectDB Snapshot in Godot Editor.\n2. Press the button below to quit Godot normally.\nThe runtime is no longer playable."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(instructions)

	var exit_button: Button = Button.new()
	exit_button.name = "ExitAfterSnapshot"
	exit_button.text = "Exit Godot (graceful shutdown)"
	exit_button.custom_minimum_size.y = 48
	exit_button.pressed.connect(_request_quit)
	column.add_child(exit_button)
	exit_button.grab_focus()


## Escape is independent of the removed console and disabled InputHelper.
func _input(event: InputEvent) -> void:
	if not _exit_controls_ready or _quitting:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	_request_quit()


## Exit via the button, Escape, or the window close request.
## SceneTree.quit() runs Godot's normal teardown and verbose leak diagnostics.
func _request_quit() -> void:
	if _quitting or not OS.is_debug_build():
		return
	_quitting = true
	print("DEBUG KILL GAME EXIT REQUESTED (SceneTree.quit)")
	get_tree().quit(0)


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
