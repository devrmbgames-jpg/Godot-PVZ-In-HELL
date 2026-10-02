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
const VISIT_CREATE_COMMAND: String = "visit_create"
const PACKAGE_ACTUAL_COMMAND: String = "pkg_actual"
const PACKAGE_DECLARE_COMMAND: String = "pkg_declare"
const PACKAGE_COMPLAINT_COMMAND: String = "pkg_complaint"
const COMPLAINT_RESOLVE_COMMAND: String = "complaint_resolve"
const PACKAGE_APPROVE_COMMAND: String = "pkg_approve"
const MONEY_ADD_COMMAND: String = "money_add"
const MONEY_REMOVE_COMMAND: String = "money_remove"
const PENALTY_ADD_COMMAND: String = "penalty_add"
const PENALTY_REMOVE_COMMAND: String = "penalty_remove"
const APPLY_DAMAGE_COMMAND: String = "apply_damage"
const HEAL_COMMAND: String = "heal"
const KILL_COMMAND: String = "kill"
const RESET_COMMAND: String = "reset"
const PACKAGE_RESET_COMMAND: String = "pkg_reset"
const DAY_INFO_COMMAND: String = "day_info"
const DAY_NEXT_COMMAND: String = "day_next"
const CUSTOMER_NEXT_COMMAND: String = "customer_next"
const DEBUG_TARGETS_COMMAND: String = "debug_targets"
const DEBUG_HELP_COMMAND: String = "debug_help"
const DEBUG_HUD_COMMAND: String = "debug_hud"

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
	_register_command(VISIT_CREATE_COMMAND, _visit_create, ["package", "customer_key"], 1, "Create a persistent debug CustomerVisit.")
	_register_command(PACKAGE_ACTUAL_COMMAND, _pkg_actual, ["package", "actual"], 2, "Force factual CustomerVisit outcome only.")
	_register_command(PACKAGE_DECLARE_COMMAND, _pkg_declare, ["package", "taken|refused|lost"], 2, "Submit Terminal declaration through CustomerFlowService.")
	_register_command(PACKAGE_COMPLAINT_COMMAND, _pkg_complaint, ["package", "reason", "pending|resolve"], 2, "Create or resolve a typed Customer complaint.")
	_register_command(COMPLAINT_RESOLVE_COMMAND, _complaint_resolve, ["package"], 1, "Resolve an existing complaint immediately.")
	_register_command(PACKAGE_APPROVE_COMMAND, _pkg_approve, ["package", "satisfaction"], 1, "Record positive Customer feedback.")
	_register_command("pkg_taken", _pkg_taken, ["package"], 1, "Alias for pkg_declare taken.")
	_register_command("pkg_lost", _pkg_lost, ["package"], 1, "Alias for pkg_declare lost.")
	_register_command("pkg_refused", _pkg_refused, ["package"], 1, "Alias for pkg_declare refused.")
	_register_command("pkg_delivered", _pkg_delivered, ["package"], 1, "Alias for factual delivered.")
	_register_command("pkg_customer_refused", _pkg_customer_refused, ["package"], 1, "Alias for factual customer refusal.")
	_register_command("pkg_player_denied", _pkg_player_denied, ["package"], 1, "Alias for factual player denial.")
	_register_command(MONEY_ADD_COMMAND, _money_add, ["amount", "note"], 1, "Journaled debug credit.")
	_register_command(MONEY_REMOVE_COMMAND, _money_remove, ["amount", "note"], 1, "Journaled forced debug debit.")
	_register_command(PENALTY_ADD_COMMAND, _penalty_add, ["amount", "note"], 1, "Journaled manual debug penalty.")
	_register_command(PENALTY_REMOVE_COMMAND, _penalty_remove, ["amount", "note"], 1, "Compensating reversal of manual debug penalty.")
	_register_command(APPLY_DAMAGE_COMMAND, _apply_damage, ["target", "amount", "damage_type"], 2, "Submit typed damage to a Health target.")
	_register_command(HEAL_COMMAND, _heal, ["target", "amount"], 2, "Submit typed healing to a non-depleted Health target.")
	_register_command(KILL_COMMAND, _kill, ["target"], 0, "Deplete a Health target through DamageRequest. Defaults to self.")
	_register_command(RESET_COMMAND, _reset, ["target"], 0, "Reset a live C_Living entity. Defaults to self.")
	_register_command(PACKAGE_RESET_COMMAND, _pkg_reset, ["package"], 1, "Reset a live damaged Package.")
	_register_command(DAY_INFO_COMMAND, _day_info, [], 0, "Show current day-cycle state.")
	_register_command(DAY_NEXT_COMMAND, _day_next, [], 0, "Queue the next normal day transition.")
	_register_command(CUSTOMER_NEXT_COMMAND, _customer_next, [], 0, "Start the next due CustomerVisit when valid.")
	_register_command(DEBUG_TARGETS_COMMAND, _debug_targets, [], 0, "List concise live debug target handles.")
	_register_command(DEBUG_HELP_COMMAND, _debug_help, ["command|group"], 0, "Show project developer-console workflows and target syntax.")
	_register_command(DEBUG_HUD_COMMAND, _debug_hud, ["on|off|toggle"], 0, "Toggle all debug HUD and customer status labels; ordinary gameplay UI stays active.")
	_register_autocomplete()
	var presentation: Node = preload("res://content/debug/developer_console_presentation.gd").new()
	add_child(presentation)


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


