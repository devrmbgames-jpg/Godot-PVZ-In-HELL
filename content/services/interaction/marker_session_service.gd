extends RefCounted
## Владеет сеансом и захватом ввода рисования; чернила изменяет PackageMarkService.
class_name MarkerSessionService


#region Жизненный цикл рисования
## Проверяет удерживаемый маркер, доступную коробку, управление и дистанцию рисования.
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
	if interactor == null or InteractionTargetingGeometry.find_target(actor, interactor) != target:
		return false

	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	var marker: C_Marker = tool.get_component(C_Marker) as C_Marker
	return (
		is_instance_valid(ray)
		and ray.global_position.distance_to(ray.get_collision_point()) <= marker.drawing_range
	)


## После проверки захватывает DRAWING, задаёт указатель и снимает вращение предмета.
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


## Сбрасывает штрих и освобождает токен маркера; actor_hint сохраняет держателя после удаления хвата.
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


#endregion
