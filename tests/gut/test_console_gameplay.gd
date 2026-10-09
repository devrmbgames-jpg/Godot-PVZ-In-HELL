extends GutTest
## Команды консоли проходят обычные игровые переходы; запись ограничена изолированными тестовыми слотами.

var _world: World
var _commands: DeveloperConsoleCommands
var _actor: Entity
var _session: Entity
var _cycle: C_DayCycle
var _slot: String


#region Подготовка и очистка
## Создаёт минимальные игрока/сессию и подключает команды консоли с уникальным тестовым слотом.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_cycle = C_DayCycle.new()
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	flow.schedule = load("res://content/domains/customers/definitions/def_customer_schedule_default.tres") as DEF_CustomerSchedule
	_session = Entity.new()
	_session.component_resources = [_cycle, C_Commerce.new(), C_Wallet.new(), flow]
	_world.add_entity(_session)
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle

	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = DEF_HungerPolicy.new()
	_actor = Entity.new()
	_actor.component_resources = [C_PlayerInputController.new(), C_Inventory.new(), hunger, C_GrabControl.new(), C_Health.new()]
	_world.add_entity(_actor)
	_commands = DeveloperConsoleCommands.new()
	add_child(_commands)
	_slot = "gut_console_%d" % Time.get_ticks_usec()
	Console.clear()


## Закрывает консоль, очищает World и удаляет только созданный тестовый слот.
func after_each() -> void:
	if bool(Console.is_visible()): Console.toggle_console()
	_commands.free()
	_world.purge(false)
	_world.free()
	ECS.world = null
	var path: String = DebugGameplayService.slot_path(_slot)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	Console.clear()
	await get_tree().process_frame


func _run(command: String, args: Array = []) -> String:
	Console.clear()
	var parts: PackedStringArray = [command]
	for argument: String in args: parts.append(argument)
	Console._on_text_entered(" ".join(parts))
	return Console.rich_label.get_parsed_text()


#endregion

#region Игровые границы команд консоли
## The destructive command is never executed inside GUT: it would remove GUT itself.
func test_kill_game_is_debug_only_and_preserves_kill_self() -> void:
	var kill_command: Console.ConsoleCommand = Console.console_commands.get(
		DeveloperConsoleCommands.KILL_COMMAND
	) as Console.ConsoleCommand
	assert_not_null(kill_command)
	assert_eq(kill_command.required, 0)
	if OS.is_debug_build():
		assert_true(kill_command.arguments.has("target|game"))
		assert_true(Console.command_parameters[DeveloperConsoleCommands.KILL_COMMAND].has("game"))
	else:
		assert_true(kill_command.arguments.has("target"))
		assert_false(Console.command_parameters[DeveloperConsoleCommands.KILL_COMMAND].has("game"))

	var worker_script: Script = load("res://content/debug/debug_runtime_purge.gd") as Script
	assert_not_null(worker_script)
	var worker: Node = worker_script.new() as Node
	add_child(worker)
	assert_true(bool(worker.call(&"_is_autoload", Console)))
	assert_true(bool(worker.call(&"_is_autoload", ECS)))
	assert_false(bool(worker.call(&"_is_autoload", _world)))
	worker.call(&"_show_exit_ui")
	var exit_button: Button = worker.find_child("ExitAfterSnapshot", true, false) as Button
	assert_not_null(exit_button, "Debug purge must leave an actionable exit control")
	if exit_button != null:
		assert_true(exit_button.pressed.is_connected(Callable(worker, "_request_quit")))
	worker.free()