func _register_autocomplete() -> void:
	var entity_targets: PackedStringArray = PackedStringArray(["self", "target"])
	var package_targets: PackedStringArray = PackedStringArray(["target"])

	for command: String in [
		RESOLVE_COMMAND,
		HEALTH_INFO_COMMAND,
		APPLY_DAMAGE_COMMAND,
		HEAL_COMMAND,
		KILL_COMMAND,
		RESET_COMMAND,
	]:
		Console.add_command_autocomplete_list(command, entity_targets)

	for command: String in [
		PACKAGE_INFO_COMMAND,
		VISIT_INFO_COMMAND,
		PACKAGE_REMOVE_COMMAND,
		PACKAGE_PURGE_COMMAND,
		PACKAGE_REGISTER_COMMAND,
		PACKAGE_RESET_COMMAND,
		VISIT_CREATE_COMMAND,
		PACKAGE_ACTUAL_COMMAND,
		PACKAGE_DECLARE_COMMAND,
		PACKAGE_COMPLAINT_COMMAND,
		COMPLAINT_RESOLVE_COMMAND,
		PACKAGE_APPROVE_COMMAND,
		"pkg_taken",
		"pkg_lost",
		"pkg_refused",
		"pkg_delivered",
		"pkg_customer_refused",
		"pkg_player_denied",
	]:
		Console.add_command_autocomplete_list(command, package_targets)

	Console.add_command_autocomplete_list(
		PACKAGE_LIST_COMMAND,
		PackedStringArray(["active", "all"]),
	)
	Console.add_command_autocomplete_list(DEBUG_HUD_COMMAND, PackedStringArray(["on", "off", "toggle"]))
	Console.add_command_autocomplete_list(
		PACKAGE_SPAWN_COMMAND,
		DebugPackageService.definition_keys(),
	)


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



func _visit_create(raw_target: String, customer_key: String = "") -> void:
	_print_service_result(
		VISIT_CREATE_COMMAND,
		DebugCustomerService.create_visit(DebugTargetResolver.resolve(raw_target), customer_key),
	)


func _pkg_actual(raw_target: String, actual_text: String) -> void:
	var target: DebugTarget = DebugTargetResolver.resolve(raw_target)
	match actual_text.strip_edges().to_lower():
		"not_resolved":
			_print_service_result(PACKAGE_ACTUAL_COMMAND, DebugCustomerService.set_actual(target, CustomerVisit.Actual.NOT_RESOLVED))
		"delivered":
			_print_service_result(PACKAGE_ACTUAL_COMMAND, DebugCustomerService.set_actual(target, CustomerVisit.Actual.DELIVERED))
		"customer_refused":
			_print_service_result(PACKAGE_ACTUAL_COMMAND, DebugCustomerService.set_actual(target, CustomerVisit.Actual.CUSTOMER_REFUSED))
		"player_denied":
			_print_service_result(PACKAGE_ACTUAL_COMMAND, DebugCustomerService.set_actual(target, CustomerVisit.Actual.PLAYER_DENIED))
		_:
			DeveloperConsoleOutput.error(
				PACKAGE_ACTUAL_COMMAND,
				"actual must be delivered, customer_refused, player_denied or not_resolved",
			)


func _pkg_declare(raw_target: String, declaration_text: String) -> void:
	var target: DebugTarget = DebugTargetResolver.resolve(raw_target)
	match declaration_text.strip_edges().to_lower():
		"taken":
			_print_service_result(PACKAGE_DECLARE_COMMAND, DebugCustomerService.declare(target, CustomerVisit.Declaration.TAKEN))
		"refused":
			_print_service_result(PACKAGE_DECLARE_COMMAND, DebugCustomerService.declare(target, CustomerVisit.Declaration.REFUSED))
		"lost":
			_print_service_result(PACKAGE_DECLARE_COMMAND, DebugCustomerService.declare(target, CustomerVisit.Declaration.LOST))
		_:
			DeveloperConsoleOutput.error(PACKAGE_DECLARE_COMMAND, "declaration must be taken, refused or lost")


