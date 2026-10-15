extends Observer
## Reconciles daily wallet results only at committed calendar/capability boundaries.
class_name O_WalletDay


#region Discrete wallet boundaries
## Late capability and isolated Worlds prepare once; passive startup explicitly reconciles at ready.
func sub_observers() -> Array[Array]:
	return [
		[q.with_all([C_Wallet, C_DayCycle]).on_match(), _on_capability, true],
		[q.with_all([C_Wallet, C_DayCycle]).on_event(DayPhaseChanged.EVENT), _on_phase],
	]


func _on_capability(_event: Variant, session: Entity, _payload: Variant = null) -> void:
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	_queue_reconciliation(session, cycle.day_index, cycle.phase)


func _on_phase(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var fact: DayPhaseChanged = payload as DayPhaseChanged
	assert(fact != null)
	_queue_reconciliation(session, fact.day_index, fact.phase)


func _queue_reconciliation(session: Entity, day_index: int, phase: C_DayCycle.Phase) -> void:
	var wallet: C_Wallet = session.get_component(C_Wallet) as C_Wallet
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	cmd.add_custom(_reconcile.bind(weakref(session), wallet, cycle, day_index, phase))
#endregion


#region Queued committed-context reconciliation
func _reconcile(
	session_reference: WeakRef,
	wallet: C_Wallet,
	cycle: C_DayCycle,
	day_index: int,
	phase: C_DayCycle.Phase,
) -> void:
	# Queued facts cannot settle a replacement session or use a different global World.
	var session: Entity = session_reference.get_ref() as Entity
	if (
		ECS.world != _world or not EntityAvailability.contains(session, _world)
		or session.get_component(C_Wallet) != wallet or session.get_component(C_DayCycle) != cycle
	):
		return
	if cycle.day_index != day_index or cycle.phase != phase:
		return
	WalletService.sync_day(wallet, cycle)
#endregion