## Выдача/употребление соблюдают владение, вместимость и диапазон голода; отказ не оставляет сирот.
func test_food_commands_obey_bounds_capacity_and_normal_consumption() -> void:
	assert_true(_run("hunger_set", ["50"]).contains("OK hunger_set"))
	assert_true(_run("inventory_give", ["food", "2"]).contains("OK inventory_give"))
	var owned: Array[Entity] = InventoryService.items(_actor)
	assert_eq(owned.size(), 1)
	assert_same(InventoryService.owner_for(owned[0]), _actor)
	assert_true(_run("inventory_info").contains("slot=0"))
	assert_true(_run("inventory_use", ["0"]).contains("OK inventory_use"))
	assert_eq((owned[0].get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)

	var hunger: C_Hunger = _actor.get_component(C_Hunger) as C_Hunger
	assert_lt(hunger.value, 50.0)
	var previous: float = hunger.value
	assert_true(_run("hunger_set", ["-1"]).contains("ERROR hunger_set"))
	assert_eq(hunger.value, previous)
	(_actor.get_component(C_Inventory) as C_Inventory).maximum_stacks = 1
	var count: int = _world.entities.size()
	assert_true(_run("inventory_give", ["med", "1"]).contains("ERROR inventory_give"))
	assert_eq(_world.entities.size(), count, "Failed grant leaves no orphan")
	assert_true(_run("inventory_give", ["large_shelf", "1"]).contains("ERROR inventory_give"))
	assert_true(_run("inventory_use", ["-1"]).contains("ERROR inventory_use"))
	assert_true(_run("help", ["inventory_give"]).contains("inventory_give <definition_key> [count=1]"))
	assert_true(Console.command_parameters["help"].has("inventory_give"))


## Предпросмотр прогресса меняет колесо и сигнал без выполнения эффекта действия.
func test_progress_command_updates_real_rotation_and_signal_without_activation() -> void:
	var valve: E_InteractionTestValve = (load("res://content/domains/interaction/entities/interaction_test_valve.tscn") as PackedScene).instantiate() as E_InteractionTestValve
	valve.mode = E_InteractionTestValve.Mode.HOLD_NEVER
	_world.add_entity(valve)
	var basis: Basis = (valve.get_node("Wheel") as Node3D).basis
	watch_signals(valve)
	var target: String = "entity:" + valve.id
	assert_true(_run("progress_set", [target, "0.5"]).contains("OK progress_set"))
	assert_eq(valve.get_progress(), 0.5)
	assert_ne((valve.get_node("Wheel") as Node3D).basis, basis)
	assert_signal_emitted_with_parameters(valve, "progress_changed", [0.5])
	assert_false(valve.is_active(), "Preview does not execute hold effect")
	assert_true(_run("progress_set", [target, "2"]).contains("ERROR progress_set"))
	assert_eq(valve.get_progress(), 0.5)
	assert_true(_run("progress_info", [target]).contains("progress=0.500"))


## Старт/остановка испытания освобождают живую связь и не допускают повтор использованной сессии.
func test_debug_challenge_uses_lifecycle_and_cannot_repeat_consumed_session() -> void:
	_cycle.phase = C_DayCycle.Phase.DAY
	var subject: Entity = Entity.new()
	_world.add_entity(subject)
	var target: String = "entity:" + subject.id
	assert_true(_run("challenge_start", [target, "warehouse-light-during-visit"]).contains("OK challenge_start"))
	assert_same(ChallengeService.actor_for(subject), _actor)
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	assert_eq(state.phase, C_Challenge.Phase.ACTIVE)
	assert_true(_run("challenge_info", [target]).contains("UNTIL_DEPARTURE"))
	assert_true(_run("challenge_stop", [target]).contains("OK challenge_stop"))
	assert_eq(state.phase, C_Challenge.Phase.CLEANUP)
	assert_null(ChallengeService.actor_for(subject))
	assert_true(_run("challenge_start", [target, "warehouse-light-during-visit"]).contains("ERROR challenge_start"))


## Именованный debug-слот сохраняет состояние; неверные фаза и путь отклоняются.
func test_named_save_roundtrip_is_isolated_and_rejects_invalid_phase_and_path() -> void:
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	wallet.balance = 123
	assert_true(_run("save_write", [_slot]).contains("OK save_write"))
	assert_true(FileAccess.file_exists(DebugGameplayService.slot_path(_slot)))
	wallet.balance = 17
	assert_true(_run("save_load", [_slot]).contains("OK save_load"))
	assert_eq(wallet.balance, 123)
	assert_eq(_cycle.phase, C_DayCycle.Phase.MORNING)
	assert_true(_run("save_write", ["../autosave"]).contains("ERROR save_write"))
	assert_eq(DebugGameplayService.slot_path("user://autosave.pvzh"), "")
	_cycle.phase = C_DayCycle.Phase.DAY
	assert_true(_run("save_load", [_slot]).contains("ERROR save_load"))
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY)


