extends Node
## Real Jolt support: floor -> movable box -> airborne, then the default floor customer/HUD.

const FRAME_DELTA: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 180
const CUSTOMER_WAIT_FRAMES: int = 900

var _world: World = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _physical_support()
	await _main_customer()
	print("Challenge floor real support box airborne damage default customer HUD and cleanup smoke PASS")
	get_tree().quit.call_deferred()


func _physical_support() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_FloorChallengeSpawn.new())
	_world.add_observer(O_ChallengeLifecycle.new())
	_world.add_observer(O_Damage.new())
	_world.add_system(S_ChallengeFloorSetup.new())
	_world.add_system(S_FloorHazard.new())
	_world.add_system(S_ChallengeRuntime.new())

	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new()]
	_world.add_entity(session)
	(session.get_component(C_DayCycle) as C_DayCycle).phase = C_DayCycle.Phase.DAY
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(8.0, 0.2, 8.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	_world.add_child(floor_body)

	var box: RigidBody3D = (load("res://content/entities/props/box.tscn") as PackedScene).instantiate() as RigidBody3D
	box.position.x = 1.5
	_world.add_entity(box as Node as Entity)
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(load("res://content/entities/characters/e_rigid_body_character.gd"))
	body.collision_layer = 4
	body.collision_mask = 31
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.can_sleep = false
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.axis_lock_angular_z = true

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape_node.shape = capsule
	shape_node.position.y = 0.85
	body.add_child(shape_node)
	var actor: Entity = body as Node as Entity
	actor.component_resources = [C_Motion.new(), C_Health.new()]
	_world.add_entity(actor)

	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	motion.control_enabled = false
	var health: C_Health = actor.get_component(C_Health) as C_Health
	await _wait_support(motion, floor_body.get_rid())
	assert(absf(motion.floor_contact_position.y) < 0.06)
	var subject: Entity = Entity.new()
	var challenge: C_Challenge = C_Challenge.new()
	challenge.definition = (load("res://content/definitions/gameplay/challenges/def_challenge_floor.tres") as DEF_Challenge).duplicate(true) as DEF_Challenge
	challenge.definition.preparation_seconds = 0.0
	challenge.definition.timeout_seconds = 30.0
	challenge.definition.violation_grace_seconds = 10.0
	(challenge.definition.condition as DEF_FloorChallengeCondition).world_position = Vector3.ZERO
	subject.component_resources = [challenge, C_FloorChallenge.new()]
	_world.add_entity(subject)
	assert(ChallengeService.arm(subject, actor) and ChallengeService.activate(subject))
	for frame: int in 36:
		_world.process(FRAME_DELTA)
		await get_tree().physics_frame
	assert(health.current < 100.0, "Actual floor support must feed O_Damage")
	# Fixture relocation only: the ensuing support is established by real gravity/contact.
	body.global_position = Vector3(1.5, 0.55, 0.0)
	body.linear_velocity = Vector3.ZERO
	await _wait_support(motion, box.get_rid())
	assert(motion.floor_contact_position.y > 0.3)

	var safe_health: float = health.current
	for frame: int in 90:
		_world.process(FRAME_DELTA)
		await get_tree().physics_frame
	assert(health.current == safe_health, "Player on a movable box must not be damaged by the floor projection")
	body.global_position.y = 2.0
	body.linear_velocity = Vector3.ZERO
	for frame: int in 3:
		await get_tree().physics_frame
	assert(not motion.is_on_floor and not motion.floor_body_rid.is_valid())
	_world.process(0.6)
	assert(health.current == safe_health, "Airborne projection must not be a support hit")
	ChallengeService.cancel(subject)
	assert(_world.query.with_all([C_FloorHazard]).execute().is_empty())
	_world.purge(false)
	_world.free()
	_world = null
	ECS.world = null
	await get_tree().process_frame


func _wait_support(motion: C_Motion, expected: RID) -> void:
	for frame: int in SETTLE_FRAMES:
		await get_tree().physics_frame
		if motion.is_on_floor and motion.floor_body_rid == expected:
			return

	assert(false, "Real physics support must match the floor/box collider")


func _main_customer() -> void:
	var level: Node = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	add_child(level)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	(actor as Node as RigidBody3D).freeze = true
	for frame: int in CUSTOMER_WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	assert(PackageRegistrationService.register_package(CustomerFlowService.parcel_for("base_supply:1:tools")).outcome == PackageScanResult.Outcome.REGISTERED)
	var cycle: C_DayCycle = DayPhaseService.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	var customer: E_Customer = null
	for frame: int in CUSTOMER_WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		customer = CustomerFlowService.waiting_customer()
		if customer != null:
			break

	assert(customer != null)
	var visit: CustomerVisit = CustomerFlowService.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	assert(visit.definition.key == &"floor_customer")
	var context: CustomerDialogueContext = CustomerDialogueContext.new(actor, customer)
	assert(context.begin() and context.arm_challenge())
	context.end()
	var state: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	assert(state.phase == C_Challenge.Phase.ACTIVE)
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(ECS.world.query.with_all([C_FloorHazard]).execute().size() == 1)
	assert(level.get_node("Entityes/FloorSafeBox1") is RigidBody3D)
	assert(level.get_node("Entityes/FloorSafeBox2") is RigidBody3D)
	assert(level.get_node("Entityes/FloorSafeBox3") is RigidBody3D)
	await get_tree().process_frame

	var debug: Label3D = customer.get_node("DebugStatus") as Label3D
	for frame: int in 8:
		if debug.text.contains("Пол:") and debug.text.contains("Таймер урона"):
			break

		await get_tree().process_frame
	assert(debug.text.contains("Пол:") and debug.text.contains("Таймер урона"), "Floor debug must show contact and damage clock: " + debug.text)
	ECS.world.process(state.definition.timeout_seconds, "GamePlay")
	assert(state.result == ChallengeResult.Type.SUCCESS)
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(ECS.world.query.with_all([C_FloorHazard]).execute().is_empty())
	assert(visit.challenge_result == &"success")
	level.free()
	ECS.world = null
