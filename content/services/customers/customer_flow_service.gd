extends RefCounted
## Владеет обслуживанием посылок и визитами; изменения выполняет вне обхода GECS через CommandBuffer.
class_name CustomerFlowService


static var _lookup_world: World = null
static var _flow_reference: WeakRef = null
static var _counter_reference: WeakRef = null

#region Поиск данных обслуживания
## Читает данные потока обслуживания из текущего мира; при отсутствии возвращает null.
static func current() -> C_CustomerFlow:
	if not is_instance_valid(ECS.world):
		return null


	_prepare_lookup()
	var owner: Entity = _flow_reference.get_ref() as Entity if _flow_reference != null else null
	if owner == null or not ECS.world.entity_to_archetype.has(owner) or not owner.has_component(C_CustomerFlow):
		owner = ECS.world.query.with_all([C_CustomerFlow]).execute_one()
		_flow_reference = weakref(owner) if owner != null else null
	return owner.get_component(C_CustomerFlow) as C_CustomerFlow if owner != null else null


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


## Находит живую физическую коробку по точному package_id.
static func parcel_for(package_id: String) -> Entity:
	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		if identity.package_id == package_id:
			return parcel
	return null


## Читает зарегистрированных клиентов сразу: query-кеш GECS обновляется только в конце пакета команд.
static func customer_for(visit_id: StringName) -> E_Customer:
	if not is_instance_valid(ECS.world):
		return null

	for customer: Entity in ECS.world.entities:
		if not is_instance_valid(customer):
			continue

		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent != null and agent.visit_id == visit_id:
			return customer as E_Customer
	return null


## Выбирает ожидающего коробку клиента стойки; домашняя встреча не участвует.
static func waiting_customer() -> E_Customer:
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		if NpcHomeDeliveryService.meeting_for(customer) != null:
			continue

		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
			return customer as E_Customer
	return null


#endregion

#region Планирование и сверка заказов


## Фиксирует визит для реально привезённой коробки, без повторного заказа при повторе команды.
static func plan_delivered_package(identity: C_Package) -> CustomerVisit:
	var flow: C_CustomerFlow = current()
	if flow == null or flow.schedule == null or flow.schedule.supply == null or identity.definition == null or identity.supply_key != flow.schedule.supply.key:
		return null

	var wallet: C_Wallet = WalletService.current()
	var payment: int = wallet.policy.delivery_payment if wallet != null and wallet.policy != null else 0
	for event: DEF_CustomerEvent in flow.schedule.events:
		if event.package_key == identity.definition.key and event.customer != null and event.arrival_delay_days >= 0:
			var visit: CustomerVisit = create_visit(
				flow, identity.definition, event, identity.delivery_day, payment
			)
			if visit != null:
				visit.package_history_id = identity.history_id
			return visit
	return null


## Creates one idempotent visit for an explicit supplied package/event pair.
static func create_visit(
	flow: C_CustomerFlow, definition: DEF_Package, event: DEF_CustomerEvent,
	supply_day: int, payment: int,
) -> CustomerVisit:
	var package_id: String = "%s:%d:%s" % [flow.schedule.supply.key, supply_day, definition.key]
	var visit_id: StringName = StringName("visit/" + package_id)
	for existing: CustomerVisit in flow.visits:
		if existing.visit_id == visit_id:
			return existing

	var district: C_District = DistrictPopulationService.current()
	var recipient: NpcRecord = DistrictPopulationService.recipient_for(definition.recipient_id) if district != null else null
	if district != null and recipient == null:
		return null

	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = visit_id
	visit.package_id = package_id
	visit.customer_id = recipient.npc_id if recipient != null else StringName("%s:%d" % [definition.recipient_id, supply_day])
	visit.definition = event.customer
	visit.requires_registered_package = event.requires_registered_package
	visit.arrival_day = supply_day + event.arrival_delay_days
	visit.accounting_value = definition.accounting_value
	visit.payment = payment
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = String(visit_id).hash()
	visit.complaint_roll = random.randf()
	visit.aggression_roll = random.randf()
	flow.visits.append(visit)
	return visit


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

	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	return ledger != null and _has_active_registration_record(ledger, visit.package_id)


static func _has_active_registration_record(
	ledger: C_PackageLedger,
	package_id: String,
) -> bool:
	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == package_id and record.active and record.number > 0:
			return true
	return false


#endregion

#region Приход и исполнение роли
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


