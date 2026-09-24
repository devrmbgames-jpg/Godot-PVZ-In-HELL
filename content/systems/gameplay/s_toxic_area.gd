extends System
## Independent per-volume clocks; Area3D supplies candidates, O_Damage owns health changes.
class_name S_ToxicArea


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_HazardFollow], Runs.Before: [S_HazardLifetime] }


func query() -> QueryBuilder:
	return q.enabled().with_all([C_Hazard, C_ToxicArea, C_HazardLifetime]).iterate(
		[C_Hazard, C_ToxicArea, C_HazardLifetime]
	)


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var hazards: Array = components[0]
	var toxins: Array = components[1]
	var lifetimes: Array = components[2]
	for index: int in entities.size():
		var hazard: C_Hazard = hazards[index]
		var toxin: C_ToxicArea = toxins[index]
		var lifetime: C_HazardLifetime = lifetimes[index]
		var effect: E_ToxicArea = entities[index] as E_ToxicArea
		var profile: DEF_ToxicArea = hazard.definition as DEF_ToxicArea
		if effect == null or profile == null or lifetime.remaining_seconds <= 0.0:
			continue

		toxin.tick_elapsed += minf(delta, lifetime.remaining_seconds)
		var ticks: int = floori(toxin.tick_elapsed / profile.tick_seconds)
		if ticks <= 0:
			continue

		# Aggregate catch-up into one request per receiver, avoiding unbounded tick loops.
		toxin.tick_elapsed -= float(ticks) * profile.tick_seconds
		cmd.add_custom(_apply_tick.bind(effect, hazard, profile, ticks))


func _apply_tick(effect: E_ToxicArea, hazard: C_Hazard, profile: DEF_ToxicArea, ticks: int) -> void:
	if not EntityAvailability.contains(effect, _world):
		return

	var seen: Dictionary[int, bool] = { }
	for body: Node3D in effect.area.get_overlapping_bodies():
		var target: Entity = HazardTargets.entity_for(body)
		if target == effect or not EntityAvailability.contains(target, _world):
			continue
		if not target.has_component(C_Health):
			continue
		if profile.living_only and not target.has_component(C_Living):
			continue

		var target_id: int = target.get_instance_id()
		if seen.has(target_id):
			continue

		seen[target_id] = true
		HazardDamage.submit(
			effect,
			hazard,
			target,
			profile.damage_per_tick * float(ticks),
			DamageRequest.Type.TOXIC,
		)
