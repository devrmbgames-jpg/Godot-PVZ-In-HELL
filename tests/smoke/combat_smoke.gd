extends Node
## Проверяет реальные удары Jolt и историческую эскалацию клиента в боевой сценарий main_level.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 900
const UI_WAIT_FRAMES: int = 32

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
		var scene: PackedScene = load("res://content/entities/customers/customer.tscn" if index == 1 else "res://content/entities/characters/physical_character.tscn") as PackedScene
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
		world.add_entity(target)
		body.global_position = Vector3(index * 5.0, 0, 0)
		characters.append(target)
	for target: Entity in characters:
		var prop: Entity = (load("res://content/entities/props/box.tscn") as PackedScene).instantiate() as Entity
		world.add_entity(prop)
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
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as Entity
	var actor_body: RigidBody3D = _actor as Node as RigidBody3D
	actor_body.freeze = true
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	assert(PackageRegistrationService.register_package(CustomerFlowService.parcel_for("base_supply:1:books")).outcome == PackageScanResult.Outcome.REGISTERED)
	var cycle: C_DayCycle = DayPhaseService.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	var customer: E_Customer = null
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		ECS.world.process(FRAME_DELTA, "Physics")
		await get_tree().physics_frame
		customer = CustomerFlowService.waiting_customer()
		if customer != null:
			break

	assert(customer != null)
	var customer_body: RigidBody3D = customer as Node as RigidBody3D
	var original_rid: RID = customer_body.get_rid()
	var visit: CustomerVisit = CustomerFlowService.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	await _acknowledge_challenge(customer)
	var npc_state: C_NpcCombat = customer.get_component(C_NpcCombat) as C_NpcCombat
	var authored_melee: Array[DEF_NpcAttack] = npc_state.melee_attacks
	npc_state.melee_attacks = []

	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	ECS.world.process(challenge.definition.timeout_seconds, "GamePlay")
	assert(challenge.result == ChallengeResult.Type.FAILURE)
	assert((customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase == C_CustomerAgent.Phase.AGGRESSIVE)
	assert(CombatService.target_for(customer) == _actor)
	assert(customer_body.get_rid() == original_rid and customer.navigation_agent != null)
	var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent
	assert(intent.move_uses_entity and intent.movement_active, "Combat must use generic NPC pursuit")
	assert(intent.arrival_distance > npc_state.ranged_attacks[0].minimum_range and intent.arrival_distance < npc_state.ranged_attacks[0].maximum_range, "Ranged-only NPC must stop within its usable attack range")
	npc_state.melee_attacks = authored_melee
	CombatService.end_combat(customer)
	ECS.world.process(FRAME_DELTA, "GamePlay")

	var player_health: C_Health = _actor.get_component(C_Health) as C_Health
	actor_body.global_position = customer_body.global_position + Vector3(0, 0, 1.3)
	for frame: int in 240:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		ECS.world.process(FRAME_DELTA, "Physics")
		await get_tree().physics_frame
		if player_health.current < 100.0:
			break

	assert(player_health.current < 100.0, "Escalated Customer must actually hit Player")
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		var debug: Label = _level.get_node("InteractionHud/Overlay/PlayerDebugPanel/Debug/CombatDebug") as Label
		if debug.text.contains("Задача:") and debug.text.contains("cooldown"):
			break

	var debug: Label = _level.get_node("InteractionHud/Overlay/PlayerDebugPanel/Debug/CombatDebug") as Label
	assert(debug.text.contains("Задача:") and debug.text.contains("cooldown") and debug.text.contains("Дистанция"))
	var weapon: Entity = _level.get_node("Entityes/UtilityBlade") as Entity
	var weapon_body: RigidBody3D = weapon as Node as RigidBody3D
	weapon_body.global_position = (_actor as E_RigidBodyCharacter).right_hand_slot.global_position
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	weapon.add_relationship(Relationship.new(grip, _actor))
	assert(GrabService.held_relationship(weapon) != null)

	var head: Node3D = (_actor as E_RigidBodyCharacter).head_axis_x
	head.look_at(CombatGeometry.aim_point(customer))
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	controller.action_main_pressed = true
	controller.physical_override = false
	for strike: int in 3:
		controller.input_tick += 1
		InteractionActionResolver.handle_input(_actor)
		assert(controller.action_main_pressed and GrabService.held_relationship(weapon) != null)
		ECS.world.process(1.0, "GamePlay")
	assert(customer.has_component(C_Death))
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(visit.finished and visit.customer_dead and visit.defeated_by_player)
	assert(visit.last_combat_context != null and visit.last_combat_context.reason == CombatContext.Reason.SELF_DEFENSE)
	_level.free()
	_level = null
	_actor = null
	ECS.world = null


func _acknowledge_challenge(customer: E_Customer) -> void:
	assert(CustomerDialogueService.start(_actor, customer))
	var panel: CustomerDialoguePanel = null
	var shown: bool = false
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		var panels: Array[Node] = get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP)
		if panels.is_empty():
			continue

		panel = panels[0] as CustomerDialoguePanel
		for node: Node in panel.find_children("*", "RichTextLabel", true, false):
			if (node as RichTextLabel).text.contains("свет"):
				shown = true
		if shown:
			break

	assert(shown and panel != null)
	var acknowledged: bool = false
	for node: Node in panel.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == "Продолжить" and button.visible and not button.disabled:
			button.pressed.emit()
			acknowledged = true
			break

	assert(acknowledged)
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		if get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).is_empty():
			return

	assert(false, "Acknowledgement must close the demand before combat starts")

#endregion