func _pkg_complaint(
	raw_target: String,
	reason_text: String,
	mode_text: String = "",
) -> void:
	var mode: String = mode_text.strip_edges().to_lower()
	if mode.is_empty():
		mode = "pending"
	if mode != "pending" and mode != "resolve":
		DeveloperConsoleOutput.error(PACKAGE_COMPLAINT_COMMAND, "mode must be pending or resolve")
		return
	var target: DebugTarget = DebugTargetResolver.resolve(raw_target)
	match reason_text.strip_edges().to_lower():
		"not_delivered":
			_print_service_result(
				PACKAGE_COMPLAINT_COMMAND,
				DebugCustomerService.complaint(target, CustomerComplaint.Reason.NOT_DELIVERED, mode == "resolve"),
			)
		"damaged":
			_print_service_result(
				PACKAGE_COMPLAINT_COMMAND,
				DebugCustomerService.complaint(target, CustomerComplaint.Reason.DAMAGED, mode == "resolve"),
			)
		_:
			DeveloperConsoleOutput.error(PACKAGE_COMPLAINT_COMMAND, "reason must be not_delivered or damaged")


func _complaint_resolve(raw_target: String) -> void:
	_print_service_result(
		COMPLAINT_RESOLVE_COMMAND,
		DebugCustomerService.resolve_complaint(DebugTargetResolver.resolve(raw_target)),
	)


func _pkg_approve(raw_target: String, satisfaction_text: String = "") -> void:
	var satisfaction: int = CustomerOutcomeService.SATISFACTION_SCALE
	if not satisfaction_text.strip_edges().is_empty():
		if not satisfaction_text.is_valid_int():
			DeveloperConsoleOutput.error(PACKAGE_APPROVE_COMMAND, "satisfaction must be an integer from 0 to 100")
			return
		satisfaction = satisfaction_text.to_int()
	_print_service_result(
		PACKAGE_APPROVE_COMMAND,
		DebugCustomerService.approve(DebugTargetResolver.resolve(raw_target), satisfaction),
	)


func _pkg_taken(raw_target: String) -> void:
	_pkg_declare(raw_target, "taken")


func _pkg_lost(raw_target: String) -> void:
	_pkg_declare(raw_target, "lost")


func _pkg_refused(raw_target: String) -> void:
	_pkg_declare(raw_target, "refused")


func _pkg_delivered(raw_target: String) -> void:
	_pkg_actual(raw_target, "delivered")


func _pkg_customer_refused(raw_target: String) -> void:
	_pkg_actual(raw_target, "customer_refused")


func _pkg_player_denied(raw_target: String) -> void:
	_pkg_actual(raw_target, "player_denied")



func _money_add(amount_text: String, note: String = "") -> void:
	_run_money_command(MONEY_ADD_COMMAND, amount_text, note, MoneyOperation.Reason.DEBUG_CREDIT)


func _money_remove(amount_text: String, note: String = "") -> void:
	_run_money_command(MONEY_REMOVE_COMMAND, amount_text, note, MoneyOperation.Reason.DEBUG_DEBIT)


func _penalty_add(amount_text: String, note: String = "") -> void:
	_run_money_command(PENALTY_ADD_COMMAND, amount_text, note, MoneyOperation.Reason.DEBUG_PENALTY)


func _penalty_remove(amount_text: String, note: String = "") -> void:
	_run_money_command(
		PENALTY_REMOVE_COMMAND,
		amount_text,
		note,
		MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL,
	)


func _run_money_command(
	command: String,
	amount_text: String,
	note: String,
	reason: MoneyOperation.Reason,
) -> void:
	if not amount_text.is_valid_int():
		DeveloperConsoleOutput.error(command, "amount must be a positive integer")
		return
	var amount: int = amount_text.to_int()
	var result: DebugServiceResult = DebugServiceResult.new()
	match reason:
		MoneyOperation.Reason.DEBUG_CREDIT:
			result = DebugEconomyService.credit(amount, note)
		MoneyOperation.Reason.DEBUG_DEBIT:
			result = DebugEconomyService.debit(amount, note)
		MoneyOperation.Reason.DEBUG_PENALTY:
			result = DebugEconomyService.penalty(amount, note)
		MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL:
			result = DebugEconomyService.reverse_penalty(amount, note)
	_print_service_result(command, result)



