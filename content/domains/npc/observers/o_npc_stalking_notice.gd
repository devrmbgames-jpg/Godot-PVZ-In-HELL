extends Observer
## Commits discrete recognition only after revalidating the queued sensing incarnation.
class_name O_NpcStalkingNotice


#region Captured notice request
func query() -> QueryBuilder:
	return q.on_event(NpcStalkingNoticeRequest.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var request: NpcStalkingNoticeRequest = payload as NpcStalkingNoticeRequest
	if request != null and request.body_reference.get_ref() == entity:
		cmd.add_custom(_commit.bind(request))


func _commit(request: NpcStalkingNoticeRequest) -> void:
	var body: E_DistrictNpc = request.body_reference.get_ref() as E_DistrictNpc
	var player: Entity = request.player_reference.get_ref() as Entity
	if (
		not EntityAvailability.contains(body, _world)
		or not EntityAvailability.contains(player, _world) or body.has_component(C_Death)
		or player.has_component(C_Death) or body.get_component(C_NpcStalking) != request.state
		or request.state.rule != request.rule or request.rule == null
		or (body.get_component(C_NpcDecision) as C_NpcDecision).lifecycle_generation
		!= request.lifecycle_generation
		or not request.state.observed
		or request.episode_sequence == 0
		or request.state.episode_sequence != request.episode_sequence
	):
		return
	NpcStalkingService.notice(body, player)
#endregion
