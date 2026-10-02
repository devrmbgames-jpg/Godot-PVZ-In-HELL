extends Observer
## Physical contents consume the existing typed opening lifecycle hook.
class_name O_PackageContents


func query() -> QueryBuilder:
	return q.with_all([C_PackageContents]).on_event(PackageLifecycleEvent.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var event: PackageLifecycleEvent = payload as PackageLifecycleEvent
	if event != null and event.package == entity and event.kind == PackageLifecycleEvent.Kind.Opened:
		cmd.add_custom(_release.bind(entity))


func _release(package: Entity) -> void:
	var contents: Array[Entity] = PackageContentsService.release(package)
	CustomerInspectionService.bind_contents(package, contents)
