extends RefCounted
class_name RefusalQuestService

const DEFINITION: DEF_RefusalQuest = preload("res://content/definitions/gameplay/quests/def_refusal_default.tres")


static func current() -> C_QuestSession:
	var session: Entity = _session()
	return session.get_component(C_QuestSession) as C_QuestSession if session != null else null


## Rebuild only live bindings from durable facts after save/load; never invent missing targets.
static func restore_bindings() -> void:
	var state: C_QuestSession = current()
	if state == null:
		return

	for record: RefusalQuestRecord in state.records:
		if record.state not in [RefusalQuestRecord.State.OFFERED, RefusalQuestRecord.State.ACTIVE]:
			continue

		var already_bound: bool = false
		for existing: Entity in ECS.world.query.with_all([C_QuestBinding]).execute():
			if (existing.get_component(C_QuestBinding) as C_QuestBinding).quest_id == record.quest_id:
				already_bound = true
		if already_bound:
			continue

		var parcel: Entity = CustomerFlowService.parcel_for(record.package_id)
		if parcel == null:
			continue

		for trader: Entity in ECS.world.query.with_all([C_Trader]).execute():
			if (trader.get_component(C_Trader) as C_Trader).trader_key != record.issuer_key:
				continue

			var binding: Entity = Entity.new()
			var identity: C_QuestBinding = C_QuestBinding.new()
			identity.quest_id = record.quest_id
			binding.component_resources = [identity]
			ECS.world.add_entity(binding)
			binding.add_relationship(Relationship.new(R_IssuedBy.new(), trader))
			binding.add_relationship(Relationship.new(R_TargetsPackage.new(), parcel))
			binding.add_relationship(Relationship.new(R_QuestSession.new(), _session()))
			break


static func find(quest_id: StringName) -> RefusalQuestRecord:
	var state: C_QuestSession = current()
	if state != null:
		for record: RefusalQuestRecord in state.records:
			if record.quest_id == quest_id:
				return record
	return null


static func offer(trader: Entity) -> RefusalQuestRecord:
	var cycle: C_DayCycle = DayPhaseService.current()
	var state: C_QuestSession = current()
	var shop: C_Trader = trader.get_component(C_Trader) as C_Trader if EntityAvailability.contains(trader, ECS.world) else null
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.EVENING or state == null or shop == null or ledger == null or flow == null:
		return null

	for record: RefusalQuestRecord in state.records:
		if record.issuer_key == shop.trader_key and record.state in [RefusalQuestRecord.State.OFFERED, RefusalQuestRecord.State.ACTIVE]:
			return record

	for registration: PackageRegistrationRecord in ledger.records:
		if not registration.active:
			continue

		var parcel: Entity = CustomerFlowService.parcel_for(registration.package_id)
		if not EntityAvailability.contains(parcel, ECS.world):
			continue

		for visit: CustomerVisit in flow.visits:
			if visit.package_id != registration.package_id or visit.finished or visit.arrival_day <= cycle.day_index or visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
				continue

			var quest_id: StringName = StringName("refusal/" + visit.package_id)
			if find(quest_id) != null:
				continue

			var record: RefusalQuestRecord = RefusalQuestRecord.new()
			record.quest_id = quest_id
			record.issuer_key = shop.trader_key
			record.package_id = visit.package_id
			record.visit_id = visit.visit_id
			record.display_number = registration.number
			record.offered_day = cycle.day_index
			record.deadline_day = maxi(cycle.day_index + DEFINITION.minimum_deadline_days, visit.arrival_day)
			record.reward = DEFINITION.reward
			state.records.append(record)
			var binding: Entity = Entity.new()
			var identity: C_QuestBinding = C_QuestBinding.new()
			identity.quest_id = record.quest_id
			binding.component_resources = [identity]
			ECS.world.add_entity(binding)
			binding.add_relationship(Relationship.new(R_IssuedBy.new(), trader))
			binding.add_relationship(Relationship.new(R_TargetsPackage.new(), parcel))
			binding.add_relationship(Relationship.new(R_QuestSession.new(), _session()))
			return record
	return null


static func accept(quest_id: StringName) -> bool:
	var record: RefusalQuestRecord = find(quest_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if record == null or cycle == null or cycle.phase != C_DayCycle.Phase.EVENING or cycle.day_index > record.deadline_day or record.state != RefusalQuestRecord.State.OFFERED:
		return false

	record.state = RefusalQuestRecord.State.ACTIVE
	return true


static func ignore(quest_id: StringName) -> bool:
	var record: RefusalQuestRecord = find(quest_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if record == null or cycle == null or cycle.phase != C_DayCycle.Phase.EVENING or record.state != RefusalQuestRecord.State.OFFERED:
		return false

	_resolve(record, RefusalQuestRecord.State.IGNORED, cycle.day_index)
	return true


static func tick(state: C_QuestSession, cycle: C_DayCycle) -> void:
	if state == null or cycle == null:
		return

	for record: RefusalQuestRecord in state.records:
		if record.state in [RefusalQuestRecord.State.OFFERED, RefusalQuestRecord.State.ACTIVE]:
			var visit: CustomerVisit = CustomerFlowService.find_visit(record.visit_id)
			if cycle.day_index > record.deadline_day:
				_resolve(record, RefusalQuestRecord.State.EXPIRED, cycle.day_index)
			elif record.state == RefusalQuestRecord.State.ACTIVE and visit != null and visit.actual == CustomerVisit.Actual.DELIVERED:
				_resolve(record, RefusalQuestRecord.State.FAILED, cycle.day_index)
			elif record.state == RefusalQuestRecord.State.ACTIVE and visit != null and visit.actual == CustomerVisit.Actual.PLAYER_DENIED:
				_resolve(record, RefusalQuestRecord.State.COMPLETED, cycle.day_index)
			elif cycle.day_index == record.deadline_day and cycle.phase == C_DayCycle.Phase.NIGHT:
				_resolve(record, RefusalQuestRecord.State.EXPIRED, cycle.day_index)
		if record.state == RefusalQuestRecord.State.COMPLETED and not record.reward_paid:
			_pay_reward(record, cycle.day_index)


static func _resolve(record: RefusalQuestRecord, outcome: RefusalQuestRecord.State, day_index: int) -> void:
	record.state = outcome
	record.resolved_day = day_index
	var bindings: Array[Entity] = ECS.world.query.with_all([C_QuestBinding]).execute().duplicate()
	for binding: Entity in bindings:
		if (binding.get_component(C_QuestBinding) as C_QuestBinding).quest_id == record.quest_id:
			ECS.world.remove_entity(binding)


static func _pay_reward(record: RefusalQuestRecord, day_index: int) -> void:
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = StringName("quest_reward/" + String(record.quest_id))
	operation.reason = MoneyOperation.Reason.PAYMENT
	operation.amount = record.reward
	operation.day_index = day_index
	var status: WalletService.Status = WalletService.submit(operation)
	record.reward_paid = status in [WalletService.Status.COMMITTED, WalletService.Status.DUPLICATE]


static func _session() -> Entity:
	return ECS.world.query.with_all([C_QuestSession, C_DayCycle]).execute_one() if is_instance_valid(ECS.world) else null
