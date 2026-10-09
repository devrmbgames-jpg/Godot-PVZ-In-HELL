extends Node
## Проверяет реальные удары Jolt и историческую эскалацию клиента в боевой сценарий main_level.

const FRAME_DELTA: float = 1.0 / 60.0

var _level: Node = null
var _actor: Entity = null


#region Порядок сценария
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _physical_impacts()
	await _customer_combat()
	print("NPC melee/ranged animation-ready combat light escalation navigation weapon and real R08 impacts smoke PASS")
	get_tree().quit.call_deferred()


#endregion

#region Изолированные удары Jolt
## Проверяет реальные слабый и тяжёлый контакты игрока и клиента через общую цепочку урона.
func _physical_impacts() -> void:
	var world: World = World.new()
	add_child(world)
	ECS.world = world
	world.add_observer(O_Damage.new())
	world.add_observer(O_HealthLifecycle.new())
	world.add_system(S_Impact.new())
	var characters: Array[Entity] = []
	for index: int in 2:
		var scene: PackedScene = load("res://content/domains/customers/entities/customer.tscn" if index == 1 else "res://content/domains/motion/entities/physical_character.tscn") as PackedScene
		var target: Entity = scene.instantiate() as Entity
		var body: RigidBody3D = target as Node as RigidBody3D
		body.freeze = true
		if index == 0:
			var collision: CollisionShape3D = CollisionShape3D.new()
			var shape: CapsuleShape3D = CapsuleShape3D.new()
			shape.radius = 0.3
			shape.height = 1.7
			collision.shape = shape
			collision.position.y = 0.85
			body.add_child(collision)
		EntityCompositionFixture.register(world, target)
		body.global_position = Vector3(index * 5.0, 0, 0)
		characters.append(target)
	for target: Entity in characters:
		var prop: Entity = (load("res://content/domains/interaction/entities/box.tscn") as PackedScene).instantiate() as Entity
		EntityCompositionFixture.register(world, prop)
		var body: RigidBody3D = prop as Node as RigidBody3D
		body.gravity_scale = 0.0
		body.mass = 40.0
		body.global_position = (target as Node as Node3D).global_position + Vector3(0, 0.7, -1.0)
		body.linear_velocity = Vector3(0, 0, 1.0)
		for tick: int in 90:
			await get_tree().physics_frame
			world.process(FRAME_DELTA)
		var health: C_Health = target.get_component(C_Health) as C_Health
		assert(health.current == 100.0, "A weak real touch must not hurt either living character")
		body.freeze = true
		body.global_position = (target as Node as Node3D).global_position + Vector3(0, 0.7, -2.0)
		body.linear_velocity = Vector3.ZERO
		await get_tree().physics_frame
		body.freeze = false
		body.linear_velocity = Vector3(0, 0, 15.0)
		for tick: int in 90:
			await get_tree().physics_frame
			world.process(FRAME_DELTA)
			if health.current < 100.0:
				break

		assert(health.current < 100.0, "Real heavy impact must use R08 for Player and Customer")
		assert(health.current >= 75.0, "R08 living per-hit cap must remain authoritative")
		world.remove_entity(prop)
	while not world.entities.is_empty():
		world.remove_entity(world.entities.back() as Entity)
	world.purge(false)
	world.free()
	ECS.world = null


#endregion

