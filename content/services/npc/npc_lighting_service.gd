extends RefCounted
## Gameplay illumination from authored ambient values and active occluded Light3D sources.
class_name NpcLightingService

const LIGHT_NORMALIZATION: float = 2.0
const BLOCKER_MASK: int = 31

#region Illumination query
## Returns gameplay light exposure, with physical blockers and circuit state.
static func exposure_at(world_position: Vector3, ignored_bodies: Array[RID] = []) -> float:
	var district: C_District = DistrictPopulationService.current()
	if district == null or district.definition == null:
		return 1.0
	var nearest: float = INF
	var exposure: float = 0.05
	for place: DEF_DistrictPlace in district.definition.places:
		var distance: float = world_position.distance_squared_to(DistrictPopulationService.position_for(place.key))
		if distance < nearest:
			nearest = distance
			exposure = place.ambient_light
	for lamp: Light3D in district.light_sources:
		if not is_instance_valid(lamp) or not lamp.is_visible_in_tree() or lamp.light_energy <= 0.0:
			continue
		var circuit_enabled: bool = true
		for child: Node in lamp.get_children():
			var circuit_view: CircuitLightView = child as CircuitLightView
			if circuit_view != null:
				var circuit: C_LightCircuit = LightCircuitService.state_for(circuit_view.circuit_id)
				circuit_enabled = circuit == null or circuit.enabled
				break
		if not circuit_enabled:
			continue
		var radius: float = (lamp as OmniLight3D).omni_range if lamp is OmniLight3D else (lamp as SpotLight3D).spot_range if lamp is SpotLight3D else 0.0
		if radius <= 0.0:
			continue
		var distance: float = lamp.global_position.distance_to(world_position)
		if distance >= radius:
			continue
		if lamp is SpotLight3D:
			var spot: SpotLight3D = lamp as SpotLight3D
			if -spot.global_basis.z.normalized().dot((world_position - spot.global_position).normalized()) < cos(deg_to_rad(spot.spot_angle)):
				continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(lamp.global_position, world_position, BLOCKER_MASK)
		query.exclude = ignored_bodies
		if not lamp.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var attenuation: float = 1.0 - distance / radius
		exposure += lamp.light_energy / LIGHT_NORMALIZATION * attenuation * attenuation
	return clampf(exposure, 0.0, 1.0)
#endregion
