extends System
## Owns marker capture, first-hit surface sampling and package-local ink mutations.
class_name S_Marker

const SURFACE_OFFSET: float = 0.004
const SAME_FACE_DOT: float = 0.995
const MAX_SAMPLE_GAP: float = 0.12


#region GECS
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_Grab] }


func query() -> QueryBuilder:
	return q.with_all([C_Marker]).iterate([C_Marker])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var markers: Array = components[0]
	for index: int in entities.size():
		var marker: C_Marker = markers[index]
		if marker.capture_token != 0:
			update_session(entities[index], marker)


func _exit_tree() -> void:
	if not is_instance_valid(ECS.world):
		return

	for tool: Entity in ECS.world.query.with_all([C_Marker]).execute():
		end(tool.get_component(C_Marker) as C_Marker)
#endregion


#region Drawing API
## Requires a live hand-held marker and an unobstructed drawable package.
static func can_begin(actor: Entity, tool: Entity, target: Entity) -> bool:
	if not S_Grab.holder_available(actor) or not S_Grab.entity_available(tool):
		return false
	if not tool.has_component(C_Marker) or not drawable(target):
		return false
	if InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS:
		return false

	var grip: Relationship = S_Grab.held_relationship(tool)
	if grip == null or grip.target != actor:
		return false
	if (grip.relation as C_HeldBy).slot == C_Grabbable.HoldSlot.CARRY:
		return false

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor == null or S_InteractionTargeting.find_target(actor, interactor) != target:
		return false

	var ray: RayCast3D = S_Grab.interaction_raycast(actor)
	var marker: C_Marker = tool.get_component(C_Marker) as C_Marker
	return ray.global_position.distance_to(ray.get_collision_point()) <= marker.drawing_range


## Acquires one token without moving the marker or the target package.
static func begin(actor: Entity, tool: Entity, target: Entity) -> void:
	if not can_begin(actor, tool, target):
		return

	var marker: C_Marker = tool.get_component(C_Marker) as C_Marker
	marker.actor = actor
	marker.pointer = (actor as Node).get_viewport().get_visible_rect().size * 0.5
	marker.capture_token = InteractionControlFocus.acquire(
		actor,
		tool,
		InteractionControlFocus.Priority.DRAWING,
	)
	if not tool.tree_exiting.is_connected(end.bind(marker)):
		tool.tree_exiting.connect(end.bind(marker), CONNECT_ONE_SHOT)


## Releases only this session's token; completed ink remains owned by packages.
static func end(marker: C_Marker) -> void:
	InteractionControlFocus.release(marker.actor, marker.capture_token)
	marker.capture_token = 0
	marker.actor = null
	break_stroke(marker)


## Validates ownership each physics tick and samples only the mapped hand-use button.
static func update_session(tool: Entity, marker: C_Marker) -> void:
	var actor: Entity = marker.actor
	if not S_Grab.holder_available(actor) or not S_Grab.entity_available(tool):
		end(marker)
		return

	var grip: Relationship = S_Grab.held_relationship(tool)
	if grip == null or grip.target != actor:
		end(marker)
		return

	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if (
		controller.cancel_pressed or controller.interact_pressed
		or focus != InteractionControlFocus.Priority.DRAWING
	):
		end(marker)
		return

	var viewport: Viewport = (actor as Node).get_viewport()
	marker.pointer = (
		marker.pointer + controller.look_delta
	).clamp(Vector2.ZERO, viewport.get_visible_rect().size)
	var secondary: bool = S_Grab.held_in_slot(actor, S_Grab.mapped_hand(actor, true)) == tool
	var drawing: bool = controller.action_second if secondary else controller.action_main
	if not drawing:
		break_stroke(marker)
		return

	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		break_stroke(marker)
		return

	var origin: Vector3 = camera.project_ray_origin(marker.pointer)
	var direction: Vector3 = camera.project_ray_normal(marker.pointer)
	var destination: Vector3 = origin + direction * marker.drawing_range
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		destination,
		interactor.collision_mask,
	)
	var excluded: Array[RID] = []
	var actor_body: CollisionObject3D = actor as Node as CollisionObject3D
	if actor_body != null:
		excluded.append(actor_body.get_rid())
	excluded.append((tool as Node as CollisionObject3D).get_rid())
	ray_query.exclude = excluded

	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(ray_query)
	if hit.is_empty():
		break_stroke(marker)
		return

	var parcel: Entity = S_InteractionTargeting.collider_entity(hit["collider"] as Object)
	if not drawable(parcel):
		break_stroke(marker)
		return

	append_sample(marker, parcel, hit["position"] as Vector3, hit["normal"] as Vector3)


