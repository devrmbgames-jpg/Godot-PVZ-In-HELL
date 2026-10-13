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
	var intent_query: QueryBuilder = q.with_all([C_NpcIntent, C_Controller])
	intent_query.with_none([C_PlayerInputController]).enabled()
	return intent_query.iterate([C_NpcIntent, C_Controller])


## Обновляет маршрут, локальное avoidance и взгляд без прямых записей физического состояния.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var intents: Array = components[0]
	var controllers: Array = components[1]
	# Соседи берутся из общего запроса: GECS обрабатывает торговцев и клиентов разными архетипами.
	var neighbour_query: QueryBuilder = ECS.world.query.with_all([C_NpcIntent, C_Controller])
	neighbour_query.with_none([C_PlayerInputController, C_Death]).enabled()
	var neighbours: Array[Entity] = neighbour_query.execute()
	for index: int in entities.size():
		_apply(
			entities[index],
			intents[index] as C_NpcIntent,
			controllers[index] as C_Controller,
			neighbours,
			delta,
		)

#endregion


#region Исполнение цели
func _apply(
	actor: Entity,
	intent: C_NpcIntent,
	controller: C_Controller,
	neighbours: Array[Entity],
	delta: float,
) -> void:
	var body: Node3D = actor as Node as Node3D
	if body == null:
		return

	controller.direction_motion = Vector3.ZERO
	controller.limit_motion_velocity = false
	_synchronize_speed_policy(actor)
	intent.navigation_pending = false
	intent.navigation_blocked = false
	intent.navigation_generation = intent.movement_generation
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	intent.navigation_task_id = decision.active_task_id if decision != null else 0
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	if npc != null:
		npc.sync_navigation_lifecycle(not actor.has_component(C_Death))
	if actor.has_component(C_Death):
		_update_encounter(actor, null, actor.get_component(C_NpcTraffic) as C_NpcTraffic)
		intent.movement_active = false
		controller.direction_look = Vector3.ZERO
		for relation: Relationship in actor.relationships:
			if relation.relation is R_NpcMoveTarget or relation.relation is R_NpcLookTarget:
				cmd.add_custom(_remove_captured_relationship.bind(weakref(actor), relation))
		return
	if NpcGazeQueries.frozen(actor) or NpcStalkingQueries.holds_approach(actor):
		_update_encounter(actor, null, actor.get_component(C_NpcTraffic) as C_NpcTraffic)
		controller.direction_look = Vector3.ZERO
		_apply_avoidance(actor, intent, controller, neighbours, delta)
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
					_apply_avoidance(actor, intent, controller, neighbours, delta)
					return
				if route != null and not route.points.is_empty() and not intent.move_uses_entity:
					var tolerance: float = (
						NpcPopulationQueries.current().definition.waypoint_distance
					)
					while (
						route.point_index < route.points.size() - 1
						and body.global_position.distance_to(route.points[route.point_index])
						<= tolerance
					):
						route.point_index += 1
					position = route.points[route.point_index]
				if intent.navigation_enabled and npc != null and npc.navigation_agent != null:
					direction = (
						_path_direction(
							npc.navigation_agent,
							intent,
							body.global_position,
							position,
						)
					)
				controller.direction_motion = (
					direction.normalized() * clampf(intent.speed_fraction, 0.0, 1.0)
				)

	var look_direction: Vector3 = controller.direction_motion
	_apply_avoidance(actor, intent, controller, neighbours, delta)
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


#region Derived control speed
func _synchronize_speed_policy(actor: Entity) -> void:
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	if motion == null:
		return
	motion.control_speed_multiplier = 1.0
	if actor.has_component(C_Death) or NpcGazeQueries.frozen(actor):
		return
	var target: Entity = CombatQueries.target_for(actor)
	if (not EntityAvailability.contains(target, ECS.world) or target.has_component(C_Death)):
		return
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = (
		NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null
	)
	if person != null:
		motion.control_speed_multiplier = person.profile.aggressive_speed_multiplier
#endregion


