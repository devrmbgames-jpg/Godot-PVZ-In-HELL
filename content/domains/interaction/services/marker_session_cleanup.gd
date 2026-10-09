extends RefCounted
## Очищает transient marker session и непрерывность штриха, сохраняя чернила коробки.
class_name MarkerSessionCleanup

#region Session cleanup
## Сбрасывает штрих и токен; actor_hint сохраняет держателя после удаления хвата.
static func end(tool_or_marker: Variant, actor_hint: Entity = null) -> void:
	var tool: Entity = tool_or_marker as Entity
	var marker: C_Marker = tool_or_marker as C_Marker
	if marker == null and is_instance_valid(tool):
		marker = tool.get_component(C_Marker) as C_Marker
	if marker == null:
		return

	var actor: Entity = actor_hint
	if not is_instance_valid(actor) and is_instance_valid(tool):
		var grip: Relationship = GrabQueries.held_relationship(tool)
		actor = grip.target as Entity if grip != null else null
	if is_instance_valid(actor):
		InteractionControlFocus.release(actor, marker.capture_token)
	marker.capture_token = 0
	break_stroke(marker)


## Сбрасывает временную непрерывность маркера, сохраняя уже нанесённые чернила.
static func break_stroke(marker: C_Marker) -> void:
	if marker == null:
		return

	marker.parcel = null
	marker.stroke = null
#endregion
