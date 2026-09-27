extends Node
## Registers project-owned developer commands without placing domain logic in the addon.
class_name DeveloperConsoleCommands

const ENABLE_SETTING: StringName = &"debug/developer_console_commands_enabled"
const RESOLVE_COMMAND: String = "debug_resolve"

var _registered_commands: PackedStringArray = []


func _ready() -> void:
	if not _commands_enabled():
		return
	_register_command(
		RESOLVE_COMMAND,
		_debug_resolve,
		["target"],
		1,
		"Resolve a developer-console target without mutating gameplay.",
	)
	Console.add_command_autocomplete_list(
		RESOLVE_COMMAND,
		PackedStringArray(["self", "target"]),
	)


func _exit_tree() -> void:
	for command: String in _registered_commands:
		Console.remove_command(command)
	_registered_commands.clear()


func _commands_enabled() -> bool:
	return (
		OS.is_debug_build()
		or bool(ProjectSettings.get_setting(ENABLE_SETTING, false))
	)


func _register_command(
	command: String,
	callback: Callable,
	arguments: Array,
	required: int,
	description: String,
) -> void:
	Console.add_command(command, callback, arguments, required, description)
	_registered_commands.append(command)


func _debug_resolve(raw_target: String) -> void:
	var target: DebugTarget = DebugTargetResolver.resolve(raw_target)
	if target.kind == DebugTarget.Kind.INVALID:
		DeveloperConsoleOutput.error(RESOLVE_COMMAND, target.error)
		return

	var details: PackedStringArray = [
		"query=%s" % target.query,
		"kind=%s" % DebugTarget.Kind.keys()[target.kind],
	]
	if target.entity != null and is_instance_valid(target.entity):
		details.append("entity=%s" % target.entity.id)
	if not target.package_id.is_empty():
		details.append("package_id=%s" % target.package_id)
	if target.registration != null:
		details.append("number=#%03d" % target.registration.number)
	if target.visit != null:
		details.append("visit=%s" % String(target.visit.visit_id))
	DeveloperConsoleOutput.ok(RESOLVE_COMMAND, details)
