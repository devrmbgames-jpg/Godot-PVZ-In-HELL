extends RefCounted
## Выполняет фиксацию и восстановление снимка; при снятии однократно определяет зависимые закреплённые опоры.
class_name AnchoringService

const DIRECTION_EPSILON: float = 0.0001
const SUPPORT_QUERY_LIMIT: int = 32


#region Покой и фиксация
## Читает признак фиксации игроком, если он присутствует на цели.
static func state(target: Entity) -> C_PlayerAnchored:
	return (
		target.get_component(C_PlayerAnchored) as C_PlayerAnchored
		if is_instance_valid(target)
		else null
	)


## Накапливает покой на delta секунд; движение, управление предметом и фиксация сбрасывают время.
static func update_stability(target: Entity, config: C_Anchorable, delta: float) -> void:
	if config == null:
		return
	if (
		delta <= 0.0 or not GrabService.entity_available(target)
		or state(target) != null or _controlled(target)
	):
		config.stable_seconds = 0.0
		return

	var body: RigidBody3D = GrabService.physical_body(target)
	if body == null or body.freeze:
		config.stable_seconds = 0.0
		return
	if not _within_motion_limits(body, config):
		config.stable_seconds = 0.0
		return

	config.stable_seconds += delta


## Проверяет инструмент основной руки, доступную неподконтрольную цель, дистанцию и достаточный покой.
static func can_anchor(actor: Entity, tool: Entity, target: Entity) -> bool:
	if (
		not GrabService.holder_available(actor) or not GrabService.entity_available(tool)
		or not GrabService.entity_available(target) or target == actor or target == tool
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS
	):
		return false
	if not tool.has_component(C_AnchorTool):
		return false

	var primary_hand: int = GrabService.mapped_hand(actor, false)
	if GrabService.held_in_slot(actor, primary_hand) != tool:
		return false

	var config: C_Anchorable = target.get_component(C_Anchorable) as C_Anchorable
	var body: RigidBody3D = GrabService.physical_body(target)
	if config == null or body == null or body.freeze or state(target) != null:
		return false
	if _controlled(target) or not GrabService.within_pickup_reach(actor, target):
		return false
	if not _valid_config(config) or not _within_motion_limits(body, config):
		return false
	return config.stable_seconds + DIRECTION_EPSILON >= config.minimum_rest_seconds


## После повторной проверки сохраняет физический снимок, создаёт признак и приостанавливает тело.
static func anchor(actor: Entity, tool: Entity, target: Entity) -> bool:
	if not can_anchor(actor, tool, target):
		return false

	var config: C_Anchorable = target.get_component(C_Anchorable) as C_Anchorable
	var body: RigidBody3D = GrabService.physical_body(target)
	var snapshot: AnchoredBodySnapshot = AnchoredBodySnapshot.new()
	snapshot.freeze = body.freeze
	snapshot.freeze_mode = body.freeze_mode
	snapshot.can_sleep = body.can_sleep
	snapshot.sleeping = body.sleeping
	snapshot.linear_velocity = body.linear_velocity
	snapshot.angular_velocity = body.angular_velocity

	var anchored: C_PlayerAnchored = C_PlayerAnchored.new()
	anchored.snapshot = snapshot
	target.add_component(anchored)
	config.stable_seconds = 0.0
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.sleeping = true
	return state(target) == anchored and body.freeze


#endregion

#region Снятие фиксации
## Проверяет инструмент в любой руке, собственный длительный сеанс и снимок закреплённой цели.
static func can_unfix(actor: Entity, target: Entity) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.entity_available(target):
		return false

	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus != InteractionControlFocus.Priority.HANDS:
		var active: Relationship = ProlongedInteractionService.session(actor)
		if (
			focus != InteractionControlFocus.Priority.PROLONGED
			or active == null or active.target != target
		):
			return false
	if _anchor_tool_in_hand(actor) == null:
		return false

	var anchored: C_PlayerAnchored = state(target)
	var config: C_Anchorable = target.get_component(C_Anchorable) as C_Anchorable
	var body: RigidBody3D = GrabService.physical_body(target)
	return (
		anchored != null and anchored.snapshot != null and config != null and body != null
		and body.freeze and GrabService.within_pickup_reach(actor, target)
	)


## Определяет цель и зависимые закреплённые объекты, затем последовательно восстанавливает их снимки.
static func unfix(actor: Entity, target: Entity) -> bool:
	if not can_unfix(actor, target):
		return false

	var cluster: Array[Entity] = _support_cluster(target)
	if cluster.is_empty():
		return false

	for member: Entity in cluster:
		if not _restore(member):
			return false
	return true


## Проверяет признак фиксации игроком; обычный freeze сам по себе не считается фиксацией.
static func is_player_anchored(target: Entity) -> bool:
	return state(target) != null


