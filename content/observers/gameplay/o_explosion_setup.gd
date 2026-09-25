extends Observer
## Validates blast tuning and sizes the independent prefab's visible flash.
class_name O_ExplosionSetup


func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_Explosion, C_HazardLifetime]).on_event(HazardSpawnResult.EVENT)


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	cmd.add_custom(_configure.bind(entity))


func _configure(entity: Entity) -> void:
	if not EntityAvailability.contains(entity, _world):
		return

	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var profile: DEF_Explosion = hazard.definition as DEF_Explosion
	var effect: E_Explosion = entity as E_Explosion
	if profile == null or effect == null:
		push_error("Explosion requires DEF_Explosion and E_Explosion prefab")
		HazardLifecycle.retire(entity, _world)
		return

	var valid_radius: bool = is_finite(profile.radius) and profile.radius > 0.0
	var valid_damage: bool = is_finite(profile.damage) and profile.damage >= 0.0
	var valid_impulse: bool = is_finite(profile.impulse) and profile.impulse >= 0.0
	var valid_upward_bias: bool = is_finite(profile.upward_bias) and profile.upward_bias >= 0.0
	var valid_falloff: bool = is_finite(profile.falloff_power) and profile.falloff_power > 0.0
	if (
		not valid_radius or not valid_damage or not valid_impulse
		or not valid_upward_bias or not valid_falloff or profile.maximum_targets < 1
	):
		push_error("Explosion tuning must be finite, with positive radius/falloff/target limit")
		HazardLifecycle.retire(entity, _world)
		return

	var lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
	lifetime.awaiting_resolution = true

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.visual.mesh = mesh
