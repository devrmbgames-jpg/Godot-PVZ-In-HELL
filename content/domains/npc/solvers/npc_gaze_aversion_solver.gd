extends RefCounted
## Bounded camera/solid-LOS and safe native-route calculations; no clocks or movement mutations.
class_name NpcGazeAversionSolver

## Extra side angle keeps the chosen destination inside the accepted observation region.
const SIDE_MARGIN_DEGREES: float = 10.0
## Native navigation projection may adjust a candidate by at most this distance, in metres.
const PROJECTION_TOLERANCE: float = 0.5


#region Perceived player and camera
## Resolves only the committed visible player; hidden/dead/unregistered actors are never followed.
static func visible_player(actor: E_DistrictNpc) -> Entity:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if not awareness.player_visible:
		return null
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	return (
		player
		if EntityAvailability.contains(player, ECS.world) \
				and not player.has_component(C_Death)
		else null
	)


## Returns the actual current camera only when it belongs to the perceived player's body.
static func camera_for(player: Entity) -> Camera3D:
	var body: Node3D = player as Node as Node3D
	if body == null:
		return null
	var camera: Camera3D = body.get_viewport().get_camera_3d()
	return camera if camera != null and body.is_ancestor_of(camera) else null


## Direct gaze uses the authored angle/range, actual frustum and unobstructed solid physics ray.
static func gazing(actor: E_DistrictNpc, player: Entity, rule: DEF_NpcGazeAversion) -> bool:
	if not EntityAvailability.contains(player, ECS.world) or player.has_component(C_Death):
		return false
	var camera: Camera3D = camera_for(player)
	if camera == null:
		return false
	var point: Vector3 = actor.global_position + Vector3.UP * NpcPerceptionService.EYE_HEIGHT
	return (
		camera.global_position.distance_to(point) <= rule.radius * 3.0
		and camera.is_position_in_frustum(point)
		and -camera.global_basis.z.dot((point - camera.global_position).normalized())
		>= rule.gaze_alignment
		and _line_clear(actor, player, camera, point, rule)
	)
#endregion


#region Safe observation position
## Observational predicate shared by the BT guard and destination revalidation.
static func safe_position(
	position: Vector3,
	player: Entity,
	camera: Camera3D,
	rule: DEF_NpcGazeAversion,
) -> bool:
	var outward: Vector3 = position - (player as Node as Node3D).global_position
	outward.y = 0.0
	var eye_direction: Vector3 = (
		position + Vector3.UP * NpcPerceptionService.EYE_HEIGHT - camera.global_position
	).normalized()
	return (
		absf(outward.length() - rule.watch_distance) <= rule.distance_tolerance
		and -camera.global_basis.z.dot(eye_direction) <= cos(deg_to_rad(rule.watch_angle_degrees))
	)


## Previews at most two side destinations through the existing native route/risk owner.
## Returns Vector3.INF when no safe reachable position exists; callers must not request it.
static func destination(
	actor: E_DistrictNpc,
	person: NpcRecord,
	player: Entity,
	rule: DEF_NpcGazeAversion,
) -> Vector3:
	var camera: Camera3D = camera_for(player)
	var map: RID = actor.navigation_agent.get_navigation_map()
	if camera == null or not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return Vector3.INF
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return Vector3.INF
	forward = forward.normalized()
	var origin: Vector3 = (player as Node as Node3D).global_position
	var selected: Vector3 = Vector3.INF
	var nearest: float = INF
	for side: float in [-1.0, 1.0]:
		var angle: float = deg_to_rad(rule.watch_angle_degrees + SIDE_MARGIN_DEGREES) * side
		var proposed: Vector3 = origin + forward.rotated(Vector3.UP, angle) * rule.watch_distance
		proposed.y = actor.global_position.y
		var candidate: Vector3 = NavigationServer3D.map_get_closest_point(map, proposed)
		if candidate.distance_to(proposed) > PROJECTION_TOLERANCE \
				or not safe_position(candidate, player, camera, rule):
			continue
		var point: Vector3 = candidate + Vector3.UP * NpcPerceptionService.EYE_HEIGHT
		if not _line_clear(actor, player, camera, point, rule):
			continue
		var path: PackedVector3Array = NpcRouteSolver.plan(
			actor,
			person,
			actor.global_position,
			candidate,
			map,
		)
		if path.is_empty():
			continue
		var distance: float = actor.global_position.distance_squared_to(candidate)
		if distance < nearest:
			nearest = distance
			selected = candidate
	return selected


static func _line_clear(
	actor: E_DistrictNpc,
	player: Entity,
	camera: Camera3D,
	point: Vector3,
	rule: DEF_NpcGazeAversion,
) -> bool:
	var exclusions: Array[RID] = [actor.get_rid()]
	var player_body: CollisionObject3D = player as Node as CollisionObject3D
	if player_body != null:
		exclusions.append(player_body.get_rid())
	for child: Node in (player as Node).find_children("*", "CollisionObject3D", true, false):
		exclusions.append((child as CollisionObject3D).get_rid())
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		point,
		rule.visibility_mask,
		exclusions,
	)
	ray.hit_from_inside = true
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
#endregion
