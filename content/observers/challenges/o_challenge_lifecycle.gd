extends Observer
class_name O_ChallengeLifecycle


func setup() -> void:
	_world.entity_removed.connect(ChallengeService.entity_unavailable)
	_world.entity_disabled.connect(ChallengeService.entity_unavailable)


func query() -> QueryBuilder:
	return q.on_relationship_removed([R_ChallengeActor])


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var state: C_Challenge = entity.get_component(C_Challenge) as C_Challenge
	if state != null and state.phase in [C_Challenge.Phase.ARMED, C_Challenge.Phase.ACTIVE]:
		ChallengeService.cancel(entity)
