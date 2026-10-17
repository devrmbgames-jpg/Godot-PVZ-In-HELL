extends System
## Собственный календарь/retry Ангела; не обращается к очереди, корню или Component ПВЗ.
class_name S_AngelOrderDelivery

const RECEIVED_DISTANCE: float = 1.0


#region Собственный scheduled lifecycle
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


func query() -> QueryBuilder:
	return q.with_all([C_AngelOrders, C_OrderReceiving]).iterate([C_AngelOrders, C_OrderReceiving])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null:
		return
	for index: int in entities.size():
		var owner: C_AngelOrders = components[0][index] as C_AngelOrders
		var receiving: C_OrderReceiving = components[1][index] as C_OrderReceiving
		if owner.transaction_in_progress or receiving.delivery_queued:
			continue
		receiving.retry_remaining = maxf(0.0, receiving.retry_remaining - delta)
		if receiving.retry_remaining > 0.0:
			continue
		receiving.retry_remaining = receiving.retry_seconds
		receiving.delivery_queued = true
		receiving.delivery_revision += 1
		cmd.add_custom(
			_advance.bind(
				weakref(entities[index]),
				owner,
				receiving,
				cycle,
				cycle.day_index,
				receiving.delivery_revision,
			)
		)


func _advance(
	reference: WeakRef,
	owner: C_AngelOrders,
	receiving: C_OrderReceiving,
	cycle: C_DayCycle,
	day: int,
	revision: int,
) -> void:
	if receiving.delivery_revision != revision:
		return
	receiving.delivery_queued = false
	var terminal: Entity = reference.get_ref() as Entity
	if (
		ECS.world != _world or not EntityAvailability.contains(terminal, _world)
		or not _world.get_parent() is Node3D or not terminal.enabled
		or terminal.get_component(C_AngelOrders) != owner
		or terminal.get_component(C_OrderReceiving) != receiving or owner.transaction_in_progress
		or DayPhaseQueries.current() != cycle or cycle.day_index != day
	):
		return
	for record: AngelFurnitureOrder in owner.orders:
		if record.received:
			continue
		if record.issued:
			var body: Entity = _world.get_entity_by_id(record.output_id)
			if (
				not EntityAvailability.contains(body, _world)
				or not body.get_relationships(Relationship.new(R_HeldBy.new(), null)).is_empty()
				or (body as Node as Node3D).global_position.distance_to(record.issued_position)
				> RECEIVED_DISTANCE
			):
				record.received = true
			continue
		if record.ready_day > day or cycle.phase == C_DayCycle.Phase.NIGHT:
			continue
		var proposal: PreparedFurniture = OrderDeliveryService.prepare_furniture(
			terminal,
			receiving,
			record.item,
			record.output_id,
			_world.get_parent() as Node3D,
		)
		if proposal == null:
			return
		# Snapshot/reentrant callbacks see an issued fact, never an unpaid or repeatable body.
		owner.transaction_in_progress = true
		record.issued = true
		record.issued_position = proposal.world_pose.origin
		OrderDeliveryService.commit_furniture(proposal, receiving)
		owner.transaction_in_progress = false
		return
#endregion
