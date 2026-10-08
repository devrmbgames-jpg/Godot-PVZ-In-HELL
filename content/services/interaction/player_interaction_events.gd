extends RefCounted
## Публикует события через канал World, не владея игровыми данными и живыми связями.
class_name PlayerInteractionEvents


#region Committed interaction facts
## Публикует подтверждённый переход с живыми ссылками и стабильными ID участников.
static func publish(actor: Entity, target: Entity, kind: PlayerInteractionEvent.Kind) -> void:
	if not EntityAvailability.contains(actor, ECS.world) or not actor.has_component(C_PlayerInputController):
		return
	if not EntityAvailability.contains(target, ECS.world):
		return

	var event: PlayerInteractionEvent = PlayerInteractionEvent.new()
	event.kind = kind
	event.actor = actor
	event.object = target
	event.actor_id = actor.id
	event.object_id = target.id
	event.operation_id = BoundaryTrace.next_id(&"interaction")
	var parcel: C_Package = target.get_component(C_Package) as C_Package
	if parcel != null:
		event.package_id = parcel.package_id

	BoundaryTrace.record(&"interaction.fact", event.operation_id,
		BoundaryTraceEntry.Stage.COMPLETED,
		StringName(String(PlayerInteractionEvent.Kind.keys()[kind]).to_lower()),
		BoundaryTrace.identity(actor), BoundaryTrace.identity(target))
	ECS.world.emit_event(PlayerInteractionEvent.EVENT, target, event)
#endregion
