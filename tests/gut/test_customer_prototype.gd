extends GutTest
## Проверяет авторский выбор prefab/диалога и приоритет позы осмотра относительно движения и боя.

var _world: World
var _visit: CustomerVisit
var _customer: E_Customer
var _actor: Entity


#region Тестовое окружение
## Создаёт визит из прототипного профиля, который сам выбирает сцену клиента.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_CustomerFlow.new()]
	_world.add_entity(session)
	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.customer_scene = null
	_visit = CustomerVisit.new()
	_visit.visit_id = &"prototype"
	_visit.definition = load("res://content/domains/customers/definitions/def_customer_prototype.tres") as DEF_Customer
	_visit.requires_registered_package = false
	flow.visits.append(_visit)

	var counter: E_DeliveryCounter = (load("res://content/domains/customers/entities/delivery_counter.tscn") as PackedScene).instantiate() as E_DeliveryCounter
	_world.add_entity(counter)
	CustomerFlowService.start_visit(flow, _visit, 1)
	_customer = CustomerFlowQueries.customer_for(_visit.visit_id) as E_Customer
	(_customer as Node as RigidBody3D).freeze = true
	(_customer.get_node("CharacterFeedback") as CharacterFeedback).footsteps_enabled = false
	_actor = Entity.new()
	_actor.component_resources = [C_GrabControl.new()]
	_world.add_entity(_actor)


## Закрывает диалог, удаляет World и освобождает глобальную ссылку ECS.
func after_each() -> void:
	for node: Node in get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP):
		(node as CustomerDialoguePanel).close_dialogue()
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


#endregion

#region Авторские сцена, диалог и анимация
## Профиль выбирает prefab и диалог интересов; закрытие возвращает ввод игроку.
func test_profile_selects_copyable_scene_and_custom_dialogue_with_interests() -> void:
	assert_eq(_customer.scene_file_path, _visit.definition.customer_scene_path)
	assert_not_null(_customer.navigation_agent)
	assert_not_null(_customer.get_node_or_null("InspectionParcelSlot"))
	assert_true(_visit.started)
	assert_eq(_visit.visit_count, 1)
	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	assert_true(CustomerDialogueService.request_open(_actor, _customer))

	var panel: CustomerDialoguePanel = get_tree().get_first_node_in_group(CustomerDialogueService.ACTIVE_GROUP) as CustomerDialoguePanel
	assert_not_null(panel)
	assert_eq(panel._resource.resource_path, _visit.definition.dialogue_resource_path)
	for frame: int in 8:
		if panel._line != null:
			break

		await get_tree().process_frame
	assert_not_null(panel._line)
	assert_true(panel._text.text.contains("Рабочая одежда"))
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	panel.close_dialogue()
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
	assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)


## Поза осмотра уступает ходьбе и действующей боевой анимации; отсутствующий клип даёт Idle.
func test_authored_stationary_pose_preserves_walk_and_combat_animation_priority() -> void:
	var player: AnimationPlayer = AnimationPlayer.new()
	var library: AnimationLibrary = AnimationLibrary.new()
	for name_text: StringName in [&"Idle", &"Walk", &"Inspect"]:
		library.add_animation(name_text, Animation.new())
	player.add_animation_library(&"", library)
	_customer.add_child(player)
	_customer.animation_player = player
	_customer.inspection_animation = &"Inspect"

	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.INSPECTING
	_customer._process(0.0)
	assert_eq(player.current_animation, "Inspect")
	(_customer as Node as RigidBody3D).linear_velocity = Vector3.FORWARD
	_customer._process(0.0)
	assert_eq(player.current_animation, "Walk")
	(_customer as Node as RigidBody3D).linear_velocity = Vector3.ZERO
	_customer.inspection_animation = &"UnassignedClip"
	_customer._process(0.0)
	assert_eq(player.current_animation, "Idle", "Missing authored clip safely uses Idle")

	var combat: C_NpcCombat = _customer.get_component(C_NpcCombat) as C_NpcCombat
	combat.animation_driven = true
	combat.phase = C_NpcCombat.Phase.WINDUP
	player.play(&"Inspect")
	agent.phase = C_CustomerAgent.Phase.WAITING
	_customer._process(0.0)
	assert_eq(player.current_animation, "Inspect", "Service pose must not override combat's active method-track animation")

#endregion
