extends RefCounted
## Live scheduling/assignment boundary. Invoked outside query iteration via command buffer.
class_name CustomerFlowService


static func current() -> C_CustomerFlow:
	if not is_instance_valid(ECS.world):
		return null
	var owner: Entity = ECS.world.query.with_all([C_CustomerFlow]).execute_one()
	return owner.get_component(C_CustomerFlow) as C_CustomerFlow if owner != null else null


static func find_visit(id: StringName) -> CustomerVisit:
	var flow: C_CustomerFlow = current()
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			if visit.visit_id == id:
				return visit
	return null


static func counter() -> E_DeliveryCounter:
	return ECS.world.query.with_all([C_DeliveryCounter]).execute_one() as E_DeliveryCounter


static func parcel_for(package_id: String) -> Entity:
	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		if identity.package_id == package_id:
			return parcel
	return null


static func customer_for(visit_id: StringName) -> E_Customer:
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.visit_id == visit_id:
			return customer as E_Customer
	return null


static func waiting_customer() -> E_Customer:
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
			return customer as E_Customer
	return null


static func plan_day(flow: C_CustomerFlow, day: int, payment: int) -> void:
	var schedule: DEF_CustomerSchedule = flow.schedule
	if schedule == null or schedule.supply == null:
		return
	while flow.planned_through_day < day:
		flow.planned_through_day += 1
		var supply_day: int = flow.planned_through_day
		for event: DEF_CustomerEvent in schedule.events:
			if event.arrival_delay_days < 0 or event.customer == null:
				continue
			for definition: DEF_Package in schedule.supply.packages:
				if definition.key != event.package_key:
					continue
				var package_id: String = "%s:%d:%s" % [schedule.supply.key, supply_day, definition.key]
				var visit_id: StringName = StringName("visit/" + package_id)
				var already_planned: bool = false
				for existing: CustomerVisit in flow.visits:
					if existing.visit_id == visit_id:
						already_planned = true
				if already_planned:
					continue
				var visit: CustomerVisit = CustomerVisit.new()
				visit.visit_id = visit_id
				visit.package_id = package_id
				visit.customer_id = StringName("%s:%d" % [definition.recipient_id, supply_day])
				visit.definition = event.customer
				visit.arrival_day = supply_day + event.arrival_delay_days
				visit.accounting_value = definition.accounting_value
				visit.payment = payment
				var random: RandomNumberGenerator = RandomNumberGenerator.new()
				random.seed = String(visit_id).hash()
				visit.complaint_roll = random.randf()
				visit.aggression_roll = random.randf()
				flow.visits.append(visit)


static func remaining(flow: C_CustomerFlow, day: int) -> int:
	var count: int = 0
	for visit: CustomerVisit in flow.visits:
		if visit.arrival_day <= day and not visit.finished:
			count += 1
	return count


static func tick(flow: C_CustomerFlow, cycle: C_DayCycle, delta: float) -> void:
	var wallet: C_Wallet = WalletService.current()
	var payment: int = wallet.policy.delivery_payment if wallet != null and wallet.policy != null else 0
	plan_day(flow, cycle.day_index, payment)
	if cycle.phase == C_DayCycle.Phase.MORNING:
		finalize_missed_unregistered(flow, cycle, wallet)
	for visit: CustomerVisit in flow.visits:
		CustomerOutcomeService.settle(visit, wallet, cycle.day_index)
		CustomerOutcomeService.resolve_complaint(visit, wallet, cycle.day_index)
		if visit.started and not visit.finished and customer_for(visit.visit_id) == null:
			finish(visit, cycle.day_index)
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		_step(customer as E_Customer, cycle, delta)
	cycle.remaining_customer_events = remaining(flow, cycle.day_index)
	spawn_next_due(flow, cycle)


