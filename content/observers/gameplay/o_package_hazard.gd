extends Observer
## Maps first damage/opening transitions to their authored autonomous hazard scenes.
class_name O_PackageHazard

func query() -> QueryBuilder:
	return q.with_all([C_Package]).on_event(PackageLifecycleEvent.EVENT)

func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var event: PackageLifecycleEvent = payload as PackageLifecycleEvent
	if event == null or event.kind not in [PackageLifecycleEvent.Kind.Damaged, PackageLifecycleEvent.Kind.Opened]:
		return
	if not is_instance_valid(entity):
		return

	var identity: C_Package = entity.get_component(C_Package) as C_Package
	var definition: DEF_Package = identity.definition if identity != null else null
	if definition == null:
		return
	if PackageContentsService.is_empty(entity):
		return
	# При распаковке эффект переносит сервис извлечения на реальное содержимое.
	if event.kind == PackageLifecycleEvent.Kind.Opened and definition.unpack_scene != null:
		return
	var scene: PackedScene = definition.hazard_on_opened if event.kind == PackageLifecycleEvent.Kind.Opened else definition.hazard_on_damaged
	if scene == null:
		return

	var actor: Entity = event.actor if is_instance_valid(event.actor) else null
	var actor_id: String = ""
	if event.cause != null and event.cause.request != null:
		actor_id = event.cause.request.instigator_id
		if is_instance_valid(event.cause.request.instigator):
			actor = event.cause.request.instigator

	var origin_id: String = event.package_id if not event.package_id.is_empty() else entity.id
	var scene_key: String = _scene_key(scene)
	var trigger: String = "opened" if event.kind == PackageLifecycleEvent.Kind.Opened else "damaged"
	HazardEmitter.emit_scene(
		entity,
		scene,
		"%s:%s:%s" % [origin_id, trigger, scene_key],
		actor,
		origin_id,
		actor_id,
	)

func _scene_key(scene: PackedScene) -> String:
	return scene.resource_path if not scene.resource_path.is_empty() else str(scene.get_instance_id())
