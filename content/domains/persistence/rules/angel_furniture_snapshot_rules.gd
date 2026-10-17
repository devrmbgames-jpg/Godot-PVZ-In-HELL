extends RefCounted
## Проверяет отдельные мебельные обещания и их деньги до изменения живого World.
class_name AngelFurnitureSnapshotRules


#region Закрытые оплаченные факты
static func valid(
	components: Dictionary[String, Dictionary],
	records: Dictionary[String, Dictionary],
) -> bool:
	var wallet: C_Wallet
	var cycle: C_DayCycle
	var live: Dictionary[String, String] = { }
	for key: String in records:
		live[String(records[key].entity_id)] = key
	for types: Dictionary in components.values():
		if types.has(C_Wallet):
			wallet = types[C_Wallet] as C_Wallet
		if types.has(C_DayCycle):
			cycle = types[C_DayCycle] as C_DayCycle
	var operations: Dictionary[StringName, bool] = { }
	var outputs: Dictionary[String, AngelFurnitureOrder] = { }
	var points: Array[StringName] = []
	for key: String in components:
		var types: Dictionary = components[key]
		if not types.has(C_AngelOrders):
			continue
		var state: C_AngelOrders = types[C_AngelOrders] as C_AngelOrders
		if (
			state.profile == null or state.profile.resource_path.is_empty()
			or state.next_request < 1 or state.profile.receiving_id.is_empty()
			or state.profile.receiving_id in points
			or types.has(C_Commerce) or wallet == null or cycle == null
		):
			return false
		points.append(state.profile.receiving_id)
		var terminal_id: String = String(records[key].entity_id)
		for record: AngelFurnitureOrder in state.orders:
			if not _promise_valid(record, terminal_id, state, cycle.day_index):
				return false
			if operations.has(record.operation_id):
				return false
			operations[record.operation_id] = true
			outputs[record.output_id] = record
			var matches: int = 0
			for operation: MoneyOperation in wallet.operations:
				if operation.operation_id != record.operation_id:
					continue
				if (
					operation.reason != MoneyOperation.Reason.PURCHASE
					or operation.amount != record.total_price
					or operation.day_index != record.ordered_day
					or not operation.settlement_id.is_empty()
				):
					return false
				matches += 1
			if matches != 1:
				return false
			if live.has(record.output_id):
				var body_key: String = live[record.output_id]
				var identity: C_PersistentIdentity = components[body_key].get(C_PersistentIdentity)
				if (
					not record.issued or identity == null or identity.key != record.output_id
					or String(records[body_key].scene) != record.item.world_pickup_scene
				):
					return false
	for key: String in components:
		var identity: C_PersistentIdentity = components[key].get(C_PersistentIdentity)
		if identity == null or not identity.key.begins_with("angel-order/"):
			continue
		var record: AngelFurnitureOrder = outputs.get(identity.key)
		if record == null or not record.issued or String(records[key].entity_id) != identity.key:
			return false
	if wallet != null:
		for operation: MoneyOperation in wallet.operations:
			if (
				String(operation.operation_id).begins_with("angel/")
				and not operations.has(operation.operation_id)
			):
				return false
	return true


static func _promise_valid(
	record: AngelFurnitureOrder,
	terminal_id: String,
	state: C_AngelOrders,
	day: int,
) -> bool:
	if record == null:
		return false
	var prefix: String = "angel/%s/" % terminal_id
	var suffix: String = String(record.operation_id).trim_prefix(prefix)
	return (
		String(record.operation_id).begins_with(prefix) and suffix.is_valid_int()
		and suffix.to_int() > 0 and suffix == str(suffix.to_int())
		and suffix.to_int() < state.next_request and record.terminal_id == terminal_id
		and record.receiving_id == state.profile.receiving_id
		and not record.receiving_hint.is_empty() and record.item != null
		and not record.item.resource_path.is_empty()
		and record.item.kind == DEF_InventoryItem.Kind.FURNITURE
		and record.quantity == 1 and record.total_price >= 0
		and record.total_price <= WalletService.MAX_AMOUNT and record.ordered_day >= 1
		and record.ordered_day <= day and record.ready_day == record.ordered_day + 1
		and record.output_id == "angel-order/%s" % record.operation_id
		and record.paid and record.issued_position.is_finite()
		and (not record.received or record.issued)
		and (not record.issued or day >= record.ready_day) and (
			record.issued or record.issued_position == Vector3.ZERO
		)
	)
#endregion
