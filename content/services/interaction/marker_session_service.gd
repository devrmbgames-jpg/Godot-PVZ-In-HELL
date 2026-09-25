extends RefCounted
## Marker drawing session/capture lifecycle; ink mutation is delegated to PackageMarkService.
class_name MarkerSessionService


static func can_begin(actor: Entity, tool: Entity, target: Entity) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.entity_available(tool):
		return false
	if not tool.has_component(C_Marker) or not PackageMarkService.drawable(target):
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
	return (
		is_instance_valid(ray)
		and ray.global_position.distance_to(ray.get_collision_point()) <= marker.drawing_range
	)


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
	PackageMarkService.break_stroke(marker)


static func update(tool: Entity, marker: C_Marker) -> void:
	var grip: Relationship = GrabService.held_relationship(tool)
	var actor: Entity = grip.target as Entity if grip != null else null
	if not GrabService.holder_available(actor) or not GrabService.entity_available(tool):
		end(tool, actor)
		return

	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if (
		controller == null or controller.cancel_pressed or controller.interact_pressed
		or focus != InteractionControlFocus.Priority.DRAWING
	):
		end(tool, actor)
		return

	var viewport: Viewport = (actor as Node).get_viewport()
	marker.pointer = (
		marker.pointer + controller.look_delta
	).clamp(Vector2.ZERO, viewport.get_visible_rect().size)
	var secondary: bool = (
		GrabService.held_in_slot(actor, GrabService.mapped_hand(actor, true)) == tool
	)
	var drawing: bool = controller.action_second if secondary else controller.action_main
	if not drawing:
		PackageMarkService.break_stroke(marker)
		return

	var hit: MarkerSurfaceSample = MarkerSurfaceSampler.sample(tool, actor, marker)
	if hit == null:
		PackageMarkService.break_stroke(marker)
		return
	PackageMarkService.append_sample(marker, hit.parcel, hit.world_point, hit.world_normal)
