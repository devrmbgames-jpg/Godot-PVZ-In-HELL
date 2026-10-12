extends RefCounted
## Explicit recognition commit; durable personal memory is the only detection authority.
class_name NpcStalkingService


#region Recognition transition
## Records one fixed neutral detection without cancelling another owner's combat or conversation.
static func notice(body: E_DistrictNpc, player: Entity) -> void:
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	if (
		state.rule == null or not state.observed
		or state.exposure_seconds < state.rule.notice_seconds
	):
		return
	if (
		not state.rule.valid_configuration()
		or not NpcStalkingSolver.observed(body, player, body.global_position, state.rule)
	):
		return
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	var actor_id: StringName = NpcSocialService.identity_for(player)
	if person.death_day != 0 or actor_id.is_empty() or NpcStalkingRules.noticed(person, actor_id):
		return
	NpcSocialService.remember(
		person,
		player,
		body,
		NpcMemory.Kind.STALKING_NOTICED,
		NpcStalkingRules.incident(person, actor_id),
		NpcMemory.Reaction.TALK,
	)
	NpcDecisionService.request_wake(body, &"stalking_noticed", true)
#endregion