## Bounded domain entry point used by the normal tick and developer tooling.
## Returns true only when a due visit was actually started.
## Morning audit: a customer already came and left, but their package still has no
## registration record. The warehouse treats it as lost before the next shift.
static func finalize_missed_unregistered(
	flow: C_CustomerFlow,
	cycle: C_DayCycle,
	wallet: C_Wallet,
) -> int:
	if (
		flow == null
		or cycle == null
		or cycle.phase != C_DayCycle.Phase.MORNING
		or cycle.day_index <= 1
	):
		return 0
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger == null:
		return 0

	var lost_count: int = 0
	for visit: CustomerVisit in flow.visits:
		if (
			not visit.started
			or not visit.finished
			or visit.finished_day >= cycle.day_index
			or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
			or visit.declaration != CustomerVisit.Declaration.NONE
		):
			continue
		if _has_registration_record(ledger, visit.package_id):
			continue

		var parcel: Entity = parcel_for(visit.package_id)
		if parcel != null:
			var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
			if state == null or state.registration != C_PackageState.Registration.UNREGISTERED:
				continue
			var identity: C_Package = parcel.get_component(C_Package) as C_Package
			if identity != null and visit.package_history_id.is_empty():
				visit.package_history_id = identity.history_id

		if not CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.LOST):
			continue
		visit.disposition = CustomerVisit.Disposition.LOST
		CustomerOutcomeService.settle(visit, wallet, cycle.day_index)
		if parcel != null:
			ECS.world.remove_entity(parcel)
		lost_count += 1
	return lost_count


static func _has_registration_record(ledger: C_PackageLedger, package_id: String) -> bool:
	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == package_id:
			return true
	return false


static func spawn_next_due(flow: C_CustomerFlow, cycle: C_DayCycle) -> bool:
	if flow == null or cycle == null or cycle.phase != C_DayCycle.Phase.DAY:
		return false
	if not ECS.world.query.with_all([C_CustomerAgent]).execute().is_empty():
		return false
	for visit: CustomerVisit in flow.visits:
		if not visit.started and visit.arrival_day <= cycle.day_index:
			_spawn(flow, visit, cycle.day_index)
			return true
	return false


static func _spawn(flow: C_CustomerFlow, visit: CustomerVisit, day: int) -> void:
	var station: E_DeliveryCounter = counter()
	if station == null or flow.schedule.customer_scene == null:
		visit.started = true
		finish(visit, day)
		return
	var customer: E_Customer = flow.schedule.customer_scene.instantiate() as E_Customer
	if customer == null:
		visit.started = true
		finish(visit, day)
		return
	station.get_parent().add_child(customer)
	(customer as Node as Node3D).global_position = station.entry_position()
	ECS.world.add_entity(customer, null, false)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = visit.visit_id
	agent.destination = station.waiting_position()
	agent.moving = true
	visit.started = true
	bind_parcel(customer, visit)
	customer.show_message(visit.definition.display_name)


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


static func assigned(parcel: Entity, customer: Entity, visit: CustomerVisit) -> bool:
	for relation: Relationship in parcel.relationships:
		if relation.relation is R_AssignedTo and relation.target == customer:
			return (relation.relation as R_AssignedTo).visit_id == visit.visit_id
	return false


static func _step(customer: E_Customer, cycle: C_DayCycle, delta: float) -> void:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = find_visit(agent.visit_id)
	if visit == null:
		ECS.world.remove_entity(customer)
		return
	var death: C_Death = customer.get_component(C_Death) as C_Death
	if death != null:
		visit.customer_dead = true
		if death.cause != null and death.cause.request != null:
			var actor: Entity = death.cause.request.instigator
			if not is_instance_valid(actor):
				actor = death.cause.request.source
			visit.defeated_by_player = is_instance_valid(actor) and actor.has_component(C_PlayerInputController)
		finish(visit, cycle.day_index)
		ECS.world.remove_entity(customer)
		return
	bind_parcel(customer, visit)
	agent.elapsed += delta
	match agent.phase:
		C_CustomerAgent.Phase.APPROACHING:
			if agent.arrived:
				_transition(agent, C_CustomerAgent.Phase.WAITING)
				agent.moving = false
				customer.show_message("Здравствуйте!")
			elif agent.elapsed >= visit.definition.approach_timeout:
				_leave(customer, visit)
		C_CustomerAgent.Phase.WAITING:
			if agent.elapsed >= visit.definition.greeting_seconds:
				greet(customer)
		C_CustomerAgent.Phase.WAITING_FOR_PACKAGE, C_CustomerAgent.Phase.DIALOGUE, C_CustomerAgent.Phase.OPTIONAL_FITTING:
			if agent.elapsed >= visit.definition.patience_seconds:
				_leave(customer, visit)
		C_CustomerAgent.Phase.RECEIVING:
			if agent.elapsed >= visit.definition.receiving_seconds:
				_leave(customer, visit)
		C_CustomerAgent.Phase.AGGRESSIVE:
			if agent.elapsed >= visit.definition.aggressive_seconds:
				_leave(customer, visit)
		C_CustomerAgent.Phase.LEAVING:
			if agent.arrived or agent.elapsed >= visit.definition.leaving_seconds:
				_transition(agent, C_CustomerAgent.Phase.FINISHED)
				finish(visit, cycle.day_index)
				ECS.world.remove_entity(customer)


