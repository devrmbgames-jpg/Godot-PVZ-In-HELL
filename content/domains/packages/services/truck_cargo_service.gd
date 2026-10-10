extends RefCounted
## Однократная синхронная отправка свободного груза; журнал принадлежит зоне приёмки.
class_name TruckCargoService

const PERCENT_BASE: int = 100


#region Транзакция до окончания утра
## Фиксирует состав, удаляет груз и только затем завершает его финансовый расчёт.
static func commit(zone: E_ReceivingZoneBody, cycle: C_DayCycle) -> bool:
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	if receiving.cargo_commit_in_progress or receiving.batch_id.is_empty():
		return false
	if receiving.dispatched_batch_id == receiving.batch_id:
		return true
	var truck: E_MorningTruck = zone.get_truck()
	if truck == null or cycle.phase != C_DayCycle.Phase.MORNING or zone.supply == null:
		return false

	receiving.cargo_commit_in_progress = true
	var success: bool = _commit(zone, receiving, truck, cycle)
	receiving.cargo_commit_in_progress = false
	return success


static func _commit(
	zone: E_ReceivingZoneBody,
	receiving: C_Receiving,
	truck: E_MorningTruck,
	cycle: C_DayCycle,
) -> bool:
	var receipts: Array[TruckCargoReceipt] = []
	if receiving.cargo_batch_id == receiving.batch_id:
		for receipt: TruckCargoReceipt in receiving.cargo_receipts:
			if receipt.batch_id == receiving.batch_id:
				receipts.append(receipt)
	else:
		if zone.supply.truck_resale_percent < 0 or zone.supply.truck_resale_percent > PERCENT_BASE:
			return false
		for item: Entity in ECS.world.entities:
			if not _is_free_cargo(item, truck):
				continue
			var receipt: TruckCargoReceipt = _prepare(item, receiving, zone.supply, cycle)
			if receipt == null:
				return false
			receipts.append(receipt)
		for node: Node in ECS.world.get_parent().find_children("*", "RigidBody3D", true, false):
			var body: RigidBody3D = node as RigidBody3D
			if not _is_free_raw(body, truck):
				continue
			var identity: String = RawPhysicsActorService.identify(body)
			if (
				identity.is_empty()
				or RawPhysicsActorService.find(ECS.world.get_parent(), identity) != body
			):
				return false
			var receipt: TruckCargoReceipt = TruckCargoReceipt.new()
			receipt.batch_id = receiving.batch_id
			receipt.raw_actor_id = identity
			receipt.day_index = cycle.day_index
			receipts.append(receipt)

	# Проверка всей выплаты на копии: переполнение/конфликт не удаляют ни одного предмета.
	if not _can_settle(receipts, cycle.day_index):
		return false
	if receiving.cargo_batch_id != receiving.batch_id:
		receiving.cargo_batch_id = receiving.batch_id
		receiving.cargo_receipts.append_array(receipts)

	for receipt: TruckCargoReceipt in receipts:
		if receipt.settled:
			continue
		if not receipt.removed:
			if not receipt.raw_actor_id.is_empty():
				var body: RigidBody3D = RawPhysicsActorService.find(
					ECS.world.get_parent(),
					receipt.raw_actor_id,
				)
				if body == null or not _is_free_raw(body, truck):
					return false
				receipt.removed = true
				RawPhysicsActorService.remove(body)
				receipt.settled = true
				continue
			var item: Entity = _entity_by_id(receipt.entity_id)
			if item == null or not _is_free_cargo(item, truck):
				return false
			# Журнал виден синхронным наблюдателям удаления и возможному snapshot.
			receipt.removed = true
			if receipt.kind == TruckCargoReceipt.Kind.RETURN:
				if not PackageReturnService.return_package(item):
					receipt.removed = false
					return false
			else:
				ECS.world.remove_entity(item)
		if receipt.amount > 0:
			var result: WalletService.Status = WalletService.submit(_operation(receipt))
			if result not in [WalletService.Status.COMMITTED, WalletService.Status.DUPLICATE]:
				return false
		receipt.settled = true
	return true
#endregion


