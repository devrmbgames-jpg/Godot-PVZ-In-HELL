extends Node
## Registers project-owned developer commands without placing domain logic in the addon.
class_name DeveloperConsoleCommands

const ENABLE_SETTING: StringName = &"debug/developer_console_commands_enabled"
const RESOLVE_COMMAND: String = "debug_resolve"
const PACKAGE_LIST_COMMAND: String = "pkg_list"
const PACKAGE_INFO_COMMAND: String = "pkg_info"
const VISIT_INFO_COMMAND: String = "visit_info"
const WALLET_INFO_COMMAND: String = "wallet_info"
const HEALTH_INFO_COMMAND: String = "health_info"
const PACKAGE_SPAWN_COMMAND: String = "pkg_spawn"
const PACKAGE_REMOVE_COMMAND: String = "pkg_remove"
const PACKAGE_PURGE_COMMAND: String = "pkg_purge"
const PACKAGE_REGISTER_COMMAND: String = "pkg_register"

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
	_register_command(
		PACKAGE_LIST_COMMAND,
		_pkg_list,
		["active|all"],
		0,
		"List package identities, registration and live condition.",
	)
	_register_command(
		PACKAGE_INFO_COMMAND,
		_pkg_info,
		["package"],
		1,
		"Show package, visit and condition details.",
	)
	_register_command(
		VISIT_INFO_COMMAND,
		_visit_info,
		["package|visit"],
		1,
		"Show persistent CustomerVisit/dispute details.",
	)
	_register_command(
		WALLET_INFO_COMMAND,
		_wallet_info,
		[],
		0,
		"Show wallet and current-day totals.",
	)
	_register_command(
		HEALTH_INFO_COMMAND,
		_health_info,
		["target"],
		0,
		"Show Health/death state. Defaults to self.",
	)
	_register_command(
		PACKAGE_SPAWN_COMMAND,
		_pkg_spawn,
		["definition_key", "count", "receiving|self", "registered"],
		1,
		"Spawn debug Package instances from an existing definition.",
	)
	_register_command(
		PACKAGE_REMOVE_COMMAND,
		_pkg_remove,
		["package"],
		1,
		"Remove only the live physical Package.",
	)
	_register_command(
		PACKAGE_PURGE_COMMAND,
		_pkg_purge,
		["package"],
		1,
		"Purge safe debug-created Package state.",
	)
	_register_command(
		PACKAGE_REGISTER_COMMAND,
		_pkg_register,
		["package"],
		1,
		"Register a live Package without Scanner gesture.",
	)
	var common_targets: PackedStringArray = PackedStringArray(["self", "target"])
	Console.add_command_autocomplete_list(RESOLVE_COMMAND, common_targets)
	Console.add_command_autocomplete_list(HEALTH_INFO_COMMAND, common_targets)
	Console.add_command_autocomplete_list(PACKAGE_LIST_COMMAND, PackedStringArray(["active", "all"]))


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



func _pkg_list(scope: String = "") -> void:
	var normalized: String = scope.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = "active"
	if normalized != "active" and normalized != "all":
		DeveloperConsoleOutput.error(
			PACKAGE_LIST_COMMAND,
			"scope must be active or all",
		)
		return
	DeveloperConsoleOutput.ok(
		PACKAGE_LIST_COMMAND,
		DeveloperConsoleDiagnostics.package_list(normalized == "all"),
	)


func _pkg_info(raw_target: String) -> void:
	var target: DebugTarget = DebugTargetResolver.resolve(raw_target)
	if target.kind != DebugTarget.Kind.PACKAGE:
		DeveloperConsoleOutput.error(
			PACKAGE_INFO_COMMAND,
			target.error if not target.error.is_empty() else "target is not a package",
		)
		return
	DeveloperConsoleOutput.ok(
		PACKAGE_INFO_COMMAND,
		DeveloperConsoleDiagnostics.package_info(target),
	)


func _visit_info(raw_target: String) -> void:
	var target: DebugTarget = DebugTargetResolver.resolve(raw_target)
	if target.visit == null:
		DeveloperConsoleOutput.error(
			VISIT_INFO_COMMAND,
			target.error if not target.error.is_empty() else "target has no CustomerVisit",
			"visit_create <package>",
		)
		return
	DeveloperConsoleOutput.ok(
		VISIT_INFO_COMMAND,
		DeveloperConsoleDiagnostics.visit_info(target.visit),
	)


func _wallet_info() -> void:
	DeveloperConsoleOutput.ok(
		WALLET_INFO_COMMAND,
		DeveloperConsoleDiagnostics.wallet_info(),
	)


func _health_info(raw_target: String = "") -> void:
	var normalized: String = raw_target.strip_edges()
	if normalized.is_empty():
		normalized = "self"
	var target: DebugTarget = DebugTargetResolver.resolve(normalized)
	if target.kind == DebugTarget.Kind.INVALID:
		DeveloperConsoleOutput.error(HEALTH_INFO_COMMAND, target.error)
		return
	if not EntityAvailability.contains(target.entity, ECS.world):
		DeveloperConsoleOutput.error(
			HEALTH_INFO_COMMAND,
			"target has no live Entity",
		)
		return
	DeveloperConsoleOutput.ok(
		HEALTH_INFO_COMMAND,
		DeveloperConsoleDiagnostics.health_info(target),
	)



func _pkg_spawn(
	definition_key: String,
	count_text: String = "",
	mode_text: String = "",
	registered_text: String = "",
) -> void:
	var count: int = 1
	if not count_text.strip_edges().is_empty():
		if not count_text.is_valid_int():
			DeveloperConsoleOutput.error(PACKAGE_SPAWN_COMMAND, "count must be an integer")
			return
		count = count_text.to_int()
	var mode: String = mode_text.strip_edges().to_lower()
	if mode.is_empty():
		mode = DebugPackageService.MODE_RECEIVING
	var register_packages: bool = false
	if not registered_text.strip_edges().is_empty():
		if registered_text != "0" and registered_text != "1":
			DeveloperConsoleOutput.error(
				PACKAGE_SPAWN_COMMAND,
				"registered must be 0 or 1",
			)
			return
		register_packages = registered_text == "1"

	var result: DebugServiceResult = DebugPackageService.spawn(
		StringName(definition_key),
		count,
		mode,
		register_packages,
	)
	_print_service_result(PACKAGE_SPAWN_COMMAND, result)


func _pkg_remove(raw_target: String) -> void:
	_print_service_result(
		PACKAGE_REMOVE_COMMAND,
		DebugPackageService.remove(DebugTargetResolver.resolve(raw_target)),
	)


func _pkg_purge(raw_target: String) -> void:
	_print_service_result(
		PACKAGE_PURGE_COMMAND,
		DebugPackageService.purge(DebugTargetResolver.resolve(raw_target)),
	)


func _pkg_register(raw_target: String) -> void:
	_print_service_result(
		PACKAGE_REGISTER_COMMAND,
		DebugPackageService.register(DebugTargetResolver.resolve(raw_target)),
	)


func _print_service_result(command: String, result: DebugServiceResult) -> void:
	if result.success:
		var details: PackedStringArray = PackedStringArray([result.message])
		details.append_array(result.details)
		DeveloperConsoleOutput.ok(command, details)
		return
	DeveloperConsoleOutput.error(command, result.message)