#region Исторический бой в основной сцене
## Историческая световая эскалация проверяет преследование, дальнюю атаку и самооборону игрока.
func _customer_combat() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as E_PhysicalCharacter
	var actor_body: Node3D = _actor as Node as Node3D
	actor_body.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Historical escalation uses a dedicated visit, independent of district deliveries.
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = null
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"smoke/combat"
	visit.definition = DEF_Customer.new()
	visit.started = true
	visit.visit_count = 1
	flow.visits = [visit]
	var customer: E_NpcCharacter = (load("res://content/domains/customers/entities/customer.tscn") as PackedScene).instantiate() as E_NpcCharacter
	(customer.get_node("CharacterFeedback") as CharacterFeedback).footsteps_enabled = false
	var customer_body: RigidBody3D = customer as Node as RigidBody3D
	customer_body.position = CustomerFlowQueries.counter().waiting_position()
	_level.add_child(customer_body)
	EntityCompositionFixture.register(ECS.world, customer, false)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = visit.visit_id
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var original_rid: RID = customer_body.get_rid()
	var definition: DEF_Challenge = load("res://content/domains/challenges/definitions/def_challenge_light_entrance.tres") as DEF_Challenge
	var rule: DEF_LightChallengeCondition = definition.condition as DEF_LightChallengeCondition
	assert(LightCircuitService.set_by_id(rule.circuit_id, true))
	assert(ChallengeService.debug_start(customer, _actor, definition))
	var npc_state: C_NpcCombat = customer.get_component(C_NpcCombat) as C_NpcCombat
	npc_state.ranged_attacks = [load("res://content/domains/combat/definitions/def_npc_shot.tres") as DEF_NpcAttack]
	var authored_melee: Array[DEF_NpcAttack] = [load("res://content/domains/combat/definitions/def_npc_punch.tres") as DEF_NpcAttack]
	npc_state.melee_attacks = []

	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	GameTimeFixture.gameplay(ECS.world, challenge.definition.timeout_seconds)
	assert(challenge.result == ChallengeResult.Type.FAILURE)
	assert((customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase == C_CustomerAgent.Phase.AGGRESSIVE)
	assert(CombatQueries.target_for(customer) == _actor)
	assert(customer_body.get_rid() == original_rid and customer.navigation_agent != null)
	var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent
	assert(intent.move_uses_entity and intent.movement_active, "Combat must use generic NPC pursuit")
	assert(intent.arrival_distance > npc_state.ranged_attacks[0].minimum_range and intent.arrival_distance < npc_state.ranged_attacks[0].maximum_range, "Ranged-only NPC must stop within its usable attack range")
	npc_state.melee_attacks = authored_melee
	CombatService.end_combat(customer)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)

	var player_health: C_Health = _actor.get_component(C_Health) as C_Health
	actor_body.global_position = customer_body.global_position + Vector3(0, 0, 1.3)
	for frame: int in 240:
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		ECS.world.process(FRAME_DELTA, "Physics")
		await get_tree().physics_frame
		if player_health.current < 100.0:
			break

	assert(player_health.current < 100.0, "Escalated Customer must actually hit Player")
	# The HUD shows its compact first line; the full diagnostic retains combat details.
	DebugHudService.set_enabled(true)
	await get_tree().process_frame
	var summary: String = CombatPresentation.debug_text(_actor)
	assert(summary.contains("Задача:") and summary.contains("cooldown") and summary.contains("Дистанция"))
	var debug: Label = _level.get_node("InteractionHud/Overlay/PlayerDebugPanel/Debug/CombatDebug") as Label
	assert(debug.text == summary.split("\n")[0])
	var weapon: Entity = _level.get_node("Entityes/UtilityBlade") as Entity
	var weapon_body: RigidBody3D = weapon as Node as RigidBody3D
	weapon_body.global_position = (_actor as E_PhysicalCharacter).right_hand_slot.global_position
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	weapon.add_relationship(Relationship.new(grip, _actor))
	assert(GrabQueries.held_relationship(weapon) != null)

	var head: Node3D = (_actor as E_PhysicalCharacter).head_axis_x
	head.look_at(CombatGeometry.aim_point(customer))
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	controller.action_main_pressed = true
	controller.physical_override = false
	for strike: int in 3:
		controller.input_tick += 1
		InteractionInputFixture.advance(_actor)
		assert(controller.action_main_pressed and GrabQueries.held_relationship(weapon) != null)
		GameTimeFixture.gameplay(ECS.world, 1.0)
	assert(customer.has_component(C_Death))
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	assert(visit.finished and visit.customer_dead and visit.defeated_by_player)
	assert(visit.last_combat_context != null and visit.last_combat_context.reason == CombatContext.Reason.SELF_DEFENSE)
	_level.free()
	_level = null
	_actor = null
	ECS.world = null


#endregion
