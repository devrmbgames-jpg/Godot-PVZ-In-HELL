extends Observer
## Advances district service clocks exactly once per committed perception step before BT.
class_name O_CustomerServiceClock

#region Due-step reaction
## Selects only retained NPC bodies currently participating in a customer role.
func query() -> QueryBuilder:
	return q.with_all([C_NpcIdentity, C_CustomerAgent]).on_event(NpcDecisionReady.EVENT)


## Synchronously commits scalar clock state; no structural buffer operation is required.
func each(_event: Variant, body: Entity, payload: Variant = null) -> void:
	var step: NpcDecisionReady = payload as NpcDecisionReady
	assert(step != null and is_finite(step.delta_seconds) and step.delta_seconds >= 0.0)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.elapsed += step.delta_seconds

	var station: E_DeliveryCounter = CustomerFlowService.counter()
	if station == null or agent.phase not in [C_CustomerAgent.Phase.QUEUED, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS, C_CustomerAgent.Phase.APPROACHING]:
		return
	var offset: Vector3 = (body as Node as Node3D).global_position - station.entry_position()
	offset.y = 0.0
	if offset.length_squared() <= NpcServiceRole.QUEUE_SPACING * NpcServiceRole.QUEUE_SPACING:
		agent.entrance_wait_elapsed += step.delta_seconds
#endregion
