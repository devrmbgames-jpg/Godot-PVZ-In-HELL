extends System
## Owns captured marker continuation, pointer delta and ink sampling; lifecycle commands remain explicit.
class_name S_Marker

#region Scheduling and captured continuation
## Input capture/action transitions commit before marker continuation.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_InteractionInput]}


## Includes unavailable tools so stale active captures can be explicitly ended.
func query() -> QueryBuilder:
	return q.with_all([C_Marker])


## Captures session/tool/grip/input identity before the structural command boundary.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for tool: Entity in entities:
		var marker: C_Marker = tool.get_component(C_Marker) as C_Marker
		if marker.capture_token == 0:
			continue

		var grip: Relationship = GrabQueries.held_relationship(tool)
		var actor: Entity = grip.target as Entity if grip != null else null
		var controller: C_Controller = actor.get_component(C_Controller) as C_Controller if is_instance_valid(actor) else null
		var snapshot: C_Controller = InteractionInputSnapshot.capture(controller) if controller != null else null
		cmd.add_custom(_advance_marker.bind(weakref(tool), marker, marker.capture_token, grip, weakref(actor) if actor != null else null, controller, snapshot))


func _advance_marker(
	tool_reference: WeakRef, marker: C_Marker, token: int, grip: Relationship, actor_reference: WeakRef,
	captured_controller: C_Controller, controller: C_Controller,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var tool: Entity = tool_reference.get_ref() as Entity
	var actor: Entity = actor_reference.get_ref() as Entity if actor_reference != null else null

	# A queued draw step cannot continue a removed tool or a newer capture/held relationship.
	if not is_instance_valid(tool) or tool not in _world.entities or tool.get_component(C_Marker) != marker:
		return
	if marker.capture_token != token or GrabQueries.held_relationship(tool) != grip:
		return
	if captured_controller != null:
		if not is_instance_valid(actor) or actor.get_component(C_Controller) != captured_controller or captured_controller.input_tick != controller.input_tick:
			return
		if controller.input_tick > 0 and marker.last_input_tick == controller.input_tick and marker.last_processed_capture == token:
			return
		marker.last_input_tick = controller.input_tick
		marker.last_processed_capture = token

	if not GrabQueries.holder_available(actor) or not GrabQueries.entity_available(tool):
		MarkerSessionCleanup.end(tool, actor)
		return

	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if (
		controller == null or controller.cancel_pressed or controller.interact_pressed
		or focus != InteractionControlFocus.Priority.DRAWING
	):
		MarkerSessionCleanup.end(tool, actor)
		return

	var viewport: Viewport = (actor as Node).get_viewport()
	marker.pointer = (
		marker.pointer + controller.look_delta
	).clamp(Vector2.ZERO, viewport.get_visible_rect().size)
	var secondary: bool = (
		GrabQueries.held_in_slot(actor, GrabQueries.mapped_hand(actor, true)) == tool
	)
	var drawing: bool = controller.action_second if secondary else controller.action_main
	if not drawing:
		MarkerSessionCleanup.break_stroke(marker)
		return

	var hit: MarkerSurfaceSample = MarkerSurfaceSampler.sample(tool, actor, marker)
	if hit == null:
		MarkerSessionCleanup.break_stroke(marker)
		return

	PackageMarkService.append_sample(marker, hit.parcel, hit.world_point, hit.world_normal)

#endregion

#region Owner shutdown
func _exit_tree() -> void:
	if is_instance_valid(ECS.world):
		for tool: Entity in ECS.world.query.with_all([C_Marker]).execute():
			MarkerSessionCleanup.end(tool)
	super._exit_tree()
#endregion
