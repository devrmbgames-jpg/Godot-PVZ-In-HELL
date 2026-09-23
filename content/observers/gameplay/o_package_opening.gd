extends Observer
## Commits opening exactly once and publishes a typed consequence hook without applying damage.
class_name O_PackageOpening


func query() -> QueryBuilder:
	return q.with_all([C_Package, C_PackageState]).on_event(PackageOpenRequest.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var request: PackageOpenRequest = payload as PackageOpenRequest
	if request != null and request.package == entity:
		cmd.add_custom(_commit.bind(request.actor, entity))


func _commit(actor: Entity, package: Entity) -> void:
	if not PackageOpening.can_open(actor, package):
		return
	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	condition.opening = C_PackageState.Opening.OPENED
	PackageLifecycle.publish(package, PackageLifecycleEvent.Kind.Opened, actor)
