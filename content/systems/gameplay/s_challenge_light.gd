extends System
## Light On and Off differ only in authored condition data.
class_name S_ChallengeLight


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_LightCircuit]}


func query() -> QueryBuilder:
	return q.with_all([C_Challenge]).iterate([C_Challenge])


func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var states: Array = components[0]
	for state: C_Challenge in states:
		if state.phase != C_Challenge.Phase.ACTIVE or state.definition == null:
			continue
		var condition: DEF_LightChallengeCondition = state.definition.condition as DEF_LightChallengeCondition
		if condition == null:
			continue
		var circuit: C_LightCircuit = LightCircuitService.state_for(condition.circuit_id)
		state.condition_result = ChallengeResult.Type.SUCCESS if circuit != null and circuit.enabled == condition.required_enabled else ChallengeResult.Type.NONE
