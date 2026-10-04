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
		cmd.add_custom(_release.bind(entity, event.actor))


func _release(package: Entity, actor: Entity) -> void:
	var contents: Array[Entity] = PackageContentsService.release(package, actor)
	CustomerInspectionService.bind_contents(package, contents)
