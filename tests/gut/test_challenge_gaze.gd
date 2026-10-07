extends GutTest
## Проверяет геометрию взгляда, реальные укрытия, предупреждение и однократный исход авторского испытания.

const FRAME_DELTA: float = 0.1

var _world: World = null
var _actor: E_RigidBodyCharacter = null
var _subject: E_Customer = null
var _state: C_Challenge = null
var _observation: C_GazeChallenge = null
var _rule: DEF_GazeChallengeCondition = null
var _visit: CustomerVisit = null
var _escalations: int = 0


#region Окружение взгляда
## Создаёт физического наблюдателя, цель и короткий авторский профиль взгляда.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_ChallengeGaze.new())
	_world.add_system(S_ChallengeRuntime.new())
	var receiver: O_CustomerChallengeOutcome = O_CustomerChallengeOutcome.new()
	receiver.escalation_requested.connect(_on_escalation)
	_world.add_observer(receiver)
	_world.add_observer(O_ChallengeLifecycle.new())

	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_CustomerFlow.new(), C_Wallet.new()]
	_world.add_entity(session)
	(session.get_component(C_DayCycle) as C_DayCycle).phase = C_DayCycle.Phase.DAY
	_actor = _character(false)
	_subject = _character(true) as E_Customer
	(_subject as Node as Node3D).position = Vector3(0.0, 0.0, -3.0)
	_state = C_Challenge.new()
	_state.definition = (load("res://content/definitions/gameplay/challenges/def_challenge_dont_look.tres") as DEF_Challenge).duplicate(true) as DEF_Challenge
	# Тест механики использует короткие интервалы; авторские сроки проверяются отдельно.
	_state.definition.violation_grace_seconds = 3.0
	_observation = C_GazeChallenge.new()

	var agent: C_CustomerAgent = C_CustomerAgent.new()
	agent.visit_id = &"gaze-test"
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_subject.add_components([_state, _observation, agent])
	_rule = _state.definition.condition as DEF_GazeChallengeCondition
	_visit = CustomerVisit.new()
	_visit.visit_id = agent.visit_id
	_visit.definition = DEF_Customer.new()
	_visit.started = true
	_visit.visit_count = 1
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(_visit)
	_escalations = 0
	await get_tree().physics_frame
	await get_tree().physics_frame


## Удаляет World и очищает ссылки состояния взгляда.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_actor = null
	_subject = null
	_state = null
	_observation = null
	_rule = null
	_visit = null


func _character(customer: bool) -> E_RigidBodyCharacter:
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.collision_layer = 2 if customer else 4
	body.set_script(load("res://content/entities/customers/e_customer.gd" if customer else "res://content/entities/characters/e_rigid_body_character.gd"))
	var entity: E_RigidBodyCharacter = body as Node as E_RigidBodyCharacter
	var eyes: Marker3D = Marker3D.new()
	eyes.position.y = 1.5
	body.add_child(eyes)
	entity.head_axis_x = eyes

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	shape_node.shape = shape
	shape_node.position.y = 0.85
	body.add_child(shape_node)
	_world.add_entity(entity)
	return entity


func _start() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	assert_true(ChallengeService.activate(_subject))
	_world.process(_state.definition.preparation_seconds)


func _on_escalation(_customer: Entity, _player: Entity, _event: ChallengeResolution) -> void:
	_escalations += 1


#endregion

#region Геометрия и реальное восприятие
## Проверяет включительные границы угла/расстояния и недопустимое нулевое направление.
func test_geometry_angle_distance_boundaries_and_invalid_direction() -> void:
	var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_rule.half_angle_degrees))
	GazeTrackingGeometry.measure_geometry(Vector3.ZERO, Vector3.FORWARD, direction * 3.0, _rule, _observation)
	assert_true(_observation.within_angle)
	assert_true(_observation.within_range)
	GazeTrackingGeometry.measure_geometry(Vector3.ZERO, Vector3.FORWARD, Vector3.FORWARD * _rule.maximum_distance, _rule, _observation)
	assert_true(_observation.within_range)
	GazeTrackingGeometry.measure_geometry(Vector3.ZERO, Vector3.FORWARD, Vector3.FORWARD * (_rule.maximum_distance + 0.1), _rule, _observation)
	assert_false(_observation.within_range)
	GazeTrackingGeometry.measure_geometry(Vector3.ZERO, Vector3.FORWARD, Vector3.BACK, _rule, _observation)
	assert_false(_observation.within_angle)
	GazeTrackingGeometry.measure_geometry(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, _rule, _observation)
	assert_false(_observation.sample_valid)