#endregion

#region Восстановление снимка и физические опоры
static func _restore(target: Entity) -> bool:
	var anchored: C_PlayerAnchored = state(target)
	var body: RigidBody3D = GrabService.physical_body(target)
	if anchored == null or anchored.snapshot == null or body == null:
		return false

	var snapshot: AnchoredBodySnapshot = anchored.snapshot
	var config: C_Anchorable = target.get_component(C_Anchorable) as C_Anchorable
	target.remove_component(anchored)
	if config != null:
		config.stable_seconds = 0.0
	body.can_sleep = snapshot.can_sleep
	body.freeze_mode = snapshot.freeze_mode
	body.freeze = snapshot.freeze
	body.linear_velocity = snapshot.linear_velocity
	body.angular_velocity = snapshot.angular_velocity
	body.sleeping = snapshot.sleeping
	return true


static func _support_cluster(root: Entity) -> Array[Entity]:
	var result: Array[Entity] = [root]
	if not is_instance_valid(ECS.world):
		return result

	var queue: Array[Entity] = [root]
	while not queue.is_empty():
		var supporter: Entity = queue.pop_front() as Entity
		for candidate: Entity in ECS.world.query.with_all([C_PlayerAnchored, C_Anchorable]).execute():
			if candidate == supporter or result.has(candidate):
				continue
			if _supported_by(candidate, supporter):
				result.append(candidate)
				queue.append(candidate)
	return result


static func _supported_by(candidate: Entity, supporter: Entity) -> bool:
	var candidate_body: RigidBody3D = GrabService.physical_body(candidate)
	var supporter_body: RigidBody3D = GrabService.physical_body(supporter)
	var config: C_Anchorable = candidate.get_component(C_Anchorable) as C_Anchorable
	if candidate_body == null or supporter_body == null or config == null:
		return false
	if config.support_tolerance <= 0.0 or not config.support_direction_local.is_finite():
		return false

	var direction: Vector3 = candidate_body.global_basis * config.support_direction_local
	if direction.length_squared() <= DIRECTION_EPSILON * DIRECTION_EPSILON:
		return false

	direction = direction.normalized()
	var excluded: Array[RID] = [candidate_body.get_rid()]
	var collision_nodes: Array[Node] = candidate_body.find_children("*", "CollisionShape3D", true, false)
	for node: Node in collision_nodes:
		var collision: CollisionShape3D = node as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue

		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		var shifted: Transform3D = collision.global_transform
		shifted.origin += direction * config.support_tolerance
		query.transform = shifted
		query.collision_mask = candidate_body.collision_mask
		query.exclude = excluded
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hits: Array[Dictionary] = candidate_body.get_world_3d().direct_space_state.intersect_shape(
			query,
			SUPPORT_QUERY_LIMIT,
		)
		for hit: Dictionary in hits:
			var collider: Object = hit.get("collider") as Object
			if InteractionTargetingGeometry.collider_rigid_body(collider) == supporter_body:
				return true
	return false


#endregion

#region Участники и авторские пределы
static func _controlled(target: Entity) -> bool:
	for binding: Relationship in target.relationships:
		if (
			binding.relation is R_HeldBy or binding.relation is R_StoredIn
			or binding.relation is R_PushedBy or binding.relation is R_CartDrivenBy
			or binding.relation is R_CartCargo
		):
			return true
	if not is_instance_valid(ECS.world):
		return false

	for actor: Entity in ECS.world.entities:
		var prolonged: Relationship = ProlongedInteractionService.session(actor)
		if prolonged != null and prolonged.target == target:
			return true
	return false


static func _anchor_tool_in_hand(actor: Entity) -> Entity:
	for hand: int in [C_Grabbable.HoldSlot.LEFT_HAND, C_Grabbable.HoldSlot.RIGHT_HAND]:
		var item: Entity = GrabService.held_in_slot(actor, hand)
		if GrabService.entity_available(item) and item.has_component(C_AnchorTool):
			return item
	return null


static func _valid_config(config: C_Anchorable) -> bool:
	return (
		is_finite(config.minimum_rest_seconds) and config.minimum_rest_seconds >= 0.0
		and is_finite(config.maximum_linear_speed) and config.maximum_linear_speed >= 0.0
		and is_finite(config.maximum_angular_speed) and config.maximum_angular_speed >= 0.0
		and is_finite(config.support_tolerance) and config.support_tolerance > 0.0
		and config.support_direction_local.is_finite()
		and config.support_direction_local.length_squared() > DIRECTION_EPSILON * DIRECTION_EPSILON
	)


static func _within_motion_limits(body: RigidBody3D, config: C_Anchorable) -> bool:
	return (
		body.linear_velocity.length() <= config.maximum_linear_speed
		and body.angular_velocity.length() <= config.maximum_angular_speed
	)

#endregion
