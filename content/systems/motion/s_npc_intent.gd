extends System
## Produces semantic intent only. Character solvers retain physics authority.
class_name S_NpcIntent


func query() -> QueryBuilder:
	return q.with_all([C_NpcIntent, C_Controller]).with_none([C_PlayerInputController]).iterate([C_NpcIntent, C_Controller])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var intents: Array = components[0]
	var controllers: Array = components[1]
	for index: int in entities.size():
		_apply(entities[index], intents[index] as C_NpcIntent, controllers[index] as C_Controller)


func _apply(actor: Entity, intent: C_NpcIntent, controller: C_Controller) -> void:
	var body: Node3D = actor as Node as Node3D
	if body == null:
		return
	controller.direction_motion = Vector3.ZERO
	intent.navigation_pending = false
	intent.navigation_blocked = false
	if actor.has_component(C_Death):
		intent.movement_active = false
		controller.direction_look = Vector3.ZERO
		for relation: Relationship in actor.relationships:
			if relation.relation is R_NpcMoveTarget or relation.relation is R_NpcLookTarget:
				cmd.remove_relationship(actor, relation)
		return
	if intent.movement_active:
		var position: Vector3 = intent.move_position
		var target: Node3D = _target(actor, R_NpcMoveTarget)
		if intent.move_uses_entity and target == null:
			intent.movement_active = false
			intent.arrived = false
		else:
			if target != null:
				position = target.global_position
			var direction: Vector3 = position - body.global_position
			direction.y = 0.0
			intent.distance_to_target = direction.length()
			intent.arrived = intent.distance_to_target <= intent.arrival_distance
			if not intent.arrived:
				var npc: E_NpcCharacter = actor as E_NpcCharacter
				if intent.navigation_enabled and npc != null and npc.navigation_agent != null:
					direction = _path_direction(npc.navigation_agent, intent, body.global_position, position)
				controller.direction_motion = direction.normalized() * clampf(intent.speed_fraction, 0.0, 1.0)
	var look_direction: Vector3 = controller.direction_motion
	if intent.look_mode == C_NpcIntent.LookMode.HOLD:
		return
	if intent.look_mode == C_NpcIntent.LookMode.TARGET:
		var target: Node3D = _target(actor, R_NpcLookTarget)
		if not intent.look_uses_entity or target != null:
			var position: Vector3 = intent.look_position
			if target != null:
				position = target.global_position
			var origin: Vector3 = body.global_position
			var character: E_RigidBodyCharacter = actor as E_RigidBodyCharacter
			if character != null and character.head_axis_x != null:
				origin = character.head_axis_x.global_position
			look_direction = position + intent.look_offset - origin
		else:
			intent.look_mode = C_NpcIntent.LookMode.MOVEMENT
			intent.look_uses_entity = false
	if not look_direction.is_zero_approx():
		controller.direction_look = look_direction.normalized()


func _path_direction(
	agent: NavigationAgent3D,
	intent: C_NpcIntent,
	origin: Vector3,
	goal: Vector3,
) -> Vector3:
	var map: RID = agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		intent.navigation_pending = true
		return Vector3.ZERO
	if not agent.target_position.is_equal_approx(goal) or agent.get_current_navigation_path().is_empty():
		agent.target_position = goal
	if not is_equal_approx(agent.target_desired_distance, intent.arrival_distance):
		agent.target_desired_distance = intent.arrival_distance
	var waypoint: Vector3 = agent.get_next_path_position()
	if agent.is_navigation_finished():
		intent.navigation_blocked = not intent.arrived
		return Vector3.ZERO
	var direction: Vector3 = waypoint - origin
	direction.y = 0.0
	return direction


func _target(actor: Entity, relation_type: Script) -> Node3D:
	for relation: Relationship in actor.relationships:
		if relation.relation.get_script() == relation_type:
			if EntityAvailability.contains(relation.target, ECS.world):
				var target: Entity = relation.target as Entity
				var node: Node3D = target as Node as Node3D
				if not target.has_component(C_Death) and node != null:
					return node
			cmd.remove_relationship(actor, relation)
	return null
