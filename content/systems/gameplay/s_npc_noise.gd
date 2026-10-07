extends System
## Ages bounded district noise only after all due consumers and native decisions finish.
class_name S_NpcNoise

#region Scheduling
## Retires noise after decision/route consumption and before downstream gameplay consumers.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcRoutePlanning], Runs.Before: [S_NpcCombat, S_NpcIntent]}


## Selects authoritative district noise with its calendar gate.
func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle])


## Queues ageing once per district step; no noise clock remains in a Service.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for session: Entity in entities:
		cmd.add_custom(_age.bind(session, delta))
#endregion

#region Noise lifetime
func _age(session: Entity, delta: float) -> void:
	if not EntityAvailability.contains(session, _world):
		return
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if cycle.phase == C_DayCycle.Phase.NIGHT:
		return
	var district: C_District = session.get_component(C_District) as C_District
	for noise: NpcNoise in district.noises.duplicate():
		noise.remaining -= maxf(0.0, delta)
		if noise.remaining <= 0.0:
			district.noises.erase(noise)
#endregion
