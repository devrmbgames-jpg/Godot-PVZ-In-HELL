extends Observer
## Spawns package destruction hazards from the actual depletion debris Entity.
class_name O_PackageDestroyedHazard

const DEBRIS_KEY: StringName = &"debris"

func query() -> QueryBuilder:
	return q.on_event(HealthDepletionEvent.EVENT)

func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var event: HealthDepletionEvent = payload as HealthDepletionEvent
	if event == null or event.cause == null or event.cause.request == null:
		return

	var package: Entity = event.cause.request.target
	if not EntityAvailability.contains(package, _world) or not package.has_component(C_Package):
		return

	var identity: C_Package = package.get_component(C_Package) as C_Package
	var definition: DEF_Package = identity.definition if identity != null else null
	if definition == null or definition.hazard_on_destroyed == null:
		return

	var debris: Entity = event.spawned_entities.get(DEBRIS_KEY) as Entity
	if not EntityAvailability.contains(debris, _world):
		push_warning("Package destruction hazard requires depletion spawn key: debris")
		return

	var actor: Entity = event.cause.request.instigator
	if not is_instance_valid(actor):
		actor = event.cause.request.source if is_instance_valid(event.cause.request.source) else null

	var package_id: String = identity.package_id if not identity.package_id.is_empty() else package.id
	var scene: PackedScene = definition.hazard_on_destroyed
	var scene_key: String = scene.resource_path if not scene.resource_path.is_empty() else str(scene.get_instance_id())
	HazardEmitter.emit_scene(
		debris,
		scene,
		"%s:destroyed:%s" % [package_id, scene_key],
		actor,
		debris.id,
		event.cause.request.instigator_id,
	)
