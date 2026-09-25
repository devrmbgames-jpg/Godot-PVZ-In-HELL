extends Observer
## Maps package condition transitions to autonomous hazard scenes without classifying effects.
class_name O_PackageHazard


func query() -> QueryBuilder:
	return q.with_all([C_Package]).on_event(PackageLifecycleEvent.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var event: PackageLifecycleEvent = payload as PackageLifecycleEvent
	if event == null or not is_instance_valid(entity):
		return

	var identity: C_Package = entity.get_component(C_Package) as C_Package
	var definition: DEF_Package = identity.definition if identity != null else null
	if definition == null:
		return

	var scene: PackedScene = null
	match event.kind:
		PackageLifecycleEvent.Kind.Damaged:
			scene = definition.hazard_on_damaged
		PackageLifecycleEvent.Kind.Destroyed:
			scene = definition.hazard_on_destroyed
		_:
			return
	if scene == null:
		return

	var actor: Entity = event.actor if is_instance_valid(event.actor) else null
	var actor_id: String = ""
	if event.cause != null and event.cause.request != null:
		actor_id = event.cause.request.instigator_id
		if is_instance_valid(event.cause.request.instigator):
			actor = event.cause.request.instigator

	var origin_id: String = event.package_id if not event.package_id.is_empty() else entity.id
	var scene_key: String = scene.resource_path
	if scene_key.is_empty():
		scene_key = str(scene.get_instance_id())
	var request_id: String = "%s:hazard:%s" % [origin_id, scene_key]
	HazardEmitter.emit_scene(entity, scene, request_id, actor, origin_id, actor_id)