#region Свободный физический груз и зафиксированная стоимость
static func _is_free_raw(body: RigidBody3D, truck: E_MorningTruck) -> bool:
	if (
		body.get_script() != null or not GrabQueries.is_carry_candidate(body)
		or not RawPhysicsActorService.is_standalone(body)
	):
		return false
	if not truck.overlaps_cargo(body):
		return false
	var proxy: Entity = PhysicsGrabTarget.handle_for(body, false)
	if proxy == null:
		return true
	if GrabQueries.held_relationship(proxy) != null or proxy.has_component(C_PlayerAnchored):
		return false
	for link: Relationship in proxy.relationships:
		if (
			link.relation is R_OwnedBy or link.relation is R_CartCargo
			or link.relation is R_StoredIn
		):
			return false
	return true


static func _is_free_cargo(item: Entity, truck: E_MorningTruck) -> bool:
	if not EntityAvailability.contains(item, ECS.world):
		return false
	var body: RigidBody3D = item as Node as RigidBody3D
	if body == null or body.is_in_group(&"no_carry") or not truck.overlaps_cargo(body):
		return false
	if GrabQueries.held_relationship(item) != null:
		return false
	if item.has_component(C_PlayerAnchored):
		return false
	for link: Relationship in item.relationships:
		if (
			link.relation is R_OwnedBy or link.relation is R_CartCargo
			or link.relation is R_StoredIn
		):
			return false
	var character: bool = (
		item.has_component(C_NpcIdentity) or item.has_component(C_PlayerInputController)
	)
	if character and not item.has_component(C_Death):
		return false
	return (
		item.has_component(C_Grabbable) or item.has_component(C_Package)
		or item.has_component(C_InventoryItem) or item.has_component(C_Death)
	)


static func _prepare(
	item: Entity,
	receiving: C_Receiving,
	supply: DEF_Delivery,
	cycle: C_DayCycle,
) -> TruckCargoReceipt:
	var receipt: TruckCargoReceipt = TruckCargoReceipt.new()
	receipt.batch_id = receiving.batch_id
	receipt.entity_id = item.id
	receipt.day_index = cycle.day_index
	if item.has_component(C_Package):
		if PackageReturnService.can_return(item):
			receipt.kind = TruckCargoReceipt.Kind.RETURN
		return receipt
	var inventory: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if inventory == null or inventory.definition == null:
		return receipt
	if (
		inventory.quantity < 1 or inventory.quantity > inventory.definition.maximum_stack
		or inventory.transfer_in_progress or not inventory.pending_use_id.is_empty()
		or inventory.definition.market_price < 0
		or inventory.definition.market_price > WalletService.MAX_AMOUNT
	):
		return null
	receipt.kind = TruckCargoReceipt.Kind.SALE
	@warning_ignore("integer_division")
	receipt.amount = (
		inventory.definition.market_price * inventory.quantity * supply.truck_resale_percent
		/ PERCENT_BASE
	)
	if receipt.amount > WalletService.MAX_AMOUNT:
		return null
	return receipt
#endregion


#region Идемпотентный расчёт
static func _can_settle(receipts: Array[TruckCargoReceipt], day_index: int) -> bool:
	var wallet: C_Wallet = WalletService.snapshot(WalletService.current())
	for receipt: TruckCargoReceipt in receipts:
		if receipt.settled or receipt.amount == 0:
			continue
		var result: WalletService.Status = WalletService.apply(
			wallet,
			_operation(receipt),
			day_index,
		)
		if result not in [WalletService.Status.COMMITTED, WalletService.Status.DUPLICATE]:
			return false
	return true


static func _operation(receipt: TruckCargoReceipt) -> MoneyOperation:
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = StringName("truck/" + receipt.batch_id + "/" + receipt.entity_id)
	operation.reason = MoneyOperation.Reason.TRUCK_RESALE
	operation.amount = receipt.amount
	operation.day_index = receipt.day_index
	return operation


static func _entity_by_id(entity_id: String) -> Entity:
	for item: Entity in ECS.world.entities:
		if item.id == entity_id and EntityAvailability.contains(item, ECS.world):
			return item
	return null
#endregion
