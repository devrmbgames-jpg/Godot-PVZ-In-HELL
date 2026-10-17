extends RefCounted
## Фиксирует ограниченную утреннюю поставку и создаёт коробки с реальными заказами.
class_name ReceivingDeliveryService

const BLOCKED_RETRY_SECONDS: float = 0.25


#region Ежедневная поставка
## Фиксирует ограниченную партию дня; непривезённый остаток не копится между утрами.
## Даже пустая партия отмечает last_started_day; повтор того же/раннего дня ничего не меняет.
static func prepare_batch(supply: DEF_Delivery, receiving: C_Receiving, day_index: int) -> void:
	if supply == null or receiving.last_started_day >= day_index:
		return

	receiving.pending.clear()
	receiving.batch_id = "%s:%d" % [supply.key, day_index]
	receiving.incoming_package_ids.clear()
	receiving.last_started_day = day_index
	receiving.completion_published_batch = ""
	receiving.blocked = false
	var available: int = maxi(0, supply.maximum_waiting_packages - waiting_count())
	var limit: int = mini(supply.maximum_batch_packages, available)
	if limit == 0 or supply.packages.is_empty():
		return

	var batch: ReceivingBatch = ReceivingBatch.new()
	batch.day_index = day_index
	var start_index: int = (
		((day_index - 1) * supply.maximum_batch_packages) % supply.packages.size()
	)
	for offset: int in supply.packages.size():
		var definition: DEF_Package = (
			supply.packages[(start_index + offset) % supply.packages.size()]
		)
		if (definition == null or not _has_recipient(definition)):
			continue
		var package_id: String = "%s:%s" % [receiving.batch_id, definition.key]
		var ordered_item: DEF_InventoryItem = _order_item(supply, definition, package_id, day_index)
		var shipment: PackageShipmentPlan = null
		var scene_path: String = ""
		if ordered_item != null:
			shipment = PackageShipmentRules.choose(
				ordered_item,
				supply.packing_profiles,
				GameTimeQueries.current().world_seed,
				package_id,
				day_index,
			)
			if shipment == null:
				continue
			scene_path = shipment.scene_path()
		else:
			if definition.scene_variants.is_empty():
				continue
			scene_path = PackageSceneRules.variant_for(
				definition,
				package_id,
				day_index,
				GameTimeQueries.current().world_seed,
			)
		batch.package_keys.append(String(definition.key))
		batch.package_scenes.append(scene_path)
		batch.order_item_paths.append(ordered_item.resource_path if ordered_item != null else "")
		batch.order_quantities.append(shipment.quantity() if shipment != null else 0)
		batch.order_packing_paths.append(
			shipment.packing().resource_path if shipment != null else ""
		)
		receiving.incoming_package_ids.append("%s:%s" % [receiving.batch_id, definition.key])
		if batch.package_keys.size() >= limit:
			break
	if not batch.package_keys.is_empty():
		receiving.pending.append(batch)


static func _order_item(
	supply: DEF_Delivery,
	definition: DEF_Package,
	package_id: String,
	day_index: int,
) -> DEF_InventoryItem:
	if definition.unpack_scene == null or supply.order_catalog.is_empty():
		return null
	var person: NpcRecord = NpcPopulationQueries.recipient_for(definition.recipient_id)
	if person == null:
		return null
	return PackageOrderRules.choose(
		supply.order_catalog,
		person.profile.item_category_weights,
		GameTimeQueries.current().world_seed,
		String(person.npc_id),
		day_index,
		package_id,
	)


