extends RefCounted
## Bounded hidden native-route previews; physical movement remains the body's responsibility.
class_name NpcStalkingSolver

## Three candidates behind the actual camera, in degrees.
const BEHIND_ANGLES: Array[float] = [180.0, -140.0, 140.0]
## Samples every route segment at most this far apart, in metres.
const PATH_SAMPLE_DISTANCE: float = 0.5
## Bounds camera rays for unusually long or circuitous paths.
const MAX_PATH_SAMPLES: int = 128


#region Hidden positions and routes
static func observed(
	actor: E_DistrictNpc,
	player: Entity,
	position: Vector3,
	rule: DEF_NpcStalking,
) -> bool:
	return NpcCameraVisibility.position_observed(
		actor,
		player,
		position,
		rule.visibility_mask,
		rule.sample_offsets,
	)


## Rejects whole routes crossing the player's actual visible region, including segment interiors.
static func hidden_path(
	actor: E_DistrictNpc,
	player: Entity,
	path: PackedVector3Array,
	rule: DEF_NpcStalking,
) -> bool:
	if path.is_empty():
		return false
	var samples: int = 0
	var previous: Vector3 = actor.global_position
	for point: Vector3 in path:
		var steps: int = maxi(1, ceili(previous.distance_to(point) / PATH_SAMPLE_DISTANCE))
		if samples + steps > MAX_PATH_SAMPLES:
			return false
		for index: int in range(1, steps + 1):
			if observed(actor, player, previous.lerp(point, float(index) / steps), rule):
				return false
		samples += steps
		previous = point
	return true


## Returns a hidden reachable destination behind the player, or INF when it is unsafe to approach.
static func destination(
	actor: E_DistrictNpc,
	person: NpcRecord,
	player: Entity,
	rule: DEF_NpcStalking,
	candidate_offset: int = 0,
) -> Vector3:
	var camera: Camera3D = NpcGazeAversionSolver.camera_for(player)
	var map: RID = actor.navigation_agent.get_navigation_map()
	if camera == null or not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return Vector3.INF
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return Vector3.INF
	forward = forward.normalized()
	var origin: Vector3 = (player as Node as Node3D).global_position
	for index: int in BEHIND_ANGLES.size():
		var angle: float = BEHIND_ANGLES[(index + candidate_offset) % BEHIND_ANGLES.size()]
		var behind: Vector3 = forward.rotated(Vector3.UP, deg_to_rad(angle))
		var proposed: Vector3 = origin + behind * rule.behind_distance
		proposed.y = actor.global_position.y
		var candidate: Vector3 = NavigationServer3D.map_get_closest_point(map, proposed)
		if candidate.distance_to(proposed) > NpcGazeAversionSolver.PROJECTION_TOLERANCE:
			continue
		var path: PackedVector3Array = NpcRouteSolver.plan(
			actor,
			person,
			actor.global_position,
			candidate,
			map,
		)
		if not hidden_path(actor, player, path, rule):
			continue
		return candidate
	return Vector3.INF
#endregion