## Поза головы и реальная стена определяют внимание, исключая собственный collider.
func test_actual_head_pose_and_physics_wall_determine_attention() -> void:
	GazeTrackingGeometry.sample(_actor, _subject, _rule, _observation)
	assert_true(_observation.attention, "Actor collider must be excluded and target collider must count as visible")
	var wall: StaticBody3D = StaticBody3D.new()
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE
	shape_node.shape = shape
	wall.add_child(shape_node)
	wall.position = Vector3(0.0, 1.5, -1.5)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	GazeTrackingGeometry.sample(_actor, _subject, _rule, _observation)
	assert_true(_observation.within_angle)
	assert_false(_observation.line_of_sight)
	assert_false(_observation.attention)
	wall.free()
	await get_tree().physics_frame
	_actor.head_axis_x.rotation.y = PI
	GazeTrackingGeometry.sample(_actor, _subject, _rule, _observation)
	assert_false(_observation.within_angle)
	assert_false(_observation.attention)


## Камера участника уточняет взгляд; чужая активная камера не подменяет его.
func test_actor_camera_pose_overrides_head_and_unrelated_camera_does_not() -> void:
	var camera: Camera3D = Camera3D.new()
	_actor.head_axis_x.add_child(camera)
	camera.make_current()
	camera.rotation.y = PI
	GazeTrackingGeometry.sample(_actor, _subject, _rule, _observation)
	assert_false(_observation.attention)
	camera.rotation.y = 0.0
	GazeTrackingGeometry.sample(_actor, _subject, _rule, _observation)
	assert_true(_observation.attention)

	var unrelated: Camera3D = Camera3D.new()
	add_child(unrelated)
	unrelated.rotation.y = PI
	unrelated.make_current()
	GazeTrackingGeometry.sample(_actor, _subject, _rule, _observation)
	assert_true(_observation.attention, "Another actor's camera must not supply this actor's gaze")
	unrelated.free()


#endregion

#region Авторские предупреждения и исход
## Непрерывный взгляд даёт предупреждение и одну неудачу; отведение взгляда сбрасывает накопление.
func test_dont_look_warns_resets_and_fails_at_continuous_threshold_once() -> void:
	_start()
	_world.process(1.6)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_gt(GazeChallengePresentation.strength(_state), 0.0)
	assert_string_contains(GazeChallengePresentation.text(_state), "До нарушения")
	_actor.head_axis_x.rotation.y = PI
	_world.process(FRAME_DELTA)
	assert_eq(_state.violation_elapsed, 0.0)
	assert_eq(GazeChallengePresentation.strength(_state), 0.0)
	_actor.head_axis_x.rotation.y = 0.0
	_world.process(2.9)
	assert_eq(_state.result, ChallengeResult.Type.NONE)
	_world.process(0.1)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
	assert_eq(_escalations, 1)
	_world.process(FRAME_DELTA)
	assert_eq(_escalations, 1)
	assert_eq(GazeChallengePresentation.strength(GazeChallengePresentation.state_for(_actor)), 0.0)


## Обратное правило требует сохранять взгляд до окончания, без досрочного успеха.
func test_keep_looking_is_inverse_configuration_and_compliance_is_not_early_success() -> void:
	_state.definition = (load("res://content/definitions/gameplay/challenges/def_challenge_keep_looking.tres") as DEF_Challenge).duplicate(true) as DEF_Challenge
	_state.definition.violation_grace_seconds = 3.0
	_rule = _state.definition.condition as DEF_GazeChallengeCondition
	_start()
	_world.process(4.0)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_eq(_state.violation_elapsed, 0.0)
	_actor.head_axis_x.rotation.y = PI
	_world.process(2.0)
	assert_gt(GazeChallengePresentation.strength(_state), 0.0)
	_actor.head_axis_x.rotation.y = 0.0
	_world.process(FRAME_DELTA)
	assert_eq(_state.violation_elapsed, 0.0)
	_actor.head_axis_x.rotation.y = PI
	_world.process(3.0)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)


## Подготовка и короткое нарушение перед уходом не создают преждевременную неудачу.
func test_preparation_and_short_final_violation_can_finish_successfully() -> void:
	_state.definition.preparation_seconds = 3.0
	assert_true(ChallengeService.arm(_subject, _actor))
	assert_true(ChallengeService.activate(_subject))
	_world.process(_state.definition.preparation_seconds)
	assert_eq(_state.violation_elapsed, 0.0)
	_world.process(0.2)
	ChallengeService.request_departure(_subject)
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	assert_eq(_visit.challenge_satisfaction_delta, 10)
	assert_eq(_escalations, 0)


## Приход запускает искажение сразу; повторный trigger не перезапускает часы.
func test_arrival_definition_and_vignette_start_before_warning_threshold() -> void:
	assert_eq(_state.definition.trigger, DEF_Challenge.Trigger.ON_ARRIVAL)
	assert_eq(_state.definition.preparation_seconds, 0.0)
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	_world.process(FRAME_DELTA)
	var first: float = GazeChallengePresentation.strength(_state)
	assert_gt(first, 0.0, "Even the first sustained gaze frame must darken the screen")
	assert_lt(_state.violation_elapsed, _state.definition.violation_grace_seconds * _rule.warning_fraction)
	_world.process(FRAME_DELTA)
	assert_gt(GazeChallengePresentation.strength(_state), first)
	assert_false(ChallengeService.begin_on_arrival(_subject, _actor), "Arrival cannot restart the timer")
	_actor.head_axis_x.rotation.y = PI
	_world.process(FRAME_DELTA)
	assert_eq(GazeChallengePresentation.strength(_state), 0.0)


