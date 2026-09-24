extends Observer
## Only translates package lifecycle events into generic emitter activation.
class_name O_PackageHazard


func query() -> QueryBuilder:
	return q.with_all([C_Package, C_HazardEmitter]).on_event(PackageLifecycleEvent.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var event: PackageLifecycleEvent = payload as PackageLifecycleEvent
	if event == null or not is_instance_valid(entity):
		return

	var emitter: C_HazardEmitter = entity.get_component(C_HazardEmitter) as C_HazardEmitter
	var trigger: int = 0
	match event.kind:
		PackageLifecycleEvent.Kind.Destroyed:
			trigger = C_HazardEmitter.Trigger.PackageDestroyed
		PackageLifecycleEvent.Kind.Leaking:
			trigger = C_HazardEmitter.Trigger.PackageLeaking
		PackageLifecycleEvent.Kind.Opened:
			trigger = C_HazardEmitter.Trigger.PackageOpened

	if emitter.triggers & trigger:
		var actor: Entity = event.actor if is_instance_valid(event.actor) else null
		var actor_id: String = ""
		if event.cause != null and event.cause.request != null:
			actor_id = event.cause.request.instigator_id
			if is_instance_valid(event.cause.request.instigator):
				actor = event.cause.request.instigator
		HazardEmitter.activate(entity, actor, event.package_id, actor_id)
