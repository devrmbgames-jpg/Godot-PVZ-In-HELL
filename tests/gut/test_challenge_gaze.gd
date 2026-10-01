extends GutTest

const FRAME_DELTA: float = 0.1

var _world: World = null
var _actor: E_RigidBodyCharacter = null
var _subject: E_Customer = null
var _state: C_Challenge = null
var _observation: C_GazeChallenge = null
var _rule: DEF_GazeChallengeCondition = null
var _visit: CustomerVisit = null
var _escalations: int = 0


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_ChallengeGaze.new())
	_world.add_system(S_ChallengeRuntime.new())
	var receiver: S_CustomerChallengeOutcome = S_CustomerChallengeOutcome.new()
	receiver.escalation_requested.connect(_on_escalation)
	_world.add_system(receiver)
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


func test_geometry_angle_distance_boundaries_and_invalid_direction() -> void:
	var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_rule.half_angle_degrees))
	GazeTrackingService.measure_geometry(Vector3.ZERO, Vector3.FORWARD, direction * 3.0, _rule, _observation)
	assert_true(_observation.within_angle)
	assert_true(_observation.within_range)
	GazeTrackingService.measure_geometry(Vector3.ZERO, Vector3.FORWARD, Vector3.FORWARD * _rule.maximum_distance, _rule, _observation)
	assert_true(_observation.within_range)
	GazeTrackingService.measure_geometry(Vector3.ZERO, Vector3.FORWARD, Vector3.FORWARD * (_rule.maximum_distance + 0.1), _rule, _observation)
	assert_false(_observation.within_range)
	GazeTrackingService.measure_geometry(Vector3.ZERO, Vector3.FORWARD, Vector3.BACK, _rule, _observation)
	assert_false(_observation.within_angle)
	GazeTrackingService.measure_geometry(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, _rule, _observation)
	assert_false(_observation.sample_valid)


func test_actual_head_pose_and_physics_wall_determine_attention() -> void:
	GazeTrackingService.sample(_actor, _subject, _rule, _observation)
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
	GazeTrackingService.sample(_actor, _subject, _rule, _observation)
	assert_true(_observation.within_angle)
	assert_false(_observation.line_of_sight)
	assert_false(_observation.attention)
	wall.free()
	await get_tree().physics_frame
	_actor.head_axis_x.rotation.y = PI
	GazeTrackingService.sample(_actor, _subject, _rule, _observation)
	assert_false(_observation.within_angle)
	assert_false(_observation.attention)


func test_actor_camera_pose_overrides_head_and_unrelated_camera_does_not() -> void:
	var camera: Camera3D = Camera3D.new()
	_actor.head_axis_x.add_child(camera)
	camera.make_current()
	camera.rotation.y = PI
	GazeTrackingService.sample(_actor, _subject, _rule, _observation)
	assert_false(_observation.attention)
	camera.rotation.y = 0.0
	GazeTrackingService.sample(_actor, _subject, _rule, _observation)
	assert_true(_observation.attention)
	var unrelated: Camera3D = Camera3D.new()
	add_child(unrelated)
	unrelated.rotation.y = PI
	unrelated.make_current()
	GazeTrackingService.sample(_actor, _subject, _rule, _observation)
	assert_true(_observation.attention, "Another actor's camera must not supply this actor's gaze")
	unrelated.free()


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


func test_keep_looking_is_inverse_configuration_and_compliance_is_not_early_success() -> void:
	_state.definition = (load("res://content/definitions/gameplay/challenges/def_challenge_keep_looking.tres") as DEF_Challenge).duplicate(true) as DEF_Challenge
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


func test_preparation_and_short_final_violation_can_finish_successfully() -> void:
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
