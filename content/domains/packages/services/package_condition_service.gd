extends RefCounted
## Materializes package condition defaults and rebuilds recipe state while preserving saved Health.
class_name PackageConditionService

#region Explicit recipe materialization
## Requires Package/Health/ImpactReceiver established by prefab preflight or the observer query.
static func initialize(entity: Entity, preserve_saved_health: bool = false) -> void:
	var package: C_Package = entity.get_component(C_Package) as C_Package
	var definition: DEF_Package = package.definition
	var health: C_Health = entity.get_component(C_Health) as C_Health
	var receiver: C_ImpactReceiver = entity.get_component(C_ImpactReceiver) as C_ImpactReceiver
	package.condition_initialized = true
	if not preserve_saved_health:
		health.base = definition.maximum_health
		health.value = definition.maximum_health
		health.current = definition.maximum_health
	receiver.profile = definition.impact_profile

	var tilt: C_LiquidTilt = entity.get_component(C_LiquidTilt) as C_LiquidTilt
	if definition.tags & DEF_Package.Tag.LIQUID:
		if tilt == null:
			tilt = C_LiquidTilt.new()
			entity.add_component(tilt)
		tilt.maximum_angle_degrees = definition.liquid_maximum_angle_degrees
		tilt.duration_seconds = definition.liquid_tilt_seconds
		tilt.damage_amount = definition.liquid_tilt_damage
		tilt.unsafe_seconds = 0.0
		tilt.triggered = false
#endregion
