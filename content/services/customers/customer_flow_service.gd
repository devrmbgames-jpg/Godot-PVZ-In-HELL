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
				visit.requires_registered_package = event.requires_registered_package
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


## Only visits that can actually arrive block shift completion. A package-pickup visit
## becomes actionable as soon as its package gets a registration record.
static func actionable_remaining(flow: C_CustomerFlow, day: int) -> int:
	var count: int = 0
	for visit: CustomerVisit in flow.visits:
		if visit.arrival_day > day or visit.finished:
			continue
		if visit.started or arrival_allowed(visit):
			count += 1
	return count


static func arrival_allowed(visit: CustomerVisit) -> bool:
	if visit == null:
		return false
	if not visit.requires_registered_package:
		return true
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	return ledger != null and _has_active_registration_record(ledger, visit.package_id)


static func sync_package_history(flow: C_CustomerFlow) -> void:
	if flow == null:
		return
	for visit: CustomerVisit in flow.visits:
		if not visit.package_history_id.is_empty():
			continue
		var parcel: Entity = parcel_for(visit.package_id)
		if parcel == null:
			continue
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		if identity != null:
			visit.package_history_id = identity.history_id


static func tick(flow: C_CustomerFlow, cycle: C_DayCycle, delta: float) -> void:
	var wallet: C_Wallet = WalletService.current()
	var payment: int = wallet.policy.delivery_payment if wallet != null and wallet.policy != null else 0
	plan_day(flow, cycle.day_index, payment)
	sync_package_history(flow)
	if cycle.phase == C_DayCycle.Phase.MORNING:
		finalize_missed_unregistered(flow, cycle, wallet)
	reactivate_due_followups(flow, cycle.day_index)
	for visit: CustomerVisit in flow.visits:
		_settle_visit(visit, wallet, cycle.day_index)
		CustomerOutcomeService.resolve_complaint(visit, wallet, cycle.day_index)
		if visit.started and not visit.finished and customer_for(visit.visit_id) == null:
			finish(visit, cycle.day_index)
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		_step(customer as E_Customer, cycle, delta)
	cycle.remaining_customer_events = actionable_remaining(flow, cycle.day_index)
	spawn_next_due(flow, cycle)


## Morning audit: a package-pickup visit that was due before today but never became
## eligible because its parcel still lacks registration is closed as Lost without spawning NPC.
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
			not visit.requires_registered_package
			or visit.arrival_day >= cycle.day_index
			or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
			or visit.declaration != CustomerVisit.Declaration.NONE
			or _has_active_registration_record(ledger, visit.package_id)
		):
			continue

		var parcel: Entity = parcel_for(visit.package_id)
		if parcel != null:
			var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
			if state == null or state.registration != C_PackageState.Registration.UNREGISTERED:
				continue
			var identity: C_Package = parcel.get_component(C_Package) as C_Package
			if identity != null and visit.package_history_id.is_empty():
				visit.package_history_id = identity.history_id

		if not CustomerOutcomeService.mark_missed_registration_lost(visit, cycle.day_index):
			continue
		CustomerOutcomeService.settle(visit, wallet, cycle.day_index)
		if parcel != null:
			ECS.world.remove_entity(parcel)
		lost_count += 1
	return lost_count


static func _has_active_registration_record(
	ledger: C_PackageLedger,
	package_id: String,
) -> bool:
	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == package_id and record.active:
			return true
	return false


static func spawn_next_due(flow: C_CustomerFlow, cycle: C_DayCycle) -> bool:
	if flow == null or cycle == null or cycle.phase != C_DayCycle.Phase.DAY:
		return false
	if not ECS.world.query.with_all([C_CustomerAgent]).execute().is_empty():
		return false
	for visit: CustomerVisit in flow.visits:
		if (
			not visit.started
			and visit.arrival_day <= cycle.day_index
			and arrival_allowed(visit)
		):
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
	var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent
	match agent.phase:
		C_CustomerAgent.Phase.APPROACHING:
			if intent != null and intent.arrived:
				_transition(agent, C_CustomerAgent.Phase.WAITING)
				NpcIntentService.stop(customer)
				_watch_player(customer)
				customer.show_message("Здравствуйте!")
				var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
				if ChallengeService.begin_on_arrival(customer, player):
					var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
					customer.show_message(challenge.definition.rule_text)
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
			if (intent != null and intent.arrived) or agent.elapsed >= visit.definition.leaving_seconds:
				ChallengeService.request_departure(customer)
				var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
				if challenge != null and challenge.definition != null:
					# The light evaluator/runtime/receiver run after CustomerFlow.
					# Keep the departing subject alive until they consume the last condition.
					if challenge.phase == C_Challenge.Phase.ACTIVE and challenge.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]:
						return
					if challenge.pending_result != null and not challenge.consequences_applied:
						return
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


