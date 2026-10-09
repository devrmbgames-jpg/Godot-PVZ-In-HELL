extends RefCounted
## Читает визиты и условия обслуживания без изменения состояния потока.
class_name CustomerFlowQueries

static var _lookup_world: World = null
static var _flow_reference: WeakRef = null
static var _counter_reference: WeakRef = null

#region Чтение состояния
## Читает данные потока обслуживания из текущего мира; при отсутствии возвращает null.
static func current() -> C_CustomerFlow:
	if not is_instance_valid(ECS.world):
		return null


	_prepare_lookup()
	var session: Entity = _flow_reference.get_ref() as Entity if _flow_reference != null else null
	if session == null or not ECS.world.entity_to_archetype.has(session) or not session.has_component(C_CustomerFlow):
		session = ECS.world.query.with_all([C_CustomerFlow]).execute_one()
		_flow_reference = weakref(session) if session != null else null
	return session.get_component(C_CustomerFlow) as C_CustomerFlow if session != null else null

## Находит заказ по стабильному ID визита, включая завершённые записи.
static func find_visit(id: StringName) -> CustomerVisit:
	var flow: C_CustomerFlow = current()
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			if visit.visit_id == id:
				return visit
	return null

## Возвращает стойку выдачи текущего мира, если она присутствует.
static func counter() -> E_DeliveryCounter:

	if not is_instance_valid(ECS.world):
		return null
	_prepare_lookup()
	var station: E_DeliveryCounter = _counter_reference.get_ref() as E_DeliveryCounter if _counter_reference != null else null
	if station == null or not ECS.world.entity_to_archetype.has(station):
		station = ECS.world.query.with_all([C_DeliveryCounter]).execute_one() as E_DeliveryCounter
		_counter_reference = weakref(station) if station != null else null
	return station

static func _prepare_lookup() -> void:
	if _lookup_world != ECS.world:
		_lookup_world = ECS.world
		_flow_reference = null
		_counter_reference = null

## Читает зарегистрированных клиентов сразу: query-кеш GECS обновляется только в конце пакета команд.
static func customer_for(visit_id: StringName) -> E_NpcCharacter:
	if not is_instance_valid(ECS.world):
		return null

	for customer: Entity in ECS.world.entities:
		if not is_instance_valid(customer):
			continue

		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent != null and agent.visit_id == visit_id:
			return customer as E_NpcCharacter
	return null

## Выбирает ожидающего коробку клиента стойки; домашняя встреча не участвует.
static func waiting_customer() -> E_NpcCharacter:
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		if HomeMeetingQueries.meeting_for(customer) != null:
			continue

		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
			return customer as E_NpcCharacter
	return null

## Считает незавершённые визиты, назначенные не позднее указанного дня.
static func remaining(flow: C_CustomerFlow, day: int) -> int:
	var count: int = 0
	for visit: CustomerVisit in flow.visits:
		if visit.arrival_day <= day and not visit.finished:
			count += 1
	return count

## Завершение смены блокируют только возможные приходы: визит за коробкой
## становится доступен после появления регистрационной записи коробки.
static func actionable_remaining(flow: C_CustomerFlow, day: int) -> int:
	var count: int = 0
	for visit: CustomerVisit in flow.visits:
		if not visit_due(visit, day):
			continue
		if visit.started or arrival_allowed(visit):
			count += 1
	return count

## Проверяет календарную доступность одинаково для очереди и окончания смены.
static func visit_due(visit: CustomerVisit, day: int) -> bool:
	return visit != null and not visit.finished and not visit.customer_dead and visit.arrival_day <= day and visit.deferred_day != day

## Допускает визит за коробкой только после действующей записи регистрации.
static func arrival_allowed(visit: CustomerVisit) -> bool:
	if visit == null:
		return false
	if not visit.requires_registered_package:
		return true

	var ledger: C_PackageLedger = PackageQueries.ledger()
	return ledger != null and _has_active_registration_record(ledger, visit.package_id)

static func _has_active_registration_record(
	ledger: C_PackageLedger,
	package_id: String,
) -> bool:
	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == package_id and record.active and record.number > 0:
			return true
	return false

## Looks up the next isolated arrival without mutating queue, visit or physical state.
static func next_arrival(flow: C_CustomerFlow, cycle: C_DayCycle) -> CustomerVisit:
	if cycle.phase != C_DayCycle.Phase.DAY or flow.arrival_cooldown_seconds > 0.0:
		return null

	# Registered entities are authoritative before CommandBuffer query-cache invalidation.
	for customer: Entity in ECS.world.entities:
		if is_instance_valid(customer) and customer.has_component(C_CustomerAgent):
			return null

	for visit: CustomerVisit in flow.visits:
		if not visit.started and not visit.finished and visit.arrival_day <= cycle.day_index:
			if arrival_allowed(visit):
				return visit
	return null

## Проверяет живую связь R_AssignedTo и совпадение заказа с предлагаемой коробкой.
static func assigned(parcel: Entity, customer: Entity, visit: CustomerVisit) -> bool:
	for relation: Relationship in parcel.relationships:
		if relation.relation is R_AssignedTo and relation.target == customer:
			return (relation.relation as R_AssignedTo).visit_id == visit.visit_id
	return false

## Явное заявление игрока для разгрузки: отсутствие тела или просрочка сами не означают LOST.
static func package_declared_lost(package_id: String) -> bool:
	var flow: C_CustomerFlow = current()
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			if visit.package_id == package_id and visit.declaration == CustomerVisit.Declaration.LOST:
				return true
	return false
## Читает конкретный заказ текущей роли; живого назначения не создаёт.
static func visit_for(body: Entity) -> CustomerVisit:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	return find_visit(agent.visit_id) if agent != null else null
#endregion