## Считает физические коробки с будущим получением; терминальные случаи и мёртвые исключены.
static func waiting_count() -> int:
	if not is_instance_valid(ECS.world):
		return 0

	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var cases: Dictionary[String, CustomerVisit] = { }
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			cases[visit.package_id] = visit
	var count: int = 0
	for parcel: Entity in ECS.world.query.with_all([C_Package, C_PackageState]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
		if (
			state.registration >= C_PackageState.Registration.DELIVERED
			or identity.definition == null
		):
			continue
		var visit: CustomerVisit = cases.get(identity.package_id) as CustomerVisit
		if visit != null:
			var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
			if visit.customer_dead or (person != null and person.death_day != 0):
				continue
			if (
				visit.actual != CustomerVisit.Actual.NOT_RESOLVED
				or visit.declaration != CustomerVisit.Declaration.NONE
				or visit.settlement_committed or visit.complaint != null
			):
				continue
			if (
				(visit.definition != null and visit.definition.voluntary_refusal)
				or (visit.finished and visit.next_followup_day == 0)
			):
				continue
		elif not _has_recipient(identity.definition):
			continue
		count += 1
	return count


static func _has_recipient(definition: DEF_Package) -> bool:
	if NpcPopulationQueries.current() == null:
		return true
	if NpcPopulationQueries.recipient_for(definition.recipient_id) == null:
		return false

	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow == null or flow.schedule == null:
		return false
	for event: DEF_CustomerEvent in flow.schedule.events:
		if (
			event.package_key == definition.key
			and event.customer != null and event.arrival_delay_days >= 0
		):
			return true
	return false
#endregion


#region Физическая доставка
## Пробует не более одной позиции партии; существующий package/history пропускается без нового тела.
## Занятая зона сохраняет текущую позицию для retry; delivered_counts отражает пройденные позиции.
## Реально размещённая коробка получает номер до planning; факт регистрации публикуется последним.
static func deliver_one(zone: E_ReceivingZone, receiving: C_Receiving, day_index: int) -> void:
	if not is_instance_valid(zone) or zone.supply == null:
		return
	prepare_batch(zone.supply, receiving, day_index)
	if zone.truck_parking != null:
		var truck: E_MorningTruck = zone.ensure_truck()
		if truck == null or not truck.is_ready_for_loading():
			receiving.blocked = truck == null
			return
	if receiving.pending.is_empty():
		_publish_completion(zone, receiving, day_index)
		return
	if receiving.last_spawn_tick == Engine.get_physics_frames():
		return

	var batch: ReceivingBatch = receiving.pending[0]
	if batch.next_package >= batch.package_keys.size():
		receiving.pending.pop_front()
		receiving.blocked = false
		_publish_completion(zone, receiving, day_index)
		return
	if waiting_count() >= zone.supply.maximum_waiting_packages:
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return

	var definition: DEF_Package = null
	for candidate: DEF_Package in zone.supply.packages:
		if String(candidate.key) == batch.package_keys[batch.next_package]:
			definition = candidate
			break
	if definition == null:
		_advance(zone, receiving, batch)
		return
	var package_id: String = "%s:%d:%s" % [zone.supply.key, batch.day_index, definition.key]
	if (
		ReceivingPackageFactory.exists(package_id)
		or PackageHistoryService.record_for(package_id) != null
	):
		_advance(zone, receiving, batch)
		return

	var package_scene: String = ""
	if batch.next_package < batch.package_scenes.size():
		package_scene = batch.package_scenes[batch.next_package]
	var shipment: PackageShipmentPlan = _retained_shipment(batch)
	if not batch.order_item_paths[batch.next_package].is_empty() and shipment == null:
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return
	var parcel: E_Package = ReceivingPackageFactory.create(
		zone,
		definition,
		package_id,
		batch.day_index,
		batch.next_package,
		package_scene,
		shipment,
	)
	if parcel == null:
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return
	var initial_fields: Dictionary[Script, Dictionary] = { }
	initial_fields[C_Package as Script] = {
		&"delivery_day": batch.day_index,
		&"supply_key": zone.supply.key,
	}
	if shipment != null:
		initial_fields[C_PackageContents as Script] = shipment.contents_fields()
	if not ReceivingPackageFactory.try_place(zone, parcel, initial_fields):
		parcel.free()
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return

	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var registration: PackageScanResult = PackageRegistrationService.register_package(parcel, false)
	if registration.outcome != PackageScanResult.Outcome.REGISTERED:
		ECS.world.remove_entity(parcel)
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return

	receiving.last_spawn_tick = Engine.get_physics_frames()
	var world: World = ECS.world
	var parcel_reference: WeakRef = weakref(parcel)
	_advance(zone, receiving, batch)
	# Факт полного прибытия тоже допускает синхронные callbacks с реальной сменой lifetime.
	parcel = parcel_reference.get_ref() as E_Package
	if (
		ECS.world != world or not EntityAvailability.contains(zone, world)
		or zone.get_component(C_Receiving) != receiving
		or not EntityAvailability.contains(parcel, world)
		or parcel.get_component(C_Package) != identity
	):
		return
	# Commit manifest and registration before planning/registration callbacks can re-enter.
	CustomerFlowService.plan_delivered_package(identity)
	parcel = parcel_reference.get_ref() as E_Package
	if (
		ECS.world == world and EntityAvailability.contains(parcel, world)
		and parcel.get_component(C_Package) == identity
	):
		world.emit_event(PackageScanResult.EVENT, parcel, registration)


## Сбрасывает временные повторы и резервы после восстановления снимка; состав партии сохраняется.
static func reset_context(receiving: C_Receiving) -> void:
	receiving.context_revision += 1
	receiving.blocked = false
	receiving.retry_remaining = 0.0
	receiving.last_spawn_tick = -1
	receiving.reservation_frame = -1
	receiving.reservations.clear()
	receiving.completion_published_batch = ""


## Rehydrates committed values only; catalog/preferences and decision RNG are not consulted.
static func _retained_shipment(batch: ReceivingBatch) -> PackageShipmentPlan:
	var index: int = batch.next_package
	var item_path: String = batch.order_item_paths[index]
	if item_path.is_empty():
		return null
	var packing_path: String = batch.order_packing_paths[index]
	if (
		not GameplayResourcePaths.is_definition_path(item_path)
		or not GameplayResourcePaths.is_definition_path(packing_path)
		or not ResourceLoader.exists(item_path) or not ResourceLoader.exists(packing_path)
	):
		return null
	var item: DEF_InventoryItem = load(item_path) as DEF_InventoryItem
	var packing: DEF_PackagePacking = load(packing_path) as DEF_PackagePacking
	var quantity: int = batch.order_quantities[index]
	var path: String = batch.package_scenes[index]
	if (
		not PackageOrderRules.is_orderable(item)
		or not PackageShipmentRules.valid(item, quantity, packing, path)
	):
		return null
	return PackageShipmentPlan.new(item, quantity, packing, path)


static func _advance(zone: E_ReceivingZone, receiving: C_Receiving, batch: ReceivingBatch) -> void:
	batch.next_package += 1
	receiving.delivered_counts[batch.day_index] = batch.next_package
	receiving.blocked = false
	if batch.next_package >= batch.package_keys.size():
		receiving.pending.erase(batch)
		_publish_completion(zone, receiving, batch.day_index)


static func _publish_completion(zone: E_ReceivingZone, receiving: C_Receiving, day: int) -> void:
	if (
		not receiving.pending.is_empty() or receiving.batch_id.is_empty()
		or receiving.last_started_day != day
		or receiving.completion_published_batch == receiving.batch_id
	):
		return
	receiving.completion_published_batch = receiving.batch_id
	var fact: ReceivingSupplyCompleted = ReceivingSupplyCompleted.new(
		receiving,
		PackageQueries.ledger(),
	)
	ECS.world.emit_event(ReceivingSupplyCompleted.EVENT, zone, fact)
#endregion
