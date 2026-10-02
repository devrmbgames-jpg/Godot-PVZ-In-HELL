extends Observer
## Initializes a toxic prefab's private shape and presentation from immutable tuning.
class_name O_ToxicAreaSetup


func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_ToxicArea]).on_event(HazardSpawnResult.EVENT)


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

	if not HazardProfileRules.valid(profile):
		push_error(
			"ToxicArea tuning must contain finite positive radius/tick and nonnegative damage"
		)
		HazardLifecycle.retire(entity, _world)
		return

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = profile.radius
	effect.get_shape().shape = sphere
	effect.get_area().collision_mask = profile.collision_mask
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.get_visual().mesh = mesh