func _apply_damage(
	raw_target: String,
	amount_text: String,
	damage_type_text: String = "",
) -> void:
	var amount: float = _positive_float(APPLY_DAMAGE_COMMAND, amount_text)
	if amount <= 0.0:
		return
	var target: DebugTarget = DebugTargetResolver.resolve(raw_target)
	var normalized: String = damage_type_text.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = "generic"
	match normalized:
		"generic":
			_print_service_result(APPLY_DAMAGE_COMMAND, DebugHealthService.apply_damage(target, amount, DamageRequest.Type.GENERIC))
		"melee":
			_print_service_result(APPLY_DAMAGE_COMMAND, DebugHealthService.apply_damage(target, amount, DamageRequest.Type.MELEE))
		"impact":
			_print_service_result(APPLY_DAMAGE_COMMAND, DebugHealthService.apply_damage(target, amount, DamageRequest.Type.IMPACT))
		"explosion":
			_print_service_result(APPLY_DAMAGE_COMMAND, DebugHealthService.apply_damage(target, amount, DamageRequest.Type.EXPLOSION))
		"toxic":
			_print_service_result(APPLY_DAMAGE_COMMAND, DebugHealthService.apply_damage(target, amount, DamageRequest.Type.TOXIC))
		"liquid":
			_print_service_result(APPLY_DAMAGE_COMMAND, DebugHealthService.apply_damage(target, amount, DamageRequest.Type.LIQUID))
		_:
			DeveloperConsoleOutput.error(
				APPLY_DAMAGE_COMMAND,
				"damage_type must be generic, melee, impact, explosion, toxic or liquid",
			)


func _heal(raw_target: String, amount_text: String) -> void:
	var amount: float = _positive_float(HEAL_COMMAND, amount_text)
	if amount <= 0.0:
		return
	_print_service_result(
		HEAL_COMMAND,
		DebugHealthService.heal(DebugTargetResolver.resolve(raw_target), amount),
	)


func _kill(raw_target: String = "") -> void:
	var normalized: String = raw_target.strip_edges()
	if normalized.is_empty():
		normalized = "self"
	_print_service_result(
		KILL_COMMAND,
		DebugHealthService.kill(DebugTargetResolver.resolve(normalized)),
	)


func _reset(raw_target: String = "") -> void:
	var normalized: String = raw_target.strip_edges()
	if normalized.is_empty():
		normalized = "self"
	_print_service_result(
		RESET_COMMAND,
		DebugHealthService.reset(DebugTargetResolver.resolve(normalized)),
	)


func _positive_float(command: String, value: String) -> float:
	if not value.is_valid_float():
		DeveloperConsoleOutput.error(command, "amount must be a finite positive number")
		return -1.0
	var parsed: float = value.to_float()
	if not is_finite(parsed) or parsed <= 0.0:
		DeveloperConsoleOutput.error(command, "amount must be a finite positive number")
		return -1.0
	return parsed



func _pkg_reset(raw_target: String) -> void:
	_print_service_result(
		PACKAGE_RESET_COMMAND,
		DebugPackageService.reset(DebugTargetResolver.resolve(raw_target)),
	)


func _day_info() -> void:
	DeveloperConsoleOutput.ok(
		DAY_INFO_COMMAND,
		DeveloperConsoleDiagnostics.day_info(),
	)


func _day_next() -> void:
	_print_service_result(DAY_NEXT_COMMAND, DebugWorldService.day_next())


func _customer_next() -> void:
	_print_service_result(CUSTOMER_NEXT_COMMAND, DebugWorldService.customer_next())


func _debug_targets() -> void:
	DeveloperConsoleOutput.ok(
		DEBUG_TARGETS_COMMAND,
		DeveloperConsoleDiagnostics.debug_targets(),
	)



func _debug_help(subject: String = "") -> void:
	Console.console_commands["help"].function.call(subject)


func _debug_hud(mode: String = "toggle") -> void:
	match mode.strip_edges().to_lower():
		"on": DebugHudService.set_enabled(true)
		"off": DebugHudService.set_enabled(false)
		"toggle", "": DebugHudService.set_enabled(not DebugHudService.is_enabled())
		_:
			DeveloperConsoleOutput.error(DEBUG_HUD_COMMAND, "mode must be on, off or toggle")
			return
	DeveloperConsoleOutput.ok(DEBUG_HUD_COMMAND, PackedStringArray(["enabled=%s" % DebugHudService.is_enabled()]))