#region Локальное уклонение
func _apply_avoidance(
	actor: Entity,
	intent: C_NpcIntent,
	controller: C_Controller,
	neighbours: Array[Entity],
	delta: float,
) -> void:
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	if npc == null or npc.navigation_agent == null:
		return

	var agent: NavigationAgent3D = npc.navigation_agent
	if not intent.navigation_enabled or not agent.avoidance_enabled:
		return

	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	if motion == null:
		return

	var speed: float = MotionRules.effective_speed(
		motion,
		actor.get_component(C_CarryLoad) as C_CarryLoad,
		actor.get_component(C_Strength) as C_Strength,
		actor.get_component(C_Hunger) as C_Hunger,
	)
	agent.max_speed = maxf(speed, MINIMUM_NAVIGATION_SPEED)
	var preferred: Vector3 = controller.direction_motion
	if (
		motion.control_enabled and not NpcGazeQueries.frozen(actor)
		and not NpcStalkingQueries.holds_approach(actor)
	):
		preferred = _passing_direction(npc, intent, preferred, neighbours, delta)
	else:
		preferred = Vector3.ZERO
	var moving: bool = not preferred.is_zero_approx()
	agent.avoidance_priority = MOVING_AVOIDANCE_PRIORITY if moving else WAITING_AVOIDANCE_PRIORITY
	if moving and _gaze_constrained(npc):
		agent.avoidance_priority = MOVING_AVOIDANCE_PRIORITY * 0.5

	if moving and not intent.movement_active:
		# NavigationAgent suspends finished-path avoidance; activate only its derived local path.
		if agent.is_navigation_finished():
			agent.target_position = npc.global_position + preferred.normalized()
		agent.get_next_path_position()
	agent.velocity = preferred * speed
	controller.limit_motion_velocity = true
	controller.direction_motion = Vector3.ZERO
	# Ожидающий NPC становится неподвижным препятствием для обходящих соседей.
	if (
		moving and intent.avoidance_frame >= 0
		and Engine.get_physics_frames() - intent.avoidance_frame <= MAX_AVOIDANCE_AGE_FRAMES
	):
		controller.direction_motion = (
			intent.avoidance_velocity.limit_length(speed) / maxf(speed, MINIMUM_NAVIGATION_SPEED)
		)


