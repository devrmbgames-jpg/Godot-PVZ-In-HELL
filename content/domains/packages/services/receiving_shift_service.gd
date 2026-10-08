extends RefCounted
## Единая проверка утренней разгрузки и граница обратного груза до изменения фазы.
class_name ReceivingShiftService

class Status extends RefCounted:
	## Позиции партии, которые ещё не поступили физически.
	var pending: int = 0
	## Поступившие коробки, всё ещё пересекающие область кузова.
	var inside: int = 0
	## Исчезнувшие/уничтоженные коробки без ручного заявления LOST.
	var missing: int = 0
	## Текущие запреты, используемые исполнением перехода и интерфейсом.
	var reasons: PackedStringArray = []


#region Одна проверка текущего состояния
## Собирает текущие запреты; zone_filter ограничивает сводку вывески одной зоной.
static func status(cycle: C_DayCycle, zone_filter: E_ReceivingZoneBody = null) -> Status:
	var result: Status = Status.new()
	if cycle == null or not is_instance_valid(ECS.world):
		result.reasons.append("Поставка недоступна")
		return result

	var parcels: Dictionary[String, Entity] = {}
	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		if EntityAvailability.contains(parcel, ECS.world):
			var identity: C_Package = parcel.get_component(C_Package) as C_Package
			parcels[identity.package_id] = parcel
	var received: Dictionary[String, bool] = {}
	var ledger: C_PackageLedger = PackageQueries.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records:
			received[record.package_id] = true
	var declared_lost: Dictionary[String, bool] = {}
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			if visit.declaration == CustomerVisit.Declaration.LOST:
				declared_lost[visit.package_id] = true
	var players: Array[PhysicsBody3D] = player_bodies()
	var zones: Array[Entity] = []
	if zone_filter != null:
		zones.append(zone_filter)
	else:
		zones.assign(ECS.world.query.with_all([C_Receiving]).execute())
	var unprepared: bool = false
	var unavailable: bool = false
	var player_inside: bool = false

	for candidate: Entity in zones:
		var zone: E_ReceivingZoneBody = candidate as E_ReceivingZoneBody
		if not is_instance_valid(zone) or zone.truck_parking == null:
			continue
		var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
		if receiving == null or receiving.last_started_day != cycle.day_index:
			unprepared = true
			continue
		for batch: ReceivingBatch in receiving.pending:
			result.pending += maxi(0, batch.package_keys.size() - batch.next_package)
		var truck: E_MorningTruck = zone.get_truck()
		if truck == null or not truck.has_cargo_volume() or not truck.is_ready_for_loading():
			unavailable = true
			continue
		for player_body: PhysicsBody3D in players:
			if truck.overlaps_cargo(player_body):
				player_inside = true
		for package_id: String in receiving.incoming_package_ids:
			if declared_lost.has(package_id):
				continue
			var parcel: Entity = parcels.get(package_id) as Entity
			if parcel == null:
				if received.has(package_id):
					result.missing += 1
				continue
			var condition: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
			var body: PhysicsBody3D = parcel as Node as PhysicsBody3D
			if body == null or (condition != null and condition.damage == C_PackageState.Damage.DESTROYED):
				result.missing += 1
			elif truck.overlaps_cargo(body):
				result.inside += 1

	if unprepared:
		result.reasons.append("Поставка ещё не подготовлена")
	if unavailable:
		result.reasons.append("Машина ещё не готова к разгрузке")
	if result.pending > 0:
		result.reasons.append("Поставка не завершена: осталось %d" % result.pending)
	if result.inside > 0:
		result.reasons.append("Выгрузите коробки из машины: %d" % result.inside)
	if result.missing > 0:
		result.reasons.append("Нет коробок: %d · отметьте потерю в терминале" % result.missing)
	if player_inside:
		result.reasons.append("Выйдите из кузова")
	return result


## Читает зарегистрированные физические тела игроков один раз для проверки/короткого отправления.
static func player_bodies() -> Array[PhysicsBody3D]:
	var players: Array[PhysicsBody3D] = []
	if not is_instance_valid(ECS.world):
		return players
	for player: Entity in ECS.world.query.with_all([C_PlayerInputController]).execute():
		var body: PhysicsBody3D = player as Node as PhysicsBody3D
		if EntityAvailability.contains(player, ECS.world) and body != null:
			players.append(body)
	return players
#endregion


#region Граница отправления
## Вызывается из CommandBuffer до смены MORNING; живой обратный груз ещё доступен обработчику.
static func commit_departure(cycle: C_DayCycle) -> bool:
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING or not status(cycle).reasons.is_empty():
		return false
	var players: Array[PhysicsBody3D] = player_bodies()
	for candidate: Entity in ECS.world.query.with_all([C_Receiving]).execute():
		var zone: E_ReceivingZoneBody = candidate as E_ReceivingZoneBody
		if not is_instance_valid(zone) or zone.truck_parking == null:
			continue
		var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
		var truck: E_MorningTruck = zone.get_truck()
		if receiving.dispatched_batch_id != receiving.batch_id:
			zone.cargo_commit_requested.emit(truck, receiving.batch_id)
			receiving.dispatched_batch_id = receiving.batch_id
		if is_instance_valid(truck) and not truck.is_queued_for_deletion():
			truck.request_departure(players)
	return true


## Завершает runtime-машину при внешнем изменении фазы; учёт обратного груза здесь не повторяется.
static func request_departure(zone: E_ReceivingZoneBody) -> void:
	if not is_instance_valid(zone):
		return
	var truck: E_MorningTruck = zone.get_truck()
	if truck != null and not truck.is_departing():
		truck.request_departure(player_bodies())
#endregion
