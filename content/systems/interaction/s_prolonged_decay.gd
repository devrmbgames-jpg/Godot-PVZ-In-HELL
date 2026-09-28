extends System
## Retained progress decays even when no actor is looking at its target.
class_name S_ProlongedDecay


func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_Grab] }


func query() -> QueryBuilder:
	return q.with_all([C_ProlongedInteraction]).iterate([C_ProlongedInteraction])


func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	for state: C_ProlongedInteraction in components[0]:
		ProlongedInteractionService.decay(state, delta)
