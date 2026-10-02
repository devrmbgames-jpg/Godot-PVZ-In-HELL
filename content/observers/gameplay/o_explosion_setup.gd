extends Observer
## Validates blast tuning and sizes the independent prefab's visible flash.
class_name O_ExplosionSetup


func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_Explosion, C_HazardLifetime]).on_event(HazardSpawnResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: HazardSpawnResult = payload as HazardSpawnResult
	cmd.add_custom(_configure.bind(entity, result != null and result.restored))


func _configure(entity: Entity, restored: bool) -> void:
	if not EntityAvailability.contains(entity, _world):
		return

	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var profile: DEF_Explosion = hazard.definition as DEF_Explosion
	var effect: E_Explosion = entity as E_Explosion
	if profile == null or effect == null:
		push_error("Explosion requires DEF_Explosion and E_Explosion prefab")
		HazardLifecycle.retire(entity, _world)
		return

	if not HazardProfileRules.valid(profile):
		push_error("Explosion tuning must be finite, with positive radius/falloff/target limit")
		HazardLifecycle.retire(entity, _world)
		return

	var lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
	if not restored:
		lifetime.awaiting_resolution = true

	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.get_visual().mesh = mesh