## Materializes one selected isolated visit; scheduling and selection belong to its caller.
static func start_visit(flow: C_CustomerFlow, visit: CustomerVisit, day: int) -> void:
	var station: E_DeliveryCounter = counter()
	var scene: PackedScene = flow.schedule.customer_scene
	if not visit.definition.customer_scene_path.is_empty():
		scene = load(visit.definition.customer_scene_path) as PackedScene if ResourceLoader.exists(visit.definition.customer_scene_path) else null
	if station == null or scene == null:
		visit.started = true
		finish(visit, day)
		return

	var node: Node = scene.instantiate()
	var customer: E_Customer = node as E_Customer
	if customer == null:
		node.free()
		visit.started = true
		finish(visit, day)
		return

	station.get_parent().add_child(customer)
	(customer as Node as Node3D).global_position = station.entry_position()
	ECS.world.add_entity(customer, null, false)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = visit.visit_id
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	if challenge != null:
		challenge.definition = visit.definition.challenge

	var motion: C_Motion = customer.get_component(C_Motion) as C_Motion
	if motion != null:
		motion.max_speed = maxf(0.0, visit.definition.move_speed)
	NpcIntentService.move_to(customer, station.waiting_position(), visit.definition.arrival_distance)
	NpcIntentService.look_along_movement(customer)
	visit.started = true
	visit.visit_count += 1
	visit.last_visit_day = day
	bind_parcel(customer, visit)
	customer.show_message(visit.definition.display_name)

	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if ChallengeService.begin_on_arrival(customer, player):
		customer.show_message(challenge.definition.rule_text)
		CustomerArrivalService.begin(customer, challenge)
	CustomerGreetingService.announce_order(customer, visit)


## Резервирует нужную коробку через R_AssignedTo, не меняя её физического положения.
static func bind_parcel(customer: Entity, visit: CustomerVisit) -> void:
	var parcel: Entity = parcel_for(visit.package_id)
	if parcel == null:
		return

	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	if identity != null and visit.package_history_id.is_empty():
		visit.package_history_id = identity.history_id
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	if state == null or state.registration >= C_PackageState.Registration.DELIVERED:
		return

	for relation: Relationship in parcel.relationships:
		if relation.relation is R_AssignedTo:
			return

	var assignment: R_AssignedTo = R_AssignedTo.new()
	assignment.visit_id = visit.visit_id
	parcel.add_relationship(Relationship.new(assignment, customer))


## Проверяет живую связь R_AssignedTo и совпадение заказа с предлагаемой коробкой.
static func assigned(parcel: Entity, customer: Entity, visit: CustomerVisit) -> bool:
	for relation: Relationship in parcel.relationships:
		if relation.relation is R_AssignedTo and relation.target == customer:
			return (relation.relation as R_AssignedTo).visit_id == visit.visit_id
	return false


## Removes one completed or orphaned appearance, preserving retained district bodies.
static func remove_appearance(customer: E_Customer, visit: CustomerVisit) -> void:
	if customer is E_DistrictNpc:
		if visit != null:
			NpcServiceRole.finish_appearance(customer as E_DistrictNpc, visit)
		else:
			var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
			if agent != null:
				NpcServiceRole.release(customer, agent.visit_id)
	else:
		ECS.world.remove_entity(customer)
	if visit != null:
		CustomerOutcomeService.publish_change(visit, &"appearance_removed")


#endregion

