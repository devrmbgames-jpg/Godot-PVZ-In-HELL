extends RefCounted
## Uses the existing World channel; does not own gameplay state or live bindings.
class_name PlayerInteractionEvents


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
	var parcel: C_Package = target.get_component(C_Package) as C_Package
	if parcel != null:
		event.package_id = parcel.package_id

	var district: C_District = DistrictPopulationService.current()
	if district != null and kind in [PlayerInteractionEvent.Kind.PARCEL_PICKED, PlayerInteractionEvent.Kind.PARCEL_PLACED, PlayerInteractionEvent.Kind.DOOR_OPENED, PlayerInteractionEvent.Kind.DOOR_CLOSED]:
		NpcPerceptionService.action_noise(target, district.definition.interaction_noise_radius)
	ECS.world.emit_event(PlayerInteractionEvent.EVENT, target, event)
