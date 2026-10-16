extends RefCounted
## Read-only demand reach and full-shape grounded return placement in the current physics space.
class_name CustomerParcelDemandGeometry

const PLACEMENT: DEF_ItemPlacement = preload(
	"res://content/shared/definitions/def_item_placement_default.tres"
)


#region Physical accessibility
static func reachable(actor: Entity, customer: E_DistrictNpc, parcel: Entity) -> bool:
	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	var anchor: Node3D = GrabQueries.hold_anchor(actor)
	if control == null or anchor == null:
		return false
	var distance: float = control.pickup_distance
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor != null:
		distance = minf(distance, interactor.interaction_distance)
	if not is_finite(distance) or distance <= 0.0:
		return false
	var body: RigidBody3D = GrabQueries.physical_body(parcel)
	var surface: Vector3 = CustomerHandoffGeometry.closest_point(body, anchor.global_position)
	if not surface.is_finite() or anchor.global_position.distance_to(surface) > distance:
		return false
	# Match native interaction targeting: the player's own hands cannot hide the demand target.
	# Placement overlap/sweeps below still treat these bodies as physical obstacles.
	var excluded: Array[RID] = _participant_rids(actor, customer, body)
	for slot: int in 3:
		var held: Entity = GrabQueries.held_in_slot(actor, slot)
		var held_body: RigidBody3D = GrabQueries.physical_body(held)
		if held_body != null:
			excluded.append(held_body.get_rid())
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		anchor.global_position,
		surface,
		PLACEMENT.obstacle_mask,
		excluded,
	)
	return body.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


## Keeps the existing parcel basis and validates support, overlap and swept shape before a drop.
static func floor_destination(
	actor: Entity,
	customer: E_DistrictNpc,
	body: RigidBody3D,
) -> ItemPlacementSolver.Result:
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	if not solver.prepare(body):
		return ItemPlacementSolver.Result.new()
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var origin: Transform3D = Transform3D(
		body.global_basis,
		GrabQueries.hold_anchor(actor).global_position,
	)
	var excluded: Array[RID] = [body.get_rid()]
	var path_excluded: Array[RID] = _participant_rids(actor, customer, body)
	var candidate: DEF_ItemPlacement = PLACEMENT.duplicate() as DEF_ItemPlacement
	for index: int in mini(PLACEMENT.offsets.size(), DEF_ItemPlacement.MAX_CANDIDATES):
		candidate.offsets = PackedVector3Array([PLACEMENT.offsets[index]])
		var result: ItemPlacementSolver.Result = solver.find(
			space,
			origin,
			candidate,
			[],
			excluded,
			false,
			body.global_position,
			path_excluded,
		)
		if result.available and _clear_sweep(body, result.pose.origin, path_excluded):
			return result
	return ItemPlacementSolver.Result.new()


static func _participant_rids(
	actor: Entity,
	customer: E_DistrictNpc,
	body: RigidBody3D,
) -> Array[RID]:
	var result: Array[RID] = [body.get_rid(), customer.get_rid()]
	var player_body: PhysicsBody3D = actor as Node as PhysicsBody3D
	if player_body != null:
		result.append(player_body.get_rid())
	return result


static func _clear_sweep(body: RigidBody3D, destination: Vector3, excluded: Array[RID]) -> bool:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		for index: int in body.shape_owner_get_shape_count(owner_id):
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = body.shape_owner_get_shape(owner_id, index)
			query.transform = body.global_transform * body.shape_owner_get_transform(owner_id)
			query.motion = destination - body.global_position
			query.collision_mask = PLACEMENT.obstacle_mask
			query.exclude = excluded
			query.margin = PLACEMENT.margin
			var travel: PackedFloat32Array = space.cast_motion(query)
			if travel.size() != 2 or travel[0] < 1.0:
				return false
	return true
#endregion
