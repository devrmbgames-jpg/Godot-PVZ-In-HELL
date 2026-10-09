extends GutTest
## Проверки диагностического HUD: скрытие отладки сохраняет игровые предупреждения, данные читаются из живых связей.

var _world: World = null
var _actor: Entity = null
var _customer: E_NpcCharacter = null
var _hud: CanvasLayer = null
var _commands: DeveloperConsoleCommands = null
var _visit: CustomerVisit = null


#region Подготовка и очистка
## Создаёт клиента, визит, HUD и команды в изолированном World дневной фазы.
func before_each() -> void:
	DebugHudService.set_enabled(true)
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new(), C_PackageLedger.new(), C_Wallet.new()]
	_world.add_entity(session)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	_actor = Entity.new()
	_actor.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_world.add_entity(_actor)
	_visit = CustomerVisit.new()
	_visit.visit_id = &"hud-test"
	_visit.package_id = "hud-parcel"
	_visit.definition = DEF_Customer.new()
	_visit.definition.patience_seconds = 47.0
	_visit.satisfaction = 74
	CustomerFlowQueries.current().visits.append(_visit)

	var scene: PackedScene = load(
		"res://content/domains/customers/entities/customer.tscn") as PackedScene
	_customer = scene.instantiate() as E_NpcCharacter
	(_customer as Node as RigidBody3D).freeze = true
	EntityCompositionFixture.register_visit(_world, _customer, _visit)

	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	agent.elapsed = 7.0


	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = _visit.package_id
	record.number = 19
	PackageQueries.ledger().records.append(record)
	_hud = (load("res://content/ui/interaction_hud.tscn") as PackedScene).instantiate() as CanvasLayer
	_hud.set("player", _actor)
	_world.add_child(_hud)
	_commands = DeveloperConsoleCommands.new()


## Освобождает команды/World и возвращает включённое состояние диагностики.
func after_each() -> void:
	_commands.free()
	_world.free()
	ECS.world = null
	DebugHudService.set_enabled(true)


#endregion

#region Диагностика и игровая обратная связь
## Выключение debug скрывает диагностические панели, сохраняя состояние игрока и предупреждение взгляда.
func test_console_toggle_hides_screen_and_customer_debug_but_preserves_gameplay_feedback() -> void:
	var challenge: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	challenge.definition = load("res://content/domains/challenges/definitions/def_challenge_dont_look.tres") as DEF_Challenge
	assert_true(ChallengeService.begin_on_arrival(_customer, _actor))
	challenge.violation_elapsed = 1.0
	var label: Label3D = _customer.get_node("DebugStatus") as Label3D
	label.call("_process", 1.0)
	_hud.call("_process", 0.0)
	assert_true(label.visible)
	assert_true((_hud.get_node("Overlay/PlayerDebugPanel") as Control).visible)
	_commands._debug_hud("off")
	label.call("_process", 1.0)
	_hud.call("_process", 0.0)
	assert_false(label.visible)
	assert_false((_hud.get_node("Overlay/PlayerDebugPanel") as Control).visible)
	assert_false((_hud.get_node("Overlay/PackageDebugPanel") as Control).visible)
	assert_false((_hud.get_node("Overlay/ChallengeDebugPanel") as Control).visible)
	assert_true((_hud.get_node("Overlay/PlayerStatusPanel") as Control).visible)
	assert_true((_hud.get_node("Overlay/GazeDistortion") as Control).visible, "Turning off debug must not remove a gameplay warning")
	_commands._debug_hud("on")
	label.call("_process", 1.0)
	_hud.call("_process", 0.0)
	assert_true(label.visible)
	assert_true((_hud.get_node("Overlay/PlayerDebugPanel") as Control).visible)


## Метка клиента отражает номер, здоровье и авторский таймер; удалённая Entity не даёт текста.
func test_customer_label_reads_registration_health_state_and_real_authored_timer() -> void:
	var text: String = CustomerDebugPresentation.text_for(_customer)
	assert_string_contains(text, "№019")
	assert_string_contains(text, "Ждёт посылку")
	assert_string_contains(text, "7.0 / 47.0 с")
	assert_string_contains(text, "HP [")
	assert_string_contains(text, "довольство 74")
	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_DARKNESS
	_visit.definition = load("res://content/domains/customers/definitions/def_customer_light_sensitive.tres") as DEF_Customer
	text = CustomerDebugPresentation.text_for(_customer)
	assert_string_contains(text, "Ждёт темноты")
	assert_string_contains(text, "7.0 / 80.0 с")
	_world.remove_entity(_customer)
	assert_eq(CustomerDebugPresentation.text_for(_customer), "")


## Таймер пола читается только из собственного живого эффекта R_ChallengeEffect и исчезает после его удаления.
func test_floor_label_reads_only_its_live_relationship_effect_damage_clock() -> void:
	var challenge: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	challenge.definition = DEF_Challenge.new()
	challenge.definition.condition = DEF_FloorChallengeCondition.new()
	challenge.phase = C_Challenge.Phase.ACTIVE
	var floor: C_FloorChallenge = _customer.get_component(C_FloorChallenge) as C_FloorChallenge
	floor.touching_danger = true
	var hazard: Entity = Entity.new()
	hazard.component_resources = [C_FloorHazard.new()]
	_world.add_entity(hazard)
	(hazard.get_component(C_FloorHazard) as C_FloorHazard).damage_elapsed = 0.35
	_customer.add_relationship(Relationship.new(R_ChallengeEffect.new(), hazard))

	var text: String = CustomerDebugPresentation.text_for(_customer)
	assert_string_contains(text, "Пол: опасный контакт")
	assert_string_contains(text, "Таймер урона 0.35 с")
	_world.remove_entity(hazard)
	assert_false(CustomerDebugPresentation.text_for(_customer).contains("Таймер урона"))

#endregion
