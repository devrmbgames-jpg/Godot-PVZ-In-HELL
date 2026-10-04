extends Observer
## Фиксирует вскрытие однократно и публикует событие для последствий, не применяя урон.
class_name O_PackageOpening


## Подписывается на запросы вскрытия коробок с постоянным ID и состоянием.
func query() -> QueryBuilder:
	return q.with_all([C_Package, C_PackageState]).on_event(PackageOpenRequest.EVENT)


## Откладывает повторную проверку доступа и фиксацию Opened через CommandBuffer.
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
