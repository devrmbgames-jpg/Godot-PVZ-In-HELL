extends RefCounted
## Сон блокируется непосредственной угрозой и поиском; прошлая неприязнь остаётся в памяти.
class_name NpcSleepService

#region Безопасность отдыха
## Объясняет блокировку сна по текущим участникам и эффективному местному урону.
static func blockers() -> PackedStringArray:
	var reasons: PackedStringArray = []
	var district: C_District = DistrictPopulationService.current()
	if district == null:
		return reasons

	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	var spatial: Node3D = player as Node as Node3D
	if player == null or spatial == null:
		return reasons

	var combat: C_Combat = player.get_component(C_Combat) as C_Combat
	if combat != null and combat.phase != C_Combat.Phase.READY:
		reasons.append("Завершите непосредственный бой")
	for person: NpcRecord in district.people:
		if person.death_day != 0 or person.placement != NpcRecord.Placement.STREET:
			continue

		var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if body == null:
			continue

		var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
		if CombatService.target_for(body) == player and awareness != null and (awareness.target_visible or (awareness.has_last_seen and awareness.search_elapsed < person.profile.search_seconds)):
			reasons.append("Преследователь ещё ищет вас: " + person.display_name)
		elif CombatService.target_for(body) != null and body.global_position.distance_to(spatial.global_position) < district.definition.sleep_danger_radius:
			reasons.append("Рядом с местом отдыха идёт бой")
	for effect: Entity in ECS.world.query.with_all([C_Hazard, C_HazardLifetime]).execute():
		var hazard: C_Hazard = effect.get_component(C_Hazard) as C_Hazard
		var life: C_HazardLifetime = effect.get_component(C_HazardLifetime) as C_HazardLifetime
		var point: Node3D = effect as Node as Node3D
		if point == null or life.remaining_seconds <= 0.0 or effect.has_component(C_NoDamage):
			continue

		var radius: float = 0.0
		var damage: float = 0.0
		if hazard.definition is DEF_ToxicArea:
			var area: DEF_ToxicArea = hazard.definition as DEF_ToxicArea
			radius = area.radius
			damage = DamageResistanceRules.effective(player, area.damage_per_tick, area.damage_type)
		elif hazard.definition is DEF_Explosion:
			var blast: DEF_Explosion = hazard.definition as DEF_Explosion
			var state: C_Explosion = effect.get_component(C_Explosion) as C_Explosion
			if state != null and state.resolved:
				continue

			radius = blast.radius
			damage = DamageResistanceRules.effective(player, blast.damage, DamageRequest.Type.EXPLOSION)
		if damage > 0.0 and point.global_position.distance_to(spatial.global_position + Vector3.UP) <= radius + district.definition.sleep_danger_radius:
			reasons.append("У места отдыха опасная зона")
	return reasons
#endregion
