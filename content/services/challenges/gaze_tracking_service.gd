extends RefCounted
## Measures the rendered camera/head pose and a first-hit physics LOS, never input intent.
class_name GazeTrackingService

const DIRECTION_EPSILON: float = 0.0001
const ANGLE_BOUNDARY_EPSILON: float = 0.0001


static func sample(actor: Entity, subject: Entity, rule: DEF_GazeChallengeCondition, observation: C_GazeChallenge) -> void:
	clear(observation)
	if rule == null or not EntityAvailability.contains(actor, ECS.world) or not EntityAvailability.contains(subject, ECS.world):
		return
	var character: E_PhysicalCharacter = actor as E_PhysicalCharacter
	var target: E_PhysicalCharacter = subject as E_PhysicalCharacter
	if character == null or target == null or character.head_axis_x == null or target.head_axis_x == null:
		return
	var eyes: Node3D = character.head_axis_x
	var actor_node: Node = actor as Node
	var camera: Camera3D = actor_node.get_viewport().get_camera_3d()
	if camera != null and actor_node.is_ancestor_of(camera):
		eyes = camera
	if not eyes.is_inside_tree() or not target.head_axis_x.is_inside_tree():
		return
	var origin: Vector3 = eyes.global_position
	var destination: Vector3 = target.head_axis_x.global_position
	measure_geometry(origin, -eyes.global_basis.z, destination, rule, observation)
	if not observation.within_range or not observation.within_angle:
		return
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination, rule.collision_mask)
	var actor_body: CollisionObject3D = actor as Node as CollisionObject3D
	if actor_body != null:
		query.exclude = [actor_body.get_rid()]
	query.hit_from_inside = true
	var space: PhysicsDirectSpaceState3D = eyes.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	var collider: Object = hit.get("collider") as Object
	observation.line_of_sight = hit.is_empty() or InteractionTargetingService.collider_entity(collider) == subject
	observation.attention = observation.line_of_sight


static func measure_geometry(origin: Vector3, forward: Vector3, destination: Vector3, rule: DEF_GazeChallengeCondition, observation: C_GazeChallenge) -> void:
	clear(observation)
	var direction: Vector3 = destination - origin
	observation.distance = direction.length()
	if not origin.is_finite() or not destination.is_finite() or not forward.is_finite() or forward.length_squared() <= DIRECTION_EPSILON or observation.distance <= DIRECTION_EPSILON:
		return
	observation.sample_valid = true
	var cosine: float = clampf(forward.normalized().dot(direction.normalized()), -1.0, 1.0)
	observation.angle_degrees = rad_to_deg(acos(cosine))
	observation.within_range = observation.distance <= rule.maximum_distance
	observation.within_angle = observation.angle_degrees <= rule.half_angle_degrees + ANGLE_BOUNDARY_EPSILON


static func clear(observation: C_GazeChallenge) -> void:
	observation.sample_valid = false
	observation.distance = 0.0
	observation.angle_degrees = 0.0
	observation.within_range = false
	observation.within_angle = false
	observation.line_of_sight = false
	observation.attention = false
