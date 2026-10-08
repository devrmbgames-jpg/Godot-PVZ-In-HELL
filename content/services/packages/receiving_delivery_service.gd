extends RefCounted
## Фиксирует ограниченную утреннюю поставку и создаёт коробки с реальными заказами.
class_name ReceivingDeliveryService

const BLOCKED_RETRY_SECONDS: float = 0.25

#region Ежедневная поставка
## Фиксирует ограниченную партию дня; непривезённый остаток не копится между утрами.
static func prepare_batch(supply: DEF_Delivery, receiving: C_Receiving, day_index: int) -> void:
	if supply == null or receiving.last_started_day >= day_index:
		return

	receiving.pending.clear()
	receiving.batch_id = "%s:%d" % [supply.key, day_index]
	receiving.incoming_package_ids.clear()
	receiving.last_started_day = day_index
	receiving.blocked = false
	var available: int = maxi(0, supply.maximum_waiting_packages - waiting_count())
	var limit: int = mini(supply.maximum_batch_packages, available)
	if limit == 0 or supply.packages.is_empty():
		return

	var batch: ReceivingBatch = ReceivingBatch.new()
	batch.day_index = day_index
	var start_index: int = ((day_index - 1) * supply.maximum_batch_packages) % supply.packages.size()
	for offset: int in supply.packages.size():
		var definition: DEF_Package = supply.packages[(start_index + offset) % supply.packages.size()]
		if definition == null or definition.scene_variants.is_empty() or not _has_recipient(definition):
			continue
		batch.package_keys.append(String(definition.key))
		batch.package_scenes.append(String(definition.scene_variants.pick_random()))
		receiving.incoming_package_ids.append("%s:%s" % [receiving.batch_id, definition.key])
		if batch.package_keys.size() >= limit:
			break
	if not batch.package_keys.is_empty():
		receiving.pending.append(batch)


## Считает физические коробки с будущим получением; терминальные случаи и мёртвые исключены.
static func waiting_count() -> int:
	if not is_instance_valid(ECS.world):
		return 0

	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var cases: Dictionary[String, CustomerVisit] = {}
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			cases[visit.package_id] = visit
	var count: int = 0
	for parcel: Entity in ECS.world.query.with_all([C_Package, C_PackageState]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
		if state.registration >= C_PackageState.Registration.DELIVERED or identity.definition == null:
			continue
		var visit: CustomerVisit = cases.get(identity.package_id) as CustomerVisit
		if visit != null:
			var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
			if visit.customer_dead or (person != null and person.death_day != 0):
				continue
			if visit.actual != CustomerVisit.Actual.NOT_RESOLVED or visit.declaration != CustomerVisit.Declaration.NONE or visit.settlement_committed or visit.complaint != null:
				continue
			if (visit.definition != null and visit.definition.voluntary_refusal) or (visit.finished and visit.next_followup_day == 0):
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
		if event.package_key == definition.key and event.customer != null and event.arrival_delay_days >= 0:
			return true
	return false
#endregion

#region Физическая доставка
## Создаёт одну коробку из зафиксированной партии, сохраняя возможность повтора при занятой зоне.
static func deliver_one(
	zone: E_ReceivingZone,
	receiving: C_Receiving,
	day_index: int,
) -> void:
	if not is_instance_valid(zone) or zone.supply == null:
		return
	prepare_batch(zone.supply, receiving, day_index)
	if zone.truck_parking != null:
		var truck: E_MorningTruck = zone.ensure_truck()
		if truck == null or not truck.is_ready_for_loading():
			receiving.blocked = truck == null
			return
	if receiving.pending.is_empty():
		return
	if receiving.last_spawn_tick == Engine.get_physics_frames():
		return

	var batch: ReceivingBatch = receiving.pending[0]
	if batch.next_package >= batch.package_keys.size():
		receiving.pending.pop_front()
		receiving.blocked = false
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
		_advance(receiving, batch)
		return
	var package_id: String = "%s:%d:%s" % [zone.supply.key, batch.day_index, definition.key]
	if ReceivingPackageFactory.exists(package_id) or PackageHistoryService.record_for(package_id) != null:
		_advance(receiving, batch)
		return

	var parcel: E_Package = ReceivingPackageFactory.create(
		zone,
		definition,
		package_id,
		batch.day_index,
		batch.next_package,
		batch.package_scenes[batch.next_package] if batch.next_package < batch.package_scenes.size() else "",
	)
	if parcel == null:
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return
	if not ReceivingPackageFactory.try_place(zone, parcel):
		parcel.free()
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return

	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	if identity == null:
		ECS.world.remove_entity(parcel)
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return

	identity.delivery_day = batch.day_index
	identity.supply_key = zone.supply.key
	if PackageHistoryService.record_arrival(parcel, batch.day_index) == null:
		ECS.world.remove_entity(parcel)
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return

	receiving.last_spawn_tick = Engine.get_physics_frames()
	var visit: CustomerVisit = CustomerFlowService.plan_delivered_package(identity)
	if visit != null:
		visit.package_history_id = identity.history_id
	_advance(receiving, batch)


## Сбрасывает временные повторы и резервы после восстановления снимка; состав партии сохраняется.
static func reset_context(receiving: C_Receiving) -> void:
	receiving.context_revision += 1
	receiving.blocked = false
	receiving.retry_remaining = 0.0
	receiving.last_spawn_tick = -1
	receiving.reservation_frame = -1
	receiving.reservations.clear()


static func _advance(receiving: C_Receiving, batch: ReceivingBatch) -> void:
	batch.next_package += 1
	receiving.delivered_counts[batch.day_index] = batch.next_package
	receiving.blocked = false
#endregion
