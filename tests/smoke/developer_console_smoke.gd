extends Node
## End-to-end developer-console regression through the real console parser.

const MAIN_LEVEL: PackedScene = preload("res://content/scenes/main_level.tscn")
const HEALTH_DELTA: float = 5.0

var _level: Node3D = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_level = MAIN_LEVEL.instantiate() as Node3D
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	await get_tree().physics_frame

	assert(Console.console_commands.has(DeveloperConsoleCommands.PACKAGE_SPAWN_COMMAND))
	assert(Console.console_commands.has(DeveloperConsoleCommands.APPLY_DAMAGE_COMMAND))
	assert(Console.console_commands.has(DeveloperConsoleCommands.MONEY_ADD_COMMAND))
	_expect_console("help inventory", "inventory_use <slot>")
	_expect_console("hunger_set 50", "OK hunger_set")
	_expect_console("inventory_give food", "OK inventory_give")
	_expect_console("inventory_info", "slot=0")
	_expect_console("inventory_use 0", "OK inventory_use")
	_expect_console("hunger_info", "OK hunger_info")
	_expect_console("trader_info", "courier=")
	_expect_console("order_info", "OK order_info")
	_expect_console("quest_info", "OK quest_info")
	_expect_console("debug_markers on", "OK debug_markers")
	_expect_console("debug_markers off", "OK debug_markers")

	var slot: String = "smoke_console_%d" % Time.get_ticks_usec()
	_expect_console("save_write " + slot, "OK save_write")
	_expect_console("save_load " + slot, "OK save_load")
	DirAccess.remove_absolute(DebugGameplayService.slot_path(slot))

	var definition_keys: PackedStringArray = DebugPackageService.definition_keys()
	assert(not definition_keys.is_empty())
	var definition_key: String = definition_keys[0]
	_expect_console(
		"pkg_spawn %s 1 self 1" % definition_key,
		"OK pkg_spawn",
	)

	var parcel: Entity = _single_debug_package()
	assert(parcel != null)
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	var package_health: C_Health = parcel.get_component(C_Health) as C_Health
	assert(identity != null and state != null and package_health != null)
	var package_id: String = identity.package_id
	var package_hp: float = package_health.current
	var registration: PackageRegistrationRecord = DebugTargetResolver.resolve(package_id).registration
	assert(registration != null and registration.active)

	var number: int = registration.number

	_expect_console("debug_resolve #%03d" % number, "OK debug_resolve")
	_expect_console(
		"apply_damage %s %.1f impact" % [package_id, HEALTH_DELTA],
		"OK apply_damage",
	)
	_process_gameplay(2)
	assert(is_equal_approx(package_health.current, package_hp - HEALTH_DELTA))
	_expect_console(
		"heal %s %.1f" % [package_id, HEALTH_DELTA],
		"OK heal",
	)
	_process_gameplay(2)
	assert(is_equal_approx(package_health.current, package_hp))

	_expect_console("visit_create %s" % package_id, "OK visit_create")
	var target: DebugTarget = DebugTargetResolver.resolve(package_id)
	assert(target.visit != null)
	var visit: CustomerVisit = target.visit
	_expect_console("pkg_delivered %s" % package_id, "OK pkg_actual")
	assert(visit.actual == CustomerVisit.Actual.DELIVERED)
	assert(visit.declaration == CustomerVisit.Declaration.NONE)
	_expect_console("pkg_approve %s 80" % package_id, "OK pkg_approve")
	assert(visit.feedback == CustomerVisit.Feedback.APPROVED)
	assert(visit.satisfaction == 80)
	_expect_console("pkg_taken %s" % package_id, "OK pkg_declare")
	assert(visit.actual == CustomerVisit.Actual.DELIVERED)
	assert(visit.declaration == CustomerVisit.Declaration.TAKEN)

	_expect_console(
		"pkg_complaint %s not_delivered pending" % package_id,
		"OK pkg_complaint",
	)
	assert(visit.complaint != null)
	assert(visit.complaint.outcome == CustomerComplaint.Outcome.PENDING)
	_expect_console(
		"complaint_resolve %s" % package_id,
		"OK complaint_resolve",
	)
	assert(visit.complaint.outcome != CustomerComplaint.Outcome.PENDING)

	var wallet: C_Wallet = WalletService.current()
	assert(wallet != null)
	var balance_before_debug_money: int = wallet.balance
	var penalties_before_debug_money: int = wallet.penalties
	_expect_console("money_add 100 stage9_credit", "OK money_add")
	assert(wallet.balance == balance_before_debug_money + 100)
	_expect_console("money_remove 40 stage9_debit", "OK money_remove")
	assert(wallet.balance == balance_before_debug_money + 60)
	_expect_console("penalty_add 30 stage9_penalty", "OK penalty_add")
	assert(wallet.balance == balance_before_debug_money + 30)
	assert(wallet.penalties == penalties_before_debug_money + 30)
	_expect_console("penalty_remove 10 stage9_reversal", "OK penalty_remove")
	assert(wallet.balance == balance_before_debug_money + 40)
	assert(wallet.penalties == penalties_before_debug_money + 20)

	var balance_before_error: int = wallet.balance
	var penalties_before_error: int = wallet.penalties
	_expect_console("penalty_remove 999 stage9_invalid", "ERROR penalty_remove")
	assert(wallet.balance == balance_before_error)
	assert(wallet.penalties == penalties_before_error)

	var player: Entity = DebugTargetResolver.player()
	assert(player != null)
	var player_health: C_Health = player.get_component(C_Health) as C_Health
	assert(player_health != null)
	var player_hp: float = player_health.current
	assert(player_hp > HEALTH_DELTA)
	_expect_console(
		"apply_damage self %.1f generic" % HEALTH_DELTA,
		"OK apply_damage",
	)
	_process_gameplay(2)
	assert(is_equal_approx(player_health.current, player_hp - HEALTH_DELTA))
	_expect_console("heal self %.1f" % HEALTH_DELTA, "OK heal")
	_process_gameplay(2)
	assert(is_equal_approx(player_health.current, player_hp))
	_expect_console("kill self", "OK kill")
	_process_gameplay(2)
	assert(player_health.depleted)
	assert(is_zero_approx(player_health.current))
	_expect_console("heal self 1", "ERROR heal")
	_expect_console("reset self", "OK reset")
	assert(not player_health.depleted)
	assert(is_equal_approx(player_health.current, player_health.value))
	assert(not player.has_component(C_Death))

	_expect_console("pkg_remove %s" % package_id, "OK pkg_remove")
	assert(not EntityAvailability.contains(parcel, ECS.world))
	_expect_console("debug_resolve #%03d" % number, "OK debug_resolve")
	_expect_console("heal %s 1" % package_id, "ERROR heal")
	_expect_console("pkg_purge %s" % package_id, "ERROR pkg_purge")

	_level.free()
	_level = null
	ECS.world = null
	print("Developer console testing smoke PASS")
	get_tree().quit()


func _expect_console(command: String, expected_marker: String) -> void:
	Console.clear()
	Console.call(&"_on_text_entered", command)
	var output: String = Console.rich_label.get_parsed_text()
	assert(
		expected_marker in output,
		"Expected '%s' for command '%s', got: %s"
		% [expected_marker, command, output],
	)
	print("%s -> %s" % [command, expected_marker])


func _single_debug_package() -> Entity:
	var found: Array[Entity] = []
	for entity: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = entity.get_component(C_Package) as C_Package
		if identity != null and identity.package_id.begins_with(DebugPackageService.DEBUG_ID_PREFIX):
			found.append(entity)
	assert(found.size() == 1)
	return found[0] if found.size() == 1 else null


func _process_gameplay(ticks: int) -> void:
	for tick: int in ticks:
		ECS.world.process(1.0 / 60.0, "GamePlay")
