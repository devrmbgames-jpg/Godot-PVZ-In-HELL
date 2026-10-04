extends GutTest
## Проверяет обратимое восприятие голодного игрока без изменения личности, заказа и смысла ответов.

## Бюджет ожидания обновления UI, в кадрах.
const UI_FRAMES: int = 32
var _world: World = null
var _actor: Entity = null
var _customer: E_Customer = null
var _state: C_Hunger = null
var _visit: CustomerVisit = null
var _context: CustomerDialogueContext = null


#region Окружение и ожидание UI
## Создаёт игрока с голодом, клиента и настоящий контекст заказа.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_CustomerFlow.new(), C_PackageLedger.new()]
	_world.add_entity(session)
	(session.get_component(C_DayCycle) as C_DayCycle).phase = C_DayCycle.Phase.DAY
	_actor = Entity.new()

	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = DEF_HungerPolicy.new()
	_actor.component_resources = [C_PlayerInputController.new(), C_GrabControl.new(), hunger]
	_world.add_entity(_actor)
	_state = _actor.get_component(C_Hunger) as C_Hunger
	_customer = (load("res://content/entities/customers/customer.tscn") as PackedScene).instantiate() as E_Customer
	(_customer as Node as RigidBody3D).freeze = true
	_world.add_entity(_customer)

	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = &"hunger-visit"
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_visit = CustomerVisit.new()
	_visit.visit_id = agent.visit_id
	_visit.customer_id = &"real-customer"
	_visit.package_id = "real-order"
	_visit.definition = DEF_Customer.new()
	_visit.started = true
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits = [_visit]

	var registration: PackageRegistrationRecord = PackageRegistrationRecord.new()
	registration.package_id = _visit.package_id
	registration.number = 3
	registration.active = true
	(session.get_component(C_PackageLedger) as C_PackageLedger).records = [registration]
	_context = CustomerDialogueContext.new(_actor, _customer)


## Закрывает диалог и удаляет World до очистки сохранённых ссылок.
func after_each() -> void:
	for panel: Node in get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP):
		(panel as CustomerDialoguePanel).close_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_actor = null
	_customer = null
	_state = null
	_visit = null
	_context = null


func _food(visible: bool) -> void:
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if (_customer.get_node("HungerPerception/Food") as Node3D).visible == visible:
			return

	assert_true(false, "Food presentation must follow the current local-player tier")


func _panel() -> CustomerDialoguePanel:
	var panels: Array[Node] = get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP)
	return panels[0] as CustomerDialoguePanel if not panels.is_empty() else null


func _line_text() -> String:
	var panel: CustomerDialoguePanel = _panel()
	if panel == null:
		return ""

	for node: Node in panel.find_children("*", "RichTextLabel", true, false):
		return (node as RichTextLabel).text
	return ""


func _press(text: String) -> bool:
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		var panel: CustomerDialoguePanel = _panel()
		if panel == null:
			continue

		for node: Node in panel.find_children("*", "Button", true, false):
			var button: Button = node as Button
			if button.text == text and button.visible and not button.disabled:
				button.pressed.emit()
				return true
	return false


#endregion

#region Обратимое восприятие и смысл ответа
## Голодная проекция обратима и сохраняет Entity, RID, заказ и исходную реплику.
func test_food_visual_is_reversible_and_keeps_entity_body_order_and_message() -> void:
	var entity_id: String = _customer.id
	var rid: RID = (_customer as Node as RigidBody3D).get_rid()
	_customer.show_message("Настоящий заказ 003")
	_state.value = 81.0
	await _food(true)
	assert_false((_customer.get_node("Body") as Node3D).visible)
	assert_false((_customer.get_node("Message") as Node3D).visible)
	assert_eq(_context.perceived_text("Настоящая реплика"), "Съешь меня")
	assert_eq(_customer.id, entity_id)
	assert_eq((_customer as Node as RigidBody3D).get_rid(), rid)
	assert_eq(_visit.customer_id, &"real-customer")
	assert_eq(_visit.package_id, "real-order")
	assert_eq(_context.package_number(), 3)
	assert_true(HungerService.apply_food(_actor, load("res://content/definitions/gameplay/hunger/def_food_bread.tres") as DEF_FoodEffect))
	await _food(false)
	assert_true((_customer.get_node("Body") as Node3D).visible)
	assert_true((_customer.get_node("Message") as Node3D).visible)
	assert_eq((_customer.get_node("Message") as Label3D).text, "Настоящий заказ 003")
	assert_eq(_context.perceived_text("Настоящая реплика"), "Настоящая реплика")
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(_visit.riddle_solved)


## Еда возвращает текущую настоящую строку без перехода по ветке диалога.
func test_open_dialogue_reverts_current_npc_line_after_food_without_advancing_branch() -> void:
	_state.value = 81.0
	assert_true(CustomerDialogueService.start(_actor, _customer))
	assert_true(await _press("Продолжить"))
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if _line_text() == "Съешь меня":
			break

	assert_eq(_line_text(), "Съешь меня")
	var food: DEF_FoodEffect = DEF_FoodEffect.new()
	food.hunger_relief = 100.0
	assert_true(HungerService.apply_food(_actor, food))
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if _line_text().contains("003"):
			break

	assert_true(_line_text().contains("003"), "Current real line must return without a dialogue transition")
	assert_true(await _press("Хорошо."), "Player choice retains its authored meaning")
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if _panel() == null:
			break

	assert_null(_panel())
	assert_eq((_customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)


## Искажённая реплика NPC сохраняет смысл честного ответа игрока и фактический отказ.
func test_starving_honest_denial_keeps_actual_response_tags_and_domain_transition() -> void:
	_state.value = 81.0
	assert_true(CustomerDialogueService.start(_actor, _customer))
	assert_true(await _press("Продолжить"))
	assert_true(await _press("Я не могу выдать вам посылку."))
	assert_true(await _press("[честно] Мы не можем найти вашу посылку."))
	assert_true(await _press("Продолжить"))
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if _panel() == null:
			break

	assert_eq(_visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(_visit.last_dialogue_intent, CustomerDialogueIntent.Type.HONEST)
	assert_eq((_customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.LEAVING)
	assert_eq(_visit.customer_id, &"real-customer")
	assert_false(_visit.customer_dead)

#endregion


#region Границы хищного голода
## Хищное восприятие имеет исключительную границу 80%, независимо от боевой ступени.
func test_food_perception_starts_strictly_above_eighty_percent() -> void:
	for value: float in [30.0, 75.0, 80.0]:
		_state.value = value
		assert_false(HungerService.sees_npcs_as_food(_state))
		assert_eq(_context.perceived_text("Настоящая реплика"), "Настоящая реплика")
	_state.value = 81.0
	assert_true(HungerService.sees_npcs_as_food(_state))
	assert_eq(_context.perceived_text("Настоящая реплика"), "Съешь меня")
	assert_eq(HungerService.tier(_state), C_Hunger.Tier.STARVING)
#endregion