func _passing_direction(
	npc: E_NpcCharacter,
	intent: C_NpcIntent,
	desired: Vector3,
	neighbours: Array[Entity],
	delta: float,
) -> Vector3:
	if intent.passing_distance <= 0.0 or intent.passing_bias <= 0.0:
		return desired

	var traffic: C_NpcTraffic = npc.get_component(C_NpcTraffic) as C_NpcTraffic
	var person: NpcRecord = _person(npc)
	var aggressive: bool = NpcTrafficRules.aggressive(person)
	var forward: Vector3 = desired.normalized()
	var right: Vector3 = forward.cross(Vector3.UP)
	var nearest: float = intent.passing_distance
	var obstacle: E_NpcCharacter = null
	var personal_space: bool = false
	for actor: Entity in neighbours:
		var other: E_NpcCharacter = actor as E_NpcCharacter
		if other == null or other == npc or other.navigation_agent == null:
			continue
		var offset: Vector3 = other.global_position - npc.global_position
		if absf(offset.y) > npc.navigation_agent.height:
			continue
		offset.y = 0.0
		var distance: float = offset.length()
		var clearance: float = npc.navigation_agent.radius + other.navigation_agent.radius
		var keep_space: bool = (
			traffic != null and traffic.rule != null and not aggressive
			and not _gaze_constrained(npc) and not _gaze_constrained(other)
			and NpcTrafficRules.aggressive(_person(other))
		)
		if keep_space:
			clearance = traffic.rule.personal_space + traffic.rule.anticipation_margin
		var ahead: bool = offset.dot(forward) > 0.0 and absf(offset.dot(right)) < clearance
		var too_close: bool = keep_space and distance < clearance
		if distance < nearest and (ahead or too_close):
			nearest = distance
			obstacle = other
			personal_space = keep_space

	_update_encounter(npc, obstacle, traffic)
	if obstacle == null:
		return desired

	var offset: Vector3 = npc.global_position - obstacle.global_position
	offset.y = 0.0
	var retreat_distance: float = (
		traffic.rule.personal_space + traffic.rule.anticipation_margin if personal_space else 0.0
	)
	if personal_space and nearest < retreat_distance:
		# A local backstep also works while idle; the original trip/arrival generation is untouched.
		if offset.is_zero_approx():
			offset = Vector3.RIGHT
		var away: Vector3 = offset.normalized()
		if desired.is_zero_approx():
			return away * 0.5 if _side_clear(npc, obstacle, away * 0.5) else Vector3.ZERO
		var tangent: Vector3 = forward - away * forward.dot(away)
		if tangent.is_zero_approx():
			tangent = right
		return (away * intent.passing_bias + tangent.normalized()).normalized() * desired.length()

	var ordinary_meets_moving_angel: bool = (
		not _gaze_constrained(npc) and _gaze_constrained(obstacle)
		and not NpcGazeQueries.frozen(obstacle)
	)
	if ordinary_meets_moving_angel:
		return desired
	var opponent: E_DistrictNpc = obstacle as E_DistrictNpc
	var body: E_DistrictNpc = npc as E_DistrictNpc
	if (
		body != null and opponent != null and traffic != null
		and traffic.rule != null and aggressive and NpcTrafficRules.aggressive(_person(opponent))
		and not _gaze_constrained(npc) and not _gaze_constrained(opponent)
		and not _urgent(npc) and not _urgent(opponent)
	):
		_tick_threat(body, opponent, traffic, intent, delta)
		return Vector3.ZERO
	if desired.is_zero_approx():
		return desired

	var side_sign: float = traffic.passing_side if traffic != null else 1.0
	var clearance: float = npc.navigation_agent.radius + obstacle.navigation_agent.radius
	if personal_space:
		clearance = traffic.rule.personal_space
	elif (obstacle.get_component(C_NpcIntent) as C_NpcIntent).movement_active:
		clearance *= 0.5
	var side: Vector3 = right * side_sign
	if not _side_clear(npc, obstacle, side * clearance):
		side = -side
		if not _side_clear(npc, obstacle, side * clearance):
			return desired
		if traffic != null:
			traffic.passing_side = -side_sign
	return (forward + side * intent.passing_bias).normalized() * desired.length()


func _side_clear(npc: E_NpcCharacter, obstacle: E_NpcCharacter, offset: Vector3) -> bool:
	var map: RID = npc.navigation_agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var candidate: Vector3 = npc.global_position + offset
	if (
		NavigationServer3D.map_get_closest_point(map, candidate).distance_to(candidate)
		> MAX_PASSING_NAV_DISTANCE
	):
		return false
	var collision: CollisionShape3D = npc.get_node("Collision") as CollisionShape3D
	var cast: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	cast.shape = collision.shape
	cast.transform = collision.global_transform
	cast.motion = offset
	cast.collision_mask = npc.collision_mask
	cast.exclude = [npc.get_rid(), obstacle.get_rid()]
	var fractions: PackedFloat32Array = npc.get_world_3d().direct_space_state.cast_motion(cast)
	return fractions.size() == 2 and fractions[0] >= 0.99


func _person(actor: Entity) -> NpcRecord:
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	return NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null


func _gaze_constrained(actor: Entity) -> bool:
	var gaze: C_NpcGazeFreeze = actor.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
	return gaze != null and gaze.rule != null


func _urgent(actor: Entity) -> bool:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	return CombatQueries.target_for(actor) != null or (awareness != null and awareness.fleeing)


func _encounter(actor: Entity) -> Relationship:
	for relation: Relationship in actor.relationships:
		if relation.relation is R_NpcBlocking:
			return relation
	return null


