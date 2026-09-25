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
		end(tool)
#endregion


#region Drawing API
static func can_begin(actor: Entity, tool: Entity, target: Entity) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.entity_available(tool):
		return false
	if not tool.has_component(C_Marker) or not drawable(target):
		return false
	if InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS:
		return false

	var grip: Relationship = GrabService.held_relationship(tool)
	if grip == null or grip.target != actor:
		return false
	if (grip.relation as R_HeldBy).slot == C_Grabbable.HoldSlot.CARRY:
		return false

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor == null or InteractionTargetingService.find_target(actor, interactor) != target:
		return false

	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	var marker: C_Marker = tool.get_component(C_Marker) as C_Marker
	return ray.global_position.distance_to(ray.get_collision_point()) <= marker.drawing_range


static func begin(actor: Entity, tool: Entity, target: Entity) -> void:
	if not can_begin(actor, tool, target):
		return
	var marker: C_Marker = tool.get_component(C_Marker) as C_Marker
	marker.pointer = (actor as Node).get_viewport().get_visible_rect().size * 0.5
	marker.capture_token = InteractionControlFocus.acquire(
		actor,
		tool,
		InteractionControlFocus.Priority.DRAWING,
	)
	var cleanup: Callable = end.bind(tool, actor)
	if not tool.tree_exiting.is_connected(cleanup):
		tool.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)


static func end(tool_or_marker: Variant, actor_hint: Entity = null) -> void:
	var tool: Entity = tool_or_marker as Entity
	var marker: C_Marker = tool_or_marker as C_Marker
	if marker == null and is_instance_valid(tool):
		marker = tool.get_component(C_Marker) as C_Marker
	if marker == null:
		return
	var actor: Entity = actor_hint
	if not is_instance_valid(actor) and is_instance_valid(tool):
		var grip: Relationship = GrabService.held_relationship(tool)
		actor = grip.target as Entity if grip != null else null
	if is_instance_valid(actor):
		InteractionControlFocus.release(actor, marker.capture_token)
	marker.capture_token = 0
	break_stroke(marker)


static func update_session(tool: Entity, marker: C_Marker) -> void:
	var grip: Relationship = GrabService.held_relationship(tool)
	var actor: Entity = grip.target as Entity if grip != null else null
	if not GrabService.holder_available(actor) or not GrabService.entity_available(tool):
		end(tool, actor)
		return
	if grip == null or grip.target != actor:
		end(tool, actor)
		return

	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if controller.cancel_pressed or controller.interact_pressed or focus != InteractionControlFocus.Priority.DRAWING:
		end(tool, actor)
		return

	var viewport: Viewport = (actor as Node).get_viewport()
	marker.pointer = (marker.pointer + controller.look_delta).clamp(
		Vector2.ZERO,
		viewport.get_visible_rect().size,
	)
	var secondary: bool = GrabService.held_in_slot(actor, GrabService.mapped_hand(actor, true)) == tool
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

	var parcel: Entity = InteractionTargetingService.collider_entity(hit["collider"] as Object)
	if not drawable(parcel):
		break_stroke(marker)
		return
	append_sample(marker, parcel, hit["position"] as Vector3, hit["normal"] as Vector3)


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


static func break_stroke(marker: C_Marker) -> void:
	marker.parcel = null
	marker.stroke = null


static func clear_marks(parcel: Entity) -> void:
	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	if marks != null and marks.point_count > 0:
		marks.strokes.clear()
		marks.point_count = 0
		marks.revision += 1


static func drawable(parcel: Entity) -> bool:
	if not GrabService.entity_available(parcel) or not parcel.has_component(C_PackageMarks):
		return false
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	return (
		state != null and state.damage != C_PackageState.Damage.DESTROYED
		and state.registration != C_PackageState.Registration.DELIVERED
	)
#endregion


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
