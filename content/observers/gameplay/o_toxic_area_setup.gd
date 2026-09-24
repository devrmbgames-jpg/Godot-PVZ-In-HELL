extends Observer
## Initializes a toxic prefab's private shape and presentation from immutable tuning.
class_name O_ToxicAreaSetup


func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_ToxicArea]).on_match()


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	cmd.add_custom(_configure.bind(entity))


func _configure(entity: Entity) -> void:
	if not EntityAvailability.contains(entity, _world):
		return

	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var profile: DEF_ToxicArea = hazard.definition as DEF_ToxicArea
	var effect: E_ToxicArea = entity as E_ToxicArea
	if profile == null or effect == null:
		push_error("ToxicArea requires DEF_ToxicArea and E_ToxicArea prefab")
		HazardLifecycle.retire(entity, _world)
		return

	var valid_radius: bool = is_finite(profile.radius) and profile.radius > 0.0
	var valid_tick: bool = is_finite(profile.tick_seconds) and profile.tick_seconds > 0.0
	var valid_damage: bool = is_finite(profile.damage_per_tick) and profile.damage_per_tick >= 0.0
	if not valid_radius or not valid_tick or not valid_damage:
		push_error(
			"ToxicArea tuning must contain finite positive radius/tick and nonnegative damage"
		)
		HazardLifecycle.retire(entity, _world)
		return

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = profile.radius
	effect.shape.shape = sphere
	effect.area.collision_mask = profile.collision_mask
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.visual.mesh = mesh
