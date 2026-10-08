extends Observer
## Фиксирует вскрытие однократно и публикует событие для последствий, не применяя урон.
class_name O_PackageOpening


#region Request handling
## Подписывается на запросы вскрытия коробок с постоянным ID и состоянием.
func query() -> QueryBuilder:
	return q.with_all([C_Package, C_PackageState]).on_event(PackageOpenRequest.EVENT)


## Откладывает повторную проверку доступа и фиксацию Opened через CommandBuffer.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var request: PackageOpenRequest = payload as PackageOpenRequest
	if request != null and request.package == entity and request.resolution != null:
		cmd.add_custom(_commit.bind(request))


func _commit(request: PackageOpenRequest) -> void:
	var actor: Entity = request.actor
	var package: Entity = request.package
	var resolution: PackageOpenResult = request.resolution
	if not PackageOpening.can_open(actor, package):
		resolution.status = PackageOpenResult.Status.REJECTED
		resolution.reason = &"access_changed"
		_publish(resolution, package)
		return

	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	condition.opening = C_PackageState.Opening.OPENED
	PackageLifecycle.publish(package, PackageLifecycleEvent.Kind.Opened, actor)
	resolution.status = PackageOpenResult.Status.COMMITTED
	resolution.reason = &"opened"
	_publish(resolution, package)


func _publish(resolution: PackageOpenResult, package: Entity) -> void:
	var trace_stage: BoundaryTraceEntry.Stage = BoundaryTraceEntry.Stage.REJECTED
	if resolution.status == PackageOpenResult.Status.COMMITTED:
		trace_stage = BoundaryTraceEntry.Stage.COMPLETED
	BoundaryTrace.record(&"package.open", resolution.correlation_id, trace_stage,
		resolution.reason, resolution.actor_id, resolution.package_id)
	_world.emit_event(PackageOpenResult.EVENT,
		package if is_instance_valid(package) else null, resolution)
#endregion