#endregion

#region Связь обслуживания и lifecycle
## Только одна настенная подсказка показывает регистрационный номер и очищается вместе с сессией.
func test_wall_clue_uses_one_registered_number_and_clears_with_session() -> void:
	_visit.definition.challenge = _state.definition
	var ledger: C_PackageLedger = C_PackageLedger.new()
	var session: Entity = _world.query.with_all([C_CustomerFlow]).execute_one()
	session.add_component(ledger)
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = _visit.package_id
	record.number = 37
	ledger.records.append(record)

	var clues: Array[Label3D] = []
	var scene: PackedScene = load("res://content/ui/gaze_order_clue.tscn") as PackedScene
	for index: int in 3:
		var clue: Label3D = scene.instantiate() as Label3D
		clue.name = "Clue%d" % index
		add_child(clue)
		clue.set_process(false)
		clues.append(clue)
		assert_eq(GazeOrderCluePresentation.text_for(clue), "")
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))

	var shown: int = 0
	for clue: Label3D in clues:
		var message: String = GazeOrderCluePresentation.text_for(clue)
		if not message.is_empty():
			shown += 1
			assert_eq(message, "ЗАКАЗ\n№037", "Physical package identity is not the player's order number")
	assert_eq(shown, 1)
	ChallengeService.request_departure(_subject)
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	for clue: Label3D in clues:
		assert_eq(GazeOrderCluePresentation.text_for(clue), "")
		clue.free()


## Старое событие прихода активирует авторское испытание до движения к стойке и диалога.
func test_customer_spawn_activates_arrival_challenge_before_approach_and_dialogue() -> void:
	_world.remove_entity(_subject)
	_subject = null
	_actor.add_component(C_PlayerInputController.new())
	var session: Entity = _world.query.with_all([C_CustomerFlow]).execute_one()
	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	flow.visits.clear()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.customer_scene = load("res://content/entities/customers/customer.tscn") as PackedScene

	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"arrival-gaze"
	visit.requires_registered_package = false
	visit.arrival_day = cycle.day_index
	visit.definition = load("res://content/definitions/gameplay/customers/def_customer_gaze.tres") as DEF_Customer
	flow.visits.append(visit)
	var scene: PackedScene = load("res://content/entities/stations/delivery_counter.tscn") as PackedScene
	var station: E_DeliveryCounter = scene.instantiate() as E_DeliveryCounter
	_world.add_entity(station)
	assert_true(CustomerFlowFixture.spawn(flow, cycle))

	var customer: E_Customer = CustomerFlowService.customer_for(visit.visit_id)
	assert_not_null(customer)
	if customer == null:
		return

	(customer as Node as RigidBody3D).freeze = true
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	assert_eq(agent.phase, C_CustomerAgent.Phase.APPROACHING)
	assert_eq(challenge.phase, C_Challenge.Phase.ACTIVE)
	assert_same(ChallengeService.actor_for(customer), _actor)
	assert_true(challenge.consumed, "The challenge is already bound before any dialogue")
	agent.phase = C_CustomerAgent.Phase.WAITING
	CustomerFlowService.greet(customer)
	assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	assert_string_contains((customer.get_node("Message") as Label3D).text, "на стене")
	assert_eq(challenge.phase, C_Challenge.Phase.ACTIVE)


## Авторская накопительная политика сохраняет прежние нарушения после безопасного промежутка.
func test_authored_accumulating_reset_policy_preserves_prior_violations() -> void:
	_state.definition.reset_violation_on_compliance = false
	_start()
	_world.process(2.0)
	_actor.head_axis_x.rotation.y = PI
	_world.process(FRAME_DELTA)
	assert_eq(_state.violation_elapsed, 2.0)
	_actor.head_axis_x.rotation.y = 0.0
	_world.process(1.0)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)


## Снятие живой связи цели отменяет испытание и предупреждение.
func test_target_binding_removal_cancels_and_clears_warning() -> void:
	_start()
	_world.process(2.0)
	var binding: Relationship = _subject.get_relationships(Relationship.new(R_ChallengeActor.new()))[0]
	_subject.remove_relationship(binding)
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_state.violation_elapsed, 0.0)
	assert_false(_observation.sample_valid)
	assert_false(_observation.warning_active)
	assert_null(GazeChallengePresentation.state_for(_actor))
	assert_eq(_visit.challenge_satisfaction_delta, 0)

#endregion