#region Приветствие и физическая выдача
## Сообщает заказ и переводит прибывшего клиента к ожиданию посылки.
static func greet(customer: E_Customer) -> void:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or find_visit(agent.visit_id) == null:
		return
	if agent.phase != C_CustomerAgent.Phase.WAITING and agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return

	_transition(agent, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	var visit: CustomerVisit = find_visit(agent.visit_id)
	if CustomerPresentation.uses_wall_order(visit.definition):
		customer.show_message("Номер моего заказа появился на стене. Выдайте его на стойке, не смотрите на меня.")
	elif CustomerPresentation.uses_quick_visit(visit):
		if not agent.order_announced:
			customer.show_message(CustomerPresentation.request_text(visit))
		CustomerGreetingService.announce_order(customer, visit)
	else:
		customer.show_message("Здравствуйте. Поговорите со мной, чтобы узнать номер заказа.")


## Проверяет коробку на стойке и применяет общую выдачу или начало осмотра.
static func confirm_delivery(station: E_DeliveryCounter) -> PackageDeliveryCheck.Result:
	var customer: E_Customer = waiting_customer()
	if customer == null:
		return PackageDeliveryCheck.Result.MISSING

	var parcels: Array[Entity] = station.parcels()
	if parcels.size() != 1:
		var result: PackageDeliveryCheck.Result = (
			PackageDeliveryCheck.Result.MISSING
			if parcels.is_empty()
			else PackageDeliveryCheck.Result.MULTIPLE
		)
		station.show_message(CustomerPresentation.check_text(result))
		return result

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = find_visit(agent.visit_id)
	var result: PackageDeliveryCheck.Result = _resolve_delivery(
		customer,
		visit,
		parcels[0],
		null,
	)
	if result != PackageDeliveryCheck.Result.READY:
		station.show_message(CustomerPresentation.check_text(result))
		return result

	station.show_message("Выдача обработана. Отметьте исход в терминале.")
	return result


## Выбирает предлагаемую коробку из удерживаемых игроком; нужный заказ имеет приоритет,
## даже если у игрока несколько коробок в Carry и ручных слотах.
## allow_greeting разрешает только предварительный поиск для ближнего автоприёма.
static func direct_handoff_package(actor: Entity, customer: E_Customer, allow_greeting: bool = false) -> Entity:
	if not is_instance_valid(actor) or not is_instance_valid(customer):
		return null

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or (agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE and not (allow_greeting and agent.phase == C_CustomerAgent.Phase.WAITING)):
		return null

	var visit: CustomerVisit = find_visit(agent.visit_id)
	if (
		visit == null
		or visit.finished
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
	):
		return null

	var fallback: Entity = null
	for slot_index: int in [
		C_Grabbable.HoldSlot.CARRY,
		C_Grabbable.HoldSlot.RIGHT_HAND,
		C_Grabbable.HoldSlot.LEFT_HAND,
	]:
		var held: Entity = GrabService.held_in_slot(actor, slot_index)
		if held == null:
			continue

		var identity: C_Package = held.get_component(C_Package) as C_Package
		if identity == null:
			continue
		if fallback == null:
			fallback = held
		if identity.package_id == visit.package_id:
			return held
	return fallback


## Автоприём проходит те же правила выдачи/осмотра; ошибочные предложения не меняют мир.
static func try_automatic_handoff(customer: E_Customer, visit: CustomerVisit) -> bool:
	if visit == null or not is_instance_valid(ECS.world):
		return false
	if NpcDeliveryScenarioService.armed_for(customer as E_DistrictNpc) != null:
		return false

	var actor: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	var parcel: Entity = direct_handoff_package(actor, customer, true)
	if not GrabService.entity_available(parcel):
		return false
	if not CustomerHandoffService.can_receive(actor, customer, visit, parcel, assigned(parcel, customer, visit)):
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent.phase == C_CustomerAgent.Phase.WAITING:
		greet(customer)
	return confirm_direct_delivery(actor, customer) == PackageDeliveryCheck.Result.READY


## Проверяет передачу из рук с теми же правилами назначения и принятия.
static func confirm_direct_delivery(
	actor: Entity,
	customer: E_Customer,
) -> PackageDeliveryCheck.Result:
	if NpcDeliveryScenarioService.armed_for(customer as E_DistrictNpc) != null:
		return PackageDeliveryCheck.Result.UNASSIGNED

	var parcel: Entity = direct_handoff_package(actor, customer)
	if parcel == null:
		return PackageDeliveryCheck.Result.MISSING

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = find_visit(agent.visit_id)
	var result: PackageDeliveryCheck.Result = _resolve_delivery(
		customer,
		visit,
		parcel,
		actor,
	)
	if result != PackageDeliveryCheck.Result.READY:
		customer.show_message(CustomerPresentation.check_text(result))
	return result


static func _resolve_delivery(
	customer: E_Customer,
	visit: CustomerVisit,
	parcel: Entity,
	direct_holder: Entity,
) -> PackageDeliveryCheck.Result:
	if customer == null or visit == null or parcel == null:
		return PackageDeliveryCheck.Result.MISSING

	var held: bool = GrabService.held_relationship(parcel) != null
	var allow_held: bool = is_instance_valid(direct_holder)
	var check_result: PackageDeliveryCheck = CustomerOutcomeService.check(
		visit,
		parcel.get_component(C_Package) as C_Package,
		parcel.get_component(C_PackageState) as C_PackageState,
		assigned(parcel, customer, visit),
		held,
		allow_held,
	)
	if check_result.result != PackageDeliveryCheck.Result.READY:
		return check_result.result
	# Допустимая передача освобождает хват игрока до принятия или отказа получателя.
	if allow_held:
		GrabService.release(direct_holder, parcel)
	if CustomerInspectionService.begin(customer, visit, parcel):
		return check_result.result
	return _complete_delivery(customer, visit, parcel, check_result, allow_held)


## Завершает общий осмотр на стойке или у домашней двери.
static func complete_inspection(customer: E_Customer, visit: CustomerVisit) -> void:
	var parcel: Entity = CustomerInspectionService.parcel_for(customer)
	if parcel == null:
		_leave(customer, visit)
		return

	var check_result: PackageDeliveryCheck = CustomerOutcomeService.check(visit, parcel.get_component(C_Package) as C_Package, parcel.get_component(C_PackageState) as C_PackageState, assigned(parcel, customer, visit), false)
	if check_result.result != PackageDeliveryCheck.Result.READY:
		_leave(customer, visit)
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var declined: bool = agent.inspection_force_refusal or CustomerInspectionService.roll(visit, "keep") >= visit.definition.inspection_keep_probability
	_complete_delivery(customer, visit, parcel, check_result, true, declined, true)


static func _complete_delivery(customer: E_Customer, visit: CustomerVisit, parcel: Entity, check_result: PackageDeliveryCheck, place_refused: bool, declined: bool = false, inspection: bool = false) -> PackageDeliveryCheck.Result:
	if not CustomerOutcomeService.receive(visit, check_result, declined):
		return check_result.result
	if inspection:
		CustomerInspectionService.end(customer, visit.actual == CustomerVisit.Actual.DELIVERED)

	if visit.actual == CustomerVisit.Actual.DELIVERED:
		_depart_parcel(parcel)
		ECS.world.remove_entity(parcel)
		customer.show_message(
			"Спасибо!"
			if visit.satisfaction == visit.definition.healthy_satisfaction
			else "Заказ принят, но его состояние меня не устраивает."
		)
	else:
		if place_refused:
			_place_refused_parcel(customer, visit, parcel)
		# При выдаче со стойки освобождённая коробка уже остаётся на стойке.
		customer.show_message("Я отказываюсь от заказа. Коробка остаётся у вас.")

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent != null:
		_transition(agent, C_CustomerAgent.Phase.RECEIVING)
	return check_result.result


## Однократно синхронизирует физическое тело при передаче, как крепление к слоту и восстановление.
## После передачи native rigid body немедленно возобновляет владение физическим состоянием.
static func _place_refused_parcel(customer: E_Customer, visit: CustomerVisit, parcel: Entity) -> void:
	var body: RigidBody3D = parcel as Node as RigidBody3D
	if body == null or visit.definition == null:
		return

	var npc: Node3D = customer as Node as Node3D
	body.global_position = npc.global_transform * visit.definition.refused_parcel_offset
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


#endregion

#region Заявления и реакции
## Явное заявление игрока для разгрузки: отсутствие тела или просрочка сами не означают LOST.
static func package_declared_lost(package_id: String) -> bool:
	var flow: C_CustomerFlow = current()
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			if visit.package_id == package_id and visit.declaration == CustomerVisit.Declaration.LOST:
				return true
	return false


## Фиксирует заявление в журнале и инициирует расчёт; физическую выдачу не подменяет.
static func declare(visit_id: StringName, declaration: CustomerVisit.Declaration) -> bool:
	var visit: CustomerVisit = find_visit(visit_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return false
	if visit.declaration == declaration and declaration != CustomerVisit.Declaration.NONE:
		CustomerOutcomeService.settle(visit, WalletService.current(), cycle.day_index)
		return true
	if not visit.started and declaration == CustomerVisit.Declaration.LOST:
		if PackageHistoryService.record_for(visit.package_id) == null:
			return false
	if not CustomerOutcomeService.declare(visit, declaration):
		return false
	if declaration != CustomerVisit.Declaration.NONE:
		visit.next_followup_day = 0
		visit.followup_committed = false
	if declaration == CustomerVisit.Declaration.LOST and not visit.started:
		visit.finished = true
		visit.finished_day = cycle.day_index
	CustomerOutcomeService.settle(visit, WalletService.current(), cycle.day_index)

	var customer: E_Customer = customer_for(visit_id)
	if customer != null and visit.aggressive:
		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.phase != C_CustomerAgent.Phase.LEAVING:
			# Заявление относится к учёту. Ложное TAKEN может быть обнаружено,
			# но диалог выбирает реакцию до ограниченной фазы Aggressive.
			customer.show_message("Вы ничего мне не выдали! Поговорите со мной.")
	return true


## Явно переносит визит из диалога, гарантируя повторный приход без отказа в выдаче.
static func defer_until_next_day(visit_id: StringName) -> bool:
	var visit: CustomerVisit = find_visit(visit_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if (
		visit == null
		or cycle == null
		or not visit.started
		or visit.finished
		or visit.declaration != CustomerVisit.Declaration.NONE
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or visit.definition == null
		or visit.followup_count >= visit.definition.max_followup_visits
	):
		return false

	var customer: E_Customer = customer_for(visit_id)
	if customer == null:
		return false

	visit.followup_count += 1
	visit.next_followup_day = cycle.day_index + 1
	visit.followup_committed = true
	_leave(customer, visit)
	return true


## Фиксирует отказ игрока; выбирает уже рассчитанную агрессию или уход клиента.
static func deny(visit_id: StringName) -> bool:
	var visit: CustomerVisit = find_visit(visit_id)
	if visit == null or not visit.started:
		return false
	if not CustomerOutcomeService.commit_player_denial(visit):
		return false

	var customer: E_Customer = customer_for(visit_id)
	if customer != null:
		if customer is E_DistrictNpc:
			NpcServiceRole.escalate(customer as E_DistrictNpc)
			visit.aggressive = CombatService.target_for(customer) != null
		if visit.aggressive:
			enter_aggressive(customer)
		else:
			_leave(customer, visit)
	return true


## Подтверждает отказ получателя из старого диалога только после фактической передачи.
static func voluntary_refuse(customer: E_Customer) -> bool:
	if not is_instance_valid(customer):
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return false

	var visit: CustomerVisit = find_visit(agent.visit_id)
	if (
		visit == null
		or visit.definition == null
		or not visit.definition.voluntary_refusal
		or visit.actual != CustomerVisit.Actual.CUSTOMER_REFUSED
		or visit.finished
	):
		return false
	if agent.phase != C_CustomerAgent.Phase.DIALOGUE and agent.phase != C_CustomerAgent.Phase.RECEIVING:
		return false

	_leave(customer, visit)
	return true


## Принимает уже определённую агрессию, не выполняя нового броска реакции.
static func enter_aggressive(customer: E_Customer) -> bool:
	if not is_instance_valid(customer):
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return false

	var visit: CustomerVisit = find_visit(agent.visit_id)
	if (
		visit == null
		or not visit.aggressive
		or visit.finished
		or agent.phase == C_CustomerAgent.Phase.LEAVING
		or agent.phase == C_CustomerAgent.Phase.FINISHED
	):
		return false
	if agent.phase == C_CustomerAgent.Phase.AGGRESSIVE:
		return true

	_transition(agent, C_CustomerAgent.Phase.AGGRESSIVE)
	if customer is E_DistrictNpc:
		NpcServiceRole.escalate(customer as E_DistrictNpc)
	NpcIntentService.stop(customer)
	watch_player(customer)
	customer.show_message("Вы меня обманули!")
	return true


#endregion

#region Завершение и повторные визиты
static func _depart_parcel(parcel: Entity, departure: C_PackageState.Registration = C_PackageState.Registration.DELIVERED) -> void:
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	state.registration = departure
	PackageRegistrationService.release_number(parcel)
	for relation: Relationship in parcel.relationships.duplicate():
		if relation.relation is R_AssignedTo:
			parcel.remove_relationship(relation)


## Закрывает приход однократно и планирует допустимый повтор, сохраняя заказ и личность.
static func finish(visit: CustomerVisit, day: int) -> void:
	if visit.finished:
		return

	var flow: C_CustomerFlow = current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if (
		visit.visit_count > 0 and flow != null and flow.schedule != null
		and cycle != null and cycle.phase == C_DayCycle.Phase.DAY
	):
		var interval: float = flow.schedule.arrival_interval_seconds
		var district: C_District = DistrictPopulationService.current()
		if district != null and DistrictPopulationService.person_for(visit.customer_id) != null:
			interval = district.definition.service_transfer_pause
		flow.arrival_cooldown_seconds = maxf(flow.arrival_cooldown_seconds, interval)
	visit.finished = true
	visit.finished_day = day
	CustomerOutcomeService.publish_change(visit, &"appearance_finished")
	if visit.followup_committed and visit.next_followup_day > day:
		return
	if create_complaint(visit, day):
		visit.next_followup_day = 0
		visit.followup_committed = false
		return

	schedule_followup(visit, day)


## Подаёт жалобу с известным именем постоянного жителя; расчёт остаётся у CustomerOutcomeService.
static func create_complaint(
	visit: CustomerVisit,
	day: int,
	reason: CustomerComplaint.Reason = CustomerComplaint.Reason.NOT_DELIVERED,
	force: bool = false,
) -> bool:
	return CustomerOutcomeService.create_complaint(
		visit, day, reason, force, CustomerPresentation.customer_name(visit),
	)


## Планирует допустимый повтор по детерминированному броску для номера повторного визита.
static func schedule_followup(visit: CustomerVisit, day: int) -> bool:
	if (
		visit == null
		or visit.definition == null
		or visit.customer_dead
		or visit.declaration != CustomerVisit.Declaration.NONE
		or (
			visit.actual != CustomerVisit.Actual.NOT_RESOLVED
			and visit.actual != CustomerVisit.Actual.PLAYER_DENIED
		)
		or visit.followup_count >= visit.definition.max_followup_visits
	):
		return false

	var probability: float = clampf(
		visit.definition.followup_probability + visit.followup_probability_delta,
		0.0,
		1.0,
	)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = String(
		"%s/followup/%d" % [visit.visit_id, visit.followup_count + 1]
	).hash()
	if random.randf() >= probability:
		return false

	visit.followup_count += 1
	visit.next_followup_day = day + maxi(1, visit.definition.followup_delay_days)
	visit.followup_committed = true
	return true


## Запрашивает обычный уход; дерево NPC выбирает момент этого действия.
static func leave_service(customer: E_Customer, visit: CustomerVisit) -> void:
	_leave(customer, visit)


static func _leave(customer: E_Customer, visit: CustomerVisit) -> void:
	NpcDialogueService.end(customer)
	CustomerInspectionService.end(customer)
	CombatService.end_combat(customer)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	_transition(agent, C_CustomerAgent.Phase.LEAVING)
	var station: E_DeliveryCounter = counter()
	var customer_node: Node = customer as Node
	var body: Node3D = customer_node as Node3D
	if station != null:
		NpcIntentService.move_to(customer, station.entry_position(), visit.definition.arrival_distance)
	elif body != null:
		NpcIntentService.move_to(customer, body.global_position, visit.definition.arrival_distance)
	NpcIntentService.look_along_movement(customer)
	if visit.actual == CustomerVisit.Actual.NOT_RESOLVED:
		customer.show_message("Я ухожу без заказа.")


## Requests player-facing attention without owning movement or a recurring phase.
static func watch_player(customer: E_Customer) -> void:
	var awareness: C_NpcAwareness = customer.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null and not awareness.player_visible:
		NpcIntentService.look_along_movement(customer)
		return

	for player: Entity in ECS.world.query.with_all([C_PlayerInputController]).execute():
		var character: E_PhysicalCharacter = player as E_PhysicalCharacter
		var offset: Vector3 = Vector3.ZERO
		if character != null and character.head_axis_x != null:
			var player_body: Node3D = player as Node as Node3D
			offset = character.head_axis_x.global_position - player_body.global_position
		NpcIntentService.watch(customer, player, offset)
		return

	NpcIntentService.look_along_movement(customer)


static func _transition(agent: C_CustomerAgent, phase: C_CustomerAgent.Phase) -> void:
	agent.phase = phase
	agent.elapsed = 0.0


## Вводит фазу диалога или примерки, сохраняя ограничение по терпению.
static func enter_service_phase(customer: E_Customer, phase: C_CustomerAgent.Phase) -> bool:
	if phase != C_CustomerAgent.Phase.DIALOGUE and phase != C_CustomerAgent.Phase.OPTIONAL_FITTING and phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE and agent.phase != C_CustomerAgent.Phase.DIALOGUE and agent.phase != C_CustomerAgent.Phase.OPTIONAL_FITTING:
		return false

	_transition(agent, phase)
	return true

#endregion