## Создание визита сохраняет авторское представление и состояние до прихода без повторного заказа.
func test_live_visit_option_preserves_accounting_default_and_authored_introduction() -> void:
	var parcel: Entity = Entity.new()
	var identity: C_Package = C_Package.new()
	identity.package_id = "console_live"
	identity.definition = DEF_Package.new()
	identity.definition.key = &"books"
	parcel.component_resources = [identity, C_PackageState.new()]
	EntityCompositionFixture.register(_world, parcel)
	assert_true(_run("visit_create", ["pkg:console_live", "ordinary", "1"]).contains("OK visit_create"))

	var visit: CustomerVisit = CustomerFlowQueries.find_visit(&"visit/console_live")
	assert_false(visit.started)
	assert_false(visit.finished)
	assert_eq(visit.definition.introduction, DEF_Customer.Introduction.ANNOUNCE_ORDER)
	assert_true(_run("visit_info", ["visit:visit/console_live"]).contains("ANNOUNCE_ORDER"))
	assert_true(_run("visit_create", ["pkg:console_live", "ordinary", "2"]).contains("ERROR visit_create"))


## Живые связи толкания/тележки блокируют запись и загрузку без изменения мира или файла.
func test_persistence_rejects_push_and_cart_without_changing_session_slot_or_world() -> void:
	assert_true(_run("save_write", [_slot]).contains("OK save_write"))
	var path: String = DebugGameplayService.slot_path(_slot)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	wallet.balance = 77
	var prop: Entity = Entity.new()
	_world.add_entity(prop)
	for relation_script: Script in [R_PushedBy, R_CartDrivenBy]:
		var binding: Relationship = Relationship.new(relation_script.new() as Component, _actor)
		prop.add_relationship(binding)
		## Живая связь запрещает запись и без актуального capture-токена: Relationship остаётся источником истины.
		assert_true(_run("save_load", [_slot]).contains("ERROR save_load"))
		assert_eq(wallet.balance, 77)
		assert_true(_run("save_write", [_slot]).contains("ERROR save_write"))
		assert_eq(FileAccess.get_file_as_bytes(path), saved)
		assert_true(prop.relationships.has(binding))
		prop.remove_relationship(binding)

	var token: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.PUSH)
	assert_true(_run("save_load", [_slot]).contains("ERROR save_load"))
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.PUSH)
	assert_eq(wallet.balance, 77)
	InteractionControlFocus.release(_actor, token)


## Отклонённый запрос атаки не меняет противника и оставшееся время перезарядки.
func test_invalid_npc_request_does_not_reset_cooldown_or_opponent() -> void:
	var npc: Entity = Entity.new()
	var state: C_NpcCombat = C_NpcCombat.new()
	state.cooldown_remaining = 5.0
	npc.component_resources = [state, C_NpcIntent.new()]
	_world.add_entity(npc)
	state = npc.get_component(C_NpcCombat) as C_NpcCombat
	assert_true(CombatService.bind_target(npc, _actor))
	state.cooldown_remaining = 5.0

	var opponent: Entity = Entity.new()
	_world.add_entity(opponent)
	assert_true(_run("npc_attack", ["entity:" + npc.id, "melee", "0", "entity:" + opponent.id]).contains("ERROR npc_attack"))
	assert_same(CombatQueries.target_for(npc), _actor)
	assert_eq(state.cooldown_remaining, 5.0)
	assert_true(_run("npc_info", ["entity:" + npc.id]).contains("cooldown=5.00s"))

#endregion
