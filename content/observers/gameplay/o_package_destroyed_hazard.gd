extends Observer
## Starts the Package's destruction hazard from the actual authored debris Entity.
class_name O_PackageDestroyedHazard

func query() -> QueryBuilder:
	return q.on_event(PackageDebrisSpawnedEvent.EVENT)

func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var event: PackageDebrisSpawnedEvent = payload as PackageDebrisSpawnedEvent
	if event == null or event.definition == null:
		return
	if event.contents_released:
		return
	if event.definition.hazard_on_destroyed == null:
		return
	if not EntityAvailability.contains(event.debris, _world):
		return

	var actor: Entity = null
	var actor_id: String = ""
	if event.cause != null and event.cause.request != null:
		actor_id = event.cause.request.instigator_id
		actor = event.cause.request.instigator
		if not is_instance_valid(actor):
			actor = event.cause.request.source if is_instance_valid(event.cause.request.source) else null

	var scene: PackedScene = event.definition.hazard_on_destroyed
	var scene_key: String = (
		scene.resource_path if not scene.resource_path.is_empty() else str(scene.get_instance_id())
	)
	var source_id: String = event.package_id if not event.package_id.is_empty() else event.debris.id
	HazardEmitter.emit_scene(
		event.debris,
		scene,
		"%s:destroyed:%s" % [source_id, scene_key],
		actor,
		event.debris.id,
		actor_id,
	)
