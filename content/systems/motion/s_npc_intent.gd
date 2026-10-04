extends System
## Преобразует цели NPC в Controller через навигацию; трансформ и скорость исполняет тело.
class_name S_NpcIntent

const MAX_AVOIDANCE_AGE_FRAMES: int = 2
const MOVING_AVOIDANCE_PRIORITY: float = 0.5
const WAITING_AVOIDANCE_PRIORITY: float = 1.0
const MINIMUM_NAVIGATION_SPEED: float = 0.001
const MAX_PASSING_NAV_DISTANCE: float = 0.2

#region Выбор и подготовка намерений
## Выбирает участвующих NPC с Controller, исключая управление вводом игрока.
func query() -> QueryBuilder:
	return q.with_all([C_NpcIntent, C_Controller]).with_none([C_PlayerInputController]).enabled().iterate([C_NpcIntent, C_Controller])


## Обновляет маршрут, локальное avoidance и взгляд без прямых записей физического состояния.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var intents: Array = components[0]
	var controllers: Array = components[1]
	# Соседи берутся из общего запроса: GECS обрабатывает торговцев и клиентов разными архетипами.
	var neighbours: Array[Entity] = ECS.world.query.with_all([C_NpcIntent, C_Controller]).with_none([C_PlayerInputController, C_Death]).enabled().execute()
	for index: int in entities.size():
		_apply(entities[index], intents[index] as C_NpcIntent, controllers[index] as C_Controller, neighbours)


#endregion

#region Исполнение цели
func _apply(actor: Entity, intent: C_NpcIntent, controller: C_Controller, neighbours: Array[Entity]) -> void:
	var body: Node3D = actor as Node as Node3D
	if body == null:
		return

	controller.direction_motion = Vector3.ZERO
	controller.limit_motion_velocity = false
	intent.navigation_pending = false
	intent.navigation_blocked = false
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	if npc != null:
		npc.sync_navigation_lifecycle(not actor.has_component(C_Death))
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
				var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
				if route != null and not route.reachable:
					intent.navigation_blocked = true
					_apply_avoidance(actor, intent, controller, neighbours)
					return
				if route != null and not route.points.is_empty() and not intent.move_uses_entity:
					var tolerance: float = DistrictPopulationService.current().definition.waypoint_distance
					while route.point_index < route.points.size() - 1 and body.global_position.distance_to(route.points[route.point_index]) <= tolerance:
						route.point_index += 1
					position = route.points[route.point_index]
				if intent.navigation_enabled and npc != null and npc.navigation_agent != null:
					direction = _path_direction(npc.navigation_agent, intent, body.global_position, position)
				controller.direction_motion = direction.normalized() * clampf(intent.speed_fraction, 0.0, 1.0)

	var look_direction: Vector3 = controller.direction_motion
	_apply_avoidance(actor, intent, controller, neighbours)
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


#endregion

#region Локальное уклонение
func _apply_avoidance(actor: Entity, intent: C_NpcIntent, controller: C_Controller, neighbours: Array[Entity]) -> void:
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	if npc == null or npc.navigation_agent == null:
		return

	var agent: NavigationAgent3D = npc.navigation_agent
	if not intent.navigation_enabled or not agent.avoidance_enabled:
		return

	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	if motion == null:
		return

	var speed: float = CharacterMotionSolver.effective_speed(
		motion, actor.get_component(C_CarryLoad) as C_CarryLoad,
		actor.get_component(C_Strength) as C_Strength, actor.get_component(C_Hunger) as C_Hunger,
	)
	agent.max_speed = maxf(speed, MINIMUM_NAVIGATION_SPEED)
	var moving: bool = not controller.direction_motion.is_zero_approx() and motion.control_enabled
	agent.avoidance_priority = MOVING_AVOIDANCE_PRIORITY if moving else WAITING_AVOIDANCE_PRIORITY
	var preferred: Vector3 = _passing_direction(npc, intent, controller.direction_motion, neighbours) if moving else Vector3.ZERO
	agent.velocity = preferred * speed
	controller.limit_motion_velocity = true
	controller.direction_motion = Vector3.ZERO
	# Ожидающий NPC становится неподвижным препятствием для обходящих соседей.
	if moving and intent.avoidance_frame >= 0 and Engine.get_physics_frames() - intent.avoidance_frame <= MAX_AVOIDANCE_AGE_FRAMES:
		controller.direction_motion = intent.avoidance_velocity.limit_length(speed) / maxf(speed, MINIMUM_NAVIGATION_SPEED)


func _passing_direction(npc: E_NpcCharacter, intent: C_NpcIntent, desired: Vector3, neighbours: Array[Entity]) -> Vector3:
	if intent.passing_distance <= 0.0 or intent.passing_bias <= 0.0:
		return desired

	var forward: Vector3 = desired.normalized()
	var right: Vector3 = forward.cross(Vector3.UP)
	var nearest: float = intent.passing_distance
	var obstacle: E_NpcCharacter = null
	for actor: Entity in neighbours:
		var other: E_NpcCharacter = actor as E_NpcCharacter
		if other == null or other == npc or other.navigation_agent == null or actor.has_component(C_Death):
			continue

		var offset: Vector3 = other.global_position - npc.global_position
		if absf(offset.y) > npc.navigation_agent.height:
			continue

		offset.y = 0.0
		var distance: float = offset.length()
		var clearance: float = npc.navigation_agent.radius + other.navigation_agent.radius
		if distance < nearest and offset.dot(forward) > 0.0 and absf(offset.dot(right)) < clearance:
			nearest = distance
			obstacle = other
	if obstacle == null:
		return desired

	var offset: Vector3 = obstacle.global_position - npc.global_position
	var side: Vector3 = -right if offset.dot(right) > 0.0 else right
	var clearance: float = npc.navigation_agent.radius + obstacle.navigation_agent.radius
	var map: RID = npc.navigation_agent.get_navigation_map()
	var candidate: Vector3 = npc.global_position + side * clearance
	if NavigationServer3D.map_get_closest_point(map, candidate).distance_to(candidate) > MAX_PASSING_NAV_DISTANCE:
		side = -side
		candidate = npc.global_position + side * clearance
		if NavigationServer3D.map_get_closest_point(map, candidate).distance_to(candidate) > MAX_PASSING_NAV_DISTANCE:
			return desired
	return (forward + side * intent.passing_bias).normalized() * desired.length()


#endregion

#region Путь и живые цели
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
	# Допуск конечной цели не должен останавливать агента до промежуточной точки маршрута.
	var navigation_arrival_distance: float = minf(intent.arrival_distance, agent.path_desired_distance)
	if not is_equal_approx(agent.target_desired_distance, navigation_arrival_distance):
		agent.target_desired_distance = navigation_arrival_distance

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

#endregion