## Converts a validated first-hit sample to local ink and splits discontinuous faces.
static func append_sample(
	marker: C_Marker,
	parcel: Entity,
	world_point: Vector3,
	world_normal: Vector3,
) -> void:
	if not drawable(parcel):
		break_stroke(marker)
		return

	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	if marks.point_count >= marker.max_package_points:
		break_stroke(marker)
		return

	var body: Node3D = parcel as Node as Node3D
	var local_normal: Vector3 = (body.global_basis.transposed() * world_normal).normalized()
	var point: Vector3 = body.to_local(world_point + world_normal * SURFACE_OFFSET)
	var package_entity: E_Package = parcel as E_Package
	if package_entity != null and is_instance_valid(package_entity.marking_surface):
		point = _visual_surface_point(
			package_entity.marking_surface,
			body,
			world_point,
			world_normal,
		)

	var continuing: bool = marker.parcel == parcel and marker.stroke != null
	if continuing:
		var previous: Vector3 = marker.stroke.points[-1]
		continuing = marker.stroke.normal.dot(local_normal) >= SAME_FACE_DOT
		continuing = continuing and previous.distance_to(point) <= MAX_SAMPLE_GAP
		if continuing and previous.distance_to(point) < marker.sample_spacing:
			return

	if not continuing:
		marker.stroke = PackageMarkStroke.new()
		marker.stroke.normal = local_normal
		marker.stroke.width = marker.ink_width
		marker.stroke.color = marker.ink_color
		marker.parcel = parcel
		marks.strokes.append(marker.stroke)

	marker.stroke.points.append(point)
	marks.point_count += 1
	marks.revision += 1


## Breaks continuity after release, occlusion or a missed surface.
static func break_stroke(marker: C_Marker) -> void:
	marker.parcel = null
	marker.stroke = null


## Destruction removes all ink data; node deletion also removes its child presentation.
static func clear_marks(parcel: Entity) -> void:
	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	if marks != null and marks.point_count > 0:
		marks.strokes.clear()
		marks.point_count = 0
		marks.revision += 1


## Only active, undelivered, non-destroyed packages accept ink.
static func drawable(parcel: Entity) -> bool:
	if not S_Grab.entity_available(parcel) or not parcel.has_component(C_PackageMarks):
		return false

	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	return (
		state != null and state.damage != C_PackageState.Damage.DESTROYED
		and state.registration != C_PackageState.Registration.DELIVERED
	)
#endregion


## The current package visual is a box; its mesh bounds may exceed collision tolerances.
static func _visual_surface_point(
	surface: MeshInstance3D,
	body: Node3D,
	world_point: Vector3,
	world_normal: Vector3,
) -> Vector3:
	var normal: Vector3 = (surface.global_basis.transposed() * world_normal).normalized()
	var point: Vector3 = surface.to_local(world_point)
	var bounds: AABB = surface.mesh.get_aabb()
	var axis: int = normal.abs().max_axis_index()
	var positive: bool = normal[axis] > 0.0
	point[axis] = bounds.end[axis] if positive else bounds.position[axis]
	point[axis] += SURFACE_OFFSET if positive else -SURFACE_OFFSET

	return body.to_local(surface.to_global(point))
