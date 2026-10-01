extends RefCounted
class_name GazeChallengePresentation


static func state_for(actor: Entity) -> C_Challenge:
	if not EntityAvailability.contains(actor, ECS.world):
		return null
	for subject: Entity in ECS.world.query.with_all([C_Challenge, C_GazeChallenge]).execute():
		var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
		if state.phase == C_Challenge.Phase.ACTIVE and state.definition != null and state.definition.condition is DEF_GazeChallengeCondition and ChallengeService.actor_for(subject) == actor:
			return state
	return null


static func strength(state: C_Challenge) -> float:
	if state == null or state.condition_result == ChallengeResult.Type.SUCCESS or state.elapsed < state.definition.preparation_seconds:
		return 0.0
	var rule: DEF_GazeChallengeCondition = state.definition.condition as DEF_GazeChallengeCondition
	var progress: float = clampf(state.violation_elapsed / maxf(state.definition.violation_grace_seconds, GazeTrackingService.DIRECTION_EPSILON), 0.0, 1.0)
	return clampf((progress - rule.warning_fraction) / (1.0 - rule.warning_fraction), 0.0, 1.0)


static func text(state: C_Challenge) -> String:
	if state == null or strength(state) <= 0.0:
		return ""
	var rule: DEF_GazeChallengeCondition = state.definition.condition as DEF_GazeChallengeCondition
	var remaining: float = maxf(0.0, state.definition.violation_grace_seconds - state.violation_elapsed)
	return "%s До нарушения: %.1f с" % [rule.warning_text, remaining]
