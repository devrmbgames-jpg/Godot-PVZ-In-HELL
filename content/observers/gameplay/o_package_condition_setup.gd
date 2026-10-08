extends Observer
## Однократно инициализирует Health и профиль удара для авторских и привезённых коробок.
class_name O_PackageConditionSetup


#region Reactive package defaults
## Подписывается на появление коробок с Health и получателем ударов.
func query() -> QueryBuilder:
	return q.with_all([C_Package, C_Health, C_ImpactReceiver]).on_match()


## Queues one recipe operation for the exact package/health/impact context.
func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var identity: C_Package = entity.get_component(C_Package) as C_Package
	if identity.condition_initialized or identity.definition == null:
		return

	var health: C_Health = entity.get_component(C_Health) as C_Health
	var receiver: C_ImpactReceiver = entity.get_component(C_ImpactReceiver) as C_ImpactReceiver
	cmd.add_custom(_initialize.bind(weakref(entity), identity, health, receiver))


func _initialize(reference: WeakRef, package: C_Package, health: C_Health,
		receiver: C_ImpactReceiver) -> void:
	var entity: Entity = reference.get_ref() as Entity
	if entity == null or not EntityAvailability.contains(entity, _world):
		return
	if entity.get_component(C_Package) != package or entity.get_component(C_Health) != health:
		return
	if entity.get_component(C_ImpactReceiver) != receiver or package.condition_initialized:
		return
	PackageConditionService.initialize(entity)
#endregion