func _update_encounter(actor: Entity, obstacle: Entity, traffic: C_NpcTraffic) -> void:
	if traffic == null:
		return
	var captured: Relationship = _encounter(actor)
	if captured != null and captured.target == obstacle:
		return
	traffic.reset_transient_state()
	if captured != null:
		cmd.add_custom(_remove_captured_relationship.bind(weakref(actor), captured))
	if obstacle != null:
		cmd.add_custom(
			_bind_encounter.bind(
				weakref(actor),
				weakref(obstacle),
				traffic,
				(actor.get_component(C_NpcIntent) as C_NpcIntent).movement_generation,
			)
		)


func _bind_encounter(
	owner_reference: WeakRef,
	other_reference: WeakRef,
	state: C_NpcTraffic,
	generation: int,
) -> void:
	var actor: Entity = owner_reference.get_ref() as Entity
	var other: Entity = other_reference.get_ref() as Entity
	if (
		not EntityAvailability.contains(actor, _world)
		or not EntityAvailability.contains(other, _world) or actor.has_component(C_Death)
		or other.has_component(C_Death) or actor.get_component(C_NpcTraffic) != state
		or (actor.get_component(C_NpcIntent) as C_NpcIntent).movement_generation != generation
		or _encounter(actor) != null
	):
		return
	actor.add_relationship(Relationship.new(R_NpcBlocking.new(), other))


func _tick_threat(
	body: E_DistrictNpc,
	other: E_DistrictNpc,
	state: C_NpcTraffic,
	intent: C_NpcIntent,
	delta: float,
) -> void:
	var captured: Relationship = _encounter(body)
	if captured == null or captured.target != other:
		return
	var other_intent: C_NpcIntent = other.get_component(C_NpcIntent) as C_NpcIntent
	var owns_pair_clock: bool = String(_person(body).npc_id) <= String(_person(other).npc_id)
	if other_intent.movement_active and not owns_pair_clock:
		return
	state.threat_elapsed += delta
	if state.threat_elapsed < state.rule.threat_interval:
		return
	state.threat_elapsed = 0.0
	cmd.add_custom(
		_commit_threat.bind(
			weakref(body),
			weakref(other),
			state,
			captured,
			intent.movement_generation,
		)
	)


func _commit_threat(
	owner_reference: WeakRef,
	other_reference: WeakRef,
	state: C_NpcTraffic,
	captured: Relationship,
	generation: int,
) -> void:
	var body: E_DistrictNpc = owner_reference.get_ref() as E_DistrictNpc
	var other: E_DistrictNpc = other_reference.get_ref() as E_DistrictNpc
	if (
		not EntityAvailability.contains(body, _world)
		or not EntityAvailability.contains(other, _world) or body.has_component(C_Death)
		or other.has_component(C_Death) or body.get_component(C_NpcTraffic) != state
		or not body.relationships.has(captured) or captured.target != other
		or (body.get_component(C_NpcIntent) as C_NpcIntent).movement_generation != generation
		or _gaze_constrained(body) or _gaze_constrained(other) or _urgent(body) or _urgent(other)
	):
		return
	NpcSocialService.threaten_passage(body, other)

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
	if (
		not agent.target_position.is_equal_approx(goal)
		or agent.get_current_navigation_path().is_empty()
	):
		agent.target_position = goal
	# Допуск конечной цели не должен останавливать агента до промежуточной точки маршрута.
	var navigation_arrival_distance: float = (
		minf(intent.arrival_distance, agent.path_desired_distance)
	)
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

			cmd.add_custom(_remove_captured_relationship.bind(weakref(actor), relation))
	return null

#endregion


#region Captured relationship retirement
func _remove_captured_relationship(owner_reference: WeakRef, captured: Relationship) -> void:
	# GECS pattern removal could otherwise match a replacement after the original binding
	# disappeared.
	var subject: Entity = owner_reference.get_ref() as Entity
	if (
		subject == null or not _world.entity_to_archetype.has(subject)
		or subject.is_queued_for_deletion()
	):
		return
	if subject.relationships.has(captured):
		subject.remove_relationship(captured)
#endregion
