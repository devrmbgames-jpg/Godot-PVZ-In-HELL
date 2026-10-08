extends Observer
## NPC noise consumes already committed player interaction facts; the publisher owns no NPC behavior.
class_name O_PlayerInteractionNoise

#region Committed player action noise
## Reacts only to the published interaction fact channel.
func query() -> QueryBuilder:
	return q.on_event(PlayerInteractionEvent.EVENT)


## Captures actual source position/identity and current aggregate before the callback command boundary.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var committed: PlayerInteractionEvent = payload as PlayerInteractionEvent
	if committed == null or committed.object != entity or committed.kind not in [
		PlayerInteractionEvent.Kind.PARCEL_PICKED, PlayerInteractionEvent.Kind.PARCEL_PLACED,
		PlayerInteractionEvent.Kind.DOOR_OPENED, PlayerInteractionEvent.Kind.DOOR_CLOSED,
	]:
		return

	var district: C_District = DistrictPopulationService.current()
	var spatial: Node3D = entity as Node as Node3D
	if district == null or spatial == null:
		return
	cmd.add_custom(_emit.bind(committed.actor, entity, committed.actor_id, committed.object_id,
		district, district.definition, spatial.global_position, district.definition.interaction_noise_radius))


func _emit(actor: Entity, subject: Entity, actor_id: String, object_id: String, district: C_District, definition: DEF_District, position: Vector3, radius: float) -> void:
	if not EntityAvailability.contains(actor, _world) or not EntityAvailability.contains(subject, _world):
		return
	if actor.id != actor_id or subject.id != object_id or not actor.has_component(C_PlayerInputController):
		return
	if DistrictPopulationService.current() != district or district.definition != definition:
		return
	NpcPerceptionService.emit_noise(subject, position, radius)
#endregion