## Returns the held Package offered to this Customer. Prefer the requested shipment when
## the Player carries more than one Package across Carry/right/left slots.
static func direct_handoff_package(actor: Entity, customer: E_Customer) -> Entity:
	if not is_instance_valid(actor) or not is_instance_valid(customer):
		return null
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
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


static func confirm_direct_delivery(
	actor: Entity,
	customer: E_Customer,
) -> PackageDeliveryCheck.Result:
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
	if not CustomerOutcomeService.receive(visit, check_result):
		return check_result.result

	if visit.actual == CustomerVisit.Actual.DELIVERED:
		if allow_held:
			GrabService.release(direct_holder, parcel)
		_depart_parcel(parcel)
		ECS.world.remove_entity(parcel)
		customer.show_message(
			"Спасибо!"
			if visit.satisfaction == visit.definition.healthy_satisfaction
			else "Заказ принят, но его состояние меня не устраивает."
		)
	else:
		# Direct refusal keeps the physical Package in the Player's grip; counter
		# refusal leaves the already released Package on the counter.
		customer.show_message("Я отказываюсь от заказа. Коробка остаётся у вас.")

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent != null:
		_transition(agent, C_CustomerAgent.Phase.RECEIVING)
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
	if declaration != CustomerVisit.Declaration.NONE:
		visit.next_followup_day = 0
		visit.followup_committed = false
	_settle_visit(visit, WalletService.current(), cycle.day_index)
	var customer: E_Customer = customer_for(visit_id)
	if customer != null and visit.aggressive:
		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.phase != C_CustomerAgent.Phase.LEAVING:
			# Declaration is accounting only. A false TAKEN may be noticed, but
			# Dialogue still owns the reaction before the bounded Aggressive transition.
			customer.show_message("Вы ничего мне не выдали! Поговорите со мной.")
	return true


## Explicit dialogue postponement. This is not a denial and must guarantee the next visit.
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


static func deny(visit_id: StringName) -> bool:
	var visit: CustomerVisit = find_visit(visit_id)
	if visit == null or not visit.started:
		return false
	if not CustomerOutcomeService.commit_player_denial(visit):
		return false
	var customer: E_Customer = customer_for(visit_id)
	if customer != null:
		if visit.aggressive:
			enter_aggressive(customer)
		else:
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
	if agent.phase == C_CustomerAgent.Phase.AGGRESSIVE:
		return true
	_transition(agent, C_CustomerAgent.Phase.AGGRESSIVE)
	NpcIntentService.stop(customer)
	_watch_player(customer)
	customer.show_message("Вы меня обманули!")
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
	if visit.followup_committed and visit.next_followup_day > day:
		return
	if CustomerOutcomeService.create_complaint(visit, day):
		visit.next_followup_day = 0
		visit.followup_committed = false
		return
	schedule_followup(visit, day)


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


static func reactivate_due_followups(flow: C_CustomerFlow, day: int) -> int:
	if flow == null:
		return 0
	var reactivated: int = 0
	for visit: CustomerVisit in flow.visits:
		if (
			not visit.finished
			or visit.next_followup_day <= 0
			or visit.next_followup_day > day
			or visit.declaration != CustomerVisit.Declaration.NONE
			or visit.complaint != null
			or visit.customer_dead
		):
			continue
		if visit.requires_registered_package and not arrival_allowed(visit):
			continue
		visit.started = false
		visit.finished = false
		visit.finished_day = 0
		visit.next_followup_day = 0
		visit.followup_committed = false
		visit.actual = CustomerVisit.Actual.NOT_RESOLVED
		visit.aggressive = false
		reactivated += 1
	return reactivated


static func _leave(customer: E_Customer, visit: CustomerVisit) -> void:
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


static func _settle_visit(visit: CustomerVisit, wallet: C_Wallet, day: int) -> void:
	if visit.actual == CustomerVisit.Actual.DELIVERED and visit.declaration == CustomerVisit.Declaration.TAKEN:
		var customer: E_Customer = customer_for(visit.visit_id)
		var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge if customer != null else null
		if challenge != null:
			if challenge.phase in [C_Challenge.Phase.ARMED, C_Challenge.Phase.ACTIVE]:
				return
			if challenge.pending_result != null and not challenge.consequences_applied:
				return
	CustomerOutcomeService.settle(visit, wallet, day)


static func _watch_player(customer: E_Customer) -> void:
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


## Bounded entry point for R12 dialogue and optional fitting; timeout remains active.
static func enter_service_phase(customer: E_Customer, phase: C_CustomerAgent.Phase) -> bool:
	if phase != C_CustomerAgent.Phase.DIALOGUE and phase != C_CustomerAgent.Phase.OPTIONAL_FITTING and phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return false
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE and agent.phase != C_CustomerAgent.Phase.DIALOGUE and agent.phase != C_CustomerAgent.Phase.OPTIONAL_FITTING:
		return false
	_transition(agent, phase)
	return true
