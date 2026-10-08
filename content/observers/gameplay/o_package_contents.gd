extends Observer
## Извлекает реальное содержимое по типизированному событию вскрытия.
class_name O_PackageContents


## Подписывается на события состояния сущностей с C_PackageContents.
func query() -> QueryBuilder:
	return q.with_all([C_PackageContents]).on_event(PackageLifecycleEvent.EVENT)


## На событие Opened откладывает реальное извлечение и привязку содержимого к осмотру.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var event: PackageLifecycleEvent = payload as PackageLifecycleEvent
	if event != null and event.package == entity and event.kind == PackageLifecycleEvent.Kind.Opened:
		var contents: C_PackageContents = entity.get_component(C_PackageContents) as C_PackageContents
		var actor_reference: WeakRef = weakref(event.actor) if is_instance_valid(event.actor) else null
		cmd.add_custom(_release.bind(weakref(entity), contents, actor_reference, event.actor_id))


#region Captured operation
func _release(package_reference: WeakRef, contents: C_PackageContents, actor_reference: WeakRef, actor_id: String) -> void:
	var package: Entity = package_reference.get_ref() as Entity
	if not EntityAvailability.contains(package, _world) or package.get_component(C_PackageContents) != contents:
		return

	# A committed opening still releases its contents if the optional initiator has left.
	var actor: Entity = actor_reference.get_ref() as Entity if actor_reference != null else null
	PackageContentsService.release(package, actor, actor_id)
#endregion
