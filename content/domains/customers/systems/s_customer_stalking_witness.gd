extends System
## Owns recurring rear-service observation/retirement; phase time remains with the role clock.
class_name S_CustomerStalkingWitness


#region Scheduled role observation
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_NpcStalkingWitness], Runs.Before: [S_NpcCadence, S_NpcIntent] }


func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent, C_NpcStalking, C_NpcIdentity, C_NpcDecision]).with_none([
		C_Death
	]).enabled()


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var agent: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.stalking_sequence > 0 or agent.rear_contact_pending:
			var state: C_NpcStalking = entity.get_component(C_NpcStalking) as C_NpcStalking
			var generation: int = (
				entity.get_component(C_NpcDecision) as C_NpcDecision
			).lifecycle_generation
			cmd.add_custom(
				_sample.bind(weakref(entity), agent, state, generation, agent.stalking_sequence)
			)


func _sample(
	reference: WeakRef,
	agent: C_CustomerAgent,
	state: C_NpcStalking,
	generation: int,
	sequence: int,
) -> void:
	var body: E_DistrictNpc = reference.get_ref() as E_DistrictNpc
	if (
		not EntityAvailability.contains(body, _world) or body.has_component(C_Death)
		or body.get_component(C_CustomerAgent) != agent
		or body.get_component(C_NpcStalking) != state or state.rule == null
		or agent.stalking_sequence != sequence
		or (body.get_component(C_NpcDecision) as C_NpcDecision).lifecycle_generation != generation
	):
		return
	if GameTimeQueries.current().paused and agent.rear_contact_pending:
		return
	if sequence == 0:
		var players: QueryBuilder = _world.query.with_all([C_PlayerInputController]).enabled()
		var current_player: Entity = players.execute_one()
		CustomerStalkingService.disclose_contact(body, current_player)
		return
	var player: Entity = CustomerStalkingQueries.target_for(body)
	if (
		not CustomerStalkingQueries.active(body, player)
		or state.sampled_player_instance_id != player.get_instance_id()
	):
		CustomerStalkingBindings.release(body)
		if (
			EntityAvailability.contains(body, _world)
			and body.get_component(C_CustomerAgent) == agent
		):
			NpcDecisionService.request_wake(body, &"rear_service_interrupted", true)
		return
	if state.observed and GameTimeQueries.current().step_ticks > 0:
		CustomerStalkingService.notice(body, player)
#endregion
