extends RefCounted
## Reads the sampled physical exposure and durable respect before a visible native offense branch.
class_name NpcPrideQueries


#region Sampled offense eligibility
## Returns only a new exposed-toy offense; respect and replay leave normal service reachable.
static func pending_toy_incident(actor: E_DistrictNpc, person: NpcRecord) -> StringName:
	var pride: C_NpcPride = actor.get_component(C_NpcPride) as C_NpcPride
	if (
		pride == null or pride.rule == null or pride.exposed_toy_id.is_empty()
		or NpcPrideRules.respects(person, &"player")
	):
		return &""
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var incident: StringName = NpcPrideRules.toy_incident(
		person,
		pride.exposed_toy_id,
		cycle.day_index,
		cycle.phase,
	)
	return &"" if NpcPrideRules.remembered(person, incident) else incident
#endregion