static func greet(customer: E_Customer) -> void:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or find_visit(agent.visit_id) == null:
		return
	if agent.phase != C_CustomerAgent.Phase.WAITING and agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return
	_transition(agent, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	customer.show_message("Здравствуйте. Поговорите со мной, чтобы узнать номер заказа.")


static func confirm_delivery(station: E_DeliveryCounter) -> PackageDeliveryCheck.Result:
	var customer: E_Customer = waiting_customer()
	if customer == null:
		return PackageDeliveryCheck.Result.MISSING
	var parcels: Array[Entity] = station.parcels()
	if parcels.size() != 1:
		var result: PackageDeliveryCheck.Result = PackageDeliveryCheck.Result.MISSING if parcels.is_empty() else PackageDeliveryCheck.Result.MULTIPLE
		station.show_message(CustomerPresentation.check_text(result))
		return result
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = find_visit(agent.visit_id)
	var parcel: Entity = parcels[0]
	var check_result: PackageDeliveryCheck = CustomerOutcomeService.check(visit, parcel.get_component(C_Package) as C_Package, parcel.get_component(C_PackageState) as C_PackageState, assigned(parcel, customer, visit), GrabService.held_relationship(parcel) != null)
	if not CustomerOutcomeService.receive(visit, check_result):
		station.show_message(CustomerPresentation.check_text(check_result.result))
		return check_result.result
	if visit.actual == CustomerVisit.Actual.DELIVERED:
		_depart_parcel(parcel)
		ECS.world.remove_entity(parcel)
		customer.show_message("Спасибо!" if visit.satisfaction == visit.definition.healthy_satisfaction else "Заказ принят, но его состояние меня не устраивает.")
	else:
		customer.show_message("Я отказываюсь от заказа. Коробка остаётся у вас.")
	_transition(agent, C_CustomerAgent.Phase.RECEIVING)
	station.show_message("Выдача обработана. Отметьте исход в терминале.")
	return check_result.result


static func declare(visit_id: StringName, declaration: CustomerVisit.Declaration) -> bool:
	var visit: CustomerVisit = find_visit(visit_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return false
	if visit.declaration == declaration and declaration != CustomerVisit.Declaration.NONE:
		return true
	if not CustomerOutcomeService.declare(visit, declaration):
		return false
	CustomerOutcomeService.settle(visit, WalletService.current(), cycle.day_index)
	var customer: E_Customer = customer_for(visit_id)
	if customer != null:
		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if visit.aggressive and agent.phase != C_CustomerAgent.Phase.LEAVING:
			# R11 decides the aggression fact. R12 owns the dialogue reaction and
			# invokes enter_aggressive() after the complaint line has been resolved.
			customer.show_message("Вы ничего мне не выдали! Поговорите со мной.")
		elif agent.phase != C_CustomerAgent.Phase.LEAVING:
			_leave(customer, visit)
	return true


static func deny(visit_id: StringName) -> bool:
	var visit: CustomerVisit = find_visit(visit_id)
	if visit == null or not visit.started or visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
		return false
	visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	visit.reputation = CustomerVisit.Reputation.PLAYER_DENIAL
	var customer: E_Customer = customer_for(visit_id)
	if customer != null:
		_leave(customer, visit)
	return true


## Dialogue-owned choice only requests the domain transition; CustomerVisit remains authority.
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
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or visit.finished
	):
		return false
	if agent.phase != C_CustomerAgent.Phase.DIALOGUE and agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return false
	visit.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
	visit.satisfaction = 0
	_leave(customer, visit)
	return true


## R12 receiver for a previously decided aggression fact; it does not decide aggression.
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
	_transition(agent, C_CustomerAgent.Phase.AGGRESSIVE)
	agent.moving = false
	customer.show_message("Вы меня обманули!")
	return true


static func dispose_refusal(visit_id: StringName, buyout: bool) -> bool:
	var visit: CustomerVisit = find_visit(visit_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or cycle == null or visit.actual != CustomerVisit.Actual.CUSTOMER_REFUSED:
		return false
	if visit.disposition != CustomerVisit.Disposition.WAREHOUSE:
		return false
	var parcel: Entity = parcel_for(visit.package_id)
	if parcel == null or GrabService.held_relationship(parcel) != null:
		return false
	if buyout:
		var wallet: C_Wallet = WalletService.current()
		var operation: MoneyOperation = WalletService.package_settlement(wallet, StringName("buyout/" + String(visit.visit_id)), MoneyOperation.Reason.VOLUNTARY_BUYOUT, visit.accounting_value, cycle.day_index)
		var result: WalletService.Status = WalletService.submit(operation)
		if result != WalletService.Status.COMMITTED and result != WalletService.Status.DUPLICATE:
			return false
		visit.money_delta -= operation.amount
		visit.disposition = CustomerVisit.Disposition.BOUGHT_OUT
	else:
		if cycle.phase != C_DayCycle.Phase.MORNING or not visit.finished or cycle.day_index <= visit.finished_day:
			return false
		var station: E_DeliveryCounter = counter()
		if station == null or not station.parcels().has(parcel):
			return false
		visit.disposition = CustomerVisit.Disposition.RETURNED
	_depart_parcel(parcel, C_PackageState.Registration.BOUGHT_OUT if buyout else C_PackageState.Registration.RETURNED)
	if not buyout:
		ECS.world.remove_entity(parcel)
	return true


static func _depart_parcel(parcel: Entity, departure: C_PackageState.Registration = C_PackageState.Registration.DELIVERED) -> void:
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	state.registration = departure
	PackageRegistrationService.release_number(parcel)
	for relation: Relationship in parcel.relationships.duplicate():
		if relation.relation is R_AssignedTo:
			parcel.remove_relationship(relation)


static func finish(visit: CustomerVisit, day: int) -> void:
	if visit.finished:
		return
	visit.finished = true
	visit.finished_day = day
	CustomerOutcomeService.create_complaint(visit, day)


static func _leave(customer: E_Customer, visit: CustomerVisit) -> void:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	_transition(agent, C_CustomerAgent.Phase.LEAVING)
	var station: E_DeliveryCounter = counter()
	agent.destination = station.entry_position() if station != null else (customer as Node as Node3D).global_position
	agent.arrived = false
	agent.moving = true
	if visit.actual == CustomerVisit.Actual.NOT_RESOLVED:
		customer.show_message("Я ухожу без заказа.")


static func _transition(agent: C_CustomerAgent, phase: C_CustomerAgent.Phase) -> void:
	agent.phase = phase
	agent.elapsed = 0.0


## Bounded entry point for R12 dialogue and optional fitting; timeout remains active.
static func enter_service_phase(customer: E_Customer, phase: C_CustomerAgent.Phase) -> bool:
	if phase != C_CustomerAgent.Phase.DIALOGUE and phase != C_CustomerAgent.Phase.OPTIONAL_FITTING and phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return false
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE and agent.phase != C_CustomerAgent.Phase.DIALOGUE and agent.phase != C_CustomerAgent.Phase.OPTIONAL_FITTING:
		return false
	_transition(agent, phase)
	return true
