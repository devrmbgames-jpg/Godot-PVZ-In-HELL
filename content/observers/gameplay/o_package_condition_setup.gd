extends Observer
## Initializes package Health/profile once, equally for authored and received packages.
class_name O_PackageConditionSetup


func query() -> QueryBuilder:
	return q.with_all([C_Package, C_Health, C_ImpactReceiver]).on_match()


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var identity: C_Package = entity.get_component(C_Package) as C_Package
	if identity.condition_initialized or identity.definition == null:
		return
	identity.condition_initialized = true
	var definition: DEF_Package = identity.definition
	var health: C_Health = entity.get_component(C_Health) as C_Health
	var receiver: C_ImpactReceiver = entity.get_component(C_ImpactReceiver) as C_ImpactReceiver
	health.base = definition.maximum_health
	health.value = definition.maximum_health
	health.current = definition.maximum_health
	receiver.profile = definition.impact_profile
