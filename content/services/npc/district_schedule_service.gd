extends RefCounted
## Фиксирует цели фаз и окончательную смерть вне обхода сущностей GECS.
class_name DistrictScheduleService

#region Исполнение расписания
## Обновляет размещение без самостоятельного продвижения календаря игрока.
static func tick(district: C_District, cycle: C_DayCycle) -> void:
	if district.definition == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return

	var phase_key: StringName = StringName("%d/%d" % [cycle.day_index, cycle.phase])
	if district.conflict_phase != phase_key:
		district.conflict_phase = phase_key
		district.ambient_conflicts = 0
	for person: NpcRecord in district.people.duplicate():
		var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if body == null or person.death_day != 0:
			continue
		if body.has_component(C_Death):
			DistrictPopulationService.mark_dead(person, body, cycle.day_index)
			continue
		if body.has_component(C_CustomerAgent):
			continue

		DistrictPopulationService.plan_phase(person, cycle.day_index, cycle.phase)
		if person.placement != NpcRecord.Placement.STREET:
			continue
		# Назначенное движение выполняет только LimboAI.
#endregion
