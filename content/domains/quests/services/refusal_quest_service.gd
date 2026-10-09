extends RefCounted
## Explicit offer/choice/outcome/reward transactions; S_RefusalQuest owns scheduled deadline selection.
class_name RefusalQuestService



#region Записи и восстановление связей
## Возвращает журнал заданий текущей сессии.
static func current() -> C_QuestSession:
	var session: Entity = _session()
	return session.get_component(C_QuestSession) as C_QuestSession if session != null else null


## Восстанавливает только живые связи из постоянных фактов; отсутствующие посылки не создаёт.
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

		var parcel: Entity = PackageQueries.find_live_package(record.package_id)
		if parcel == null:
			continue

		for trader: Entity in ECS.world.query.with_all([C_Trader]).execute():
			if (trader.get_component(C_Trader) as C_Trader).trader_key != record.issuer_key:
				continue

			if not _create_binding(record, trader, parcel):
				return
			break


static func _create_binding(record: RefusalQuestRecord, trader: Entity, parcel: Entity) -> bool:
	var binding: Entity = Entity.new()
	var identity: C_QuestBinding = C_QuestBinding.new()
	identity.quest_id = record.quest_id
	binding.component_resources = [identity]
	var context: EntitySpawnContext = EntityCompositionService.context_for(binding, ECS.world,
		GECSIO.uuid())
	context.bindings[&"issuer"] = trader
	context.bindings[&"package"] = parcel
	context.bindings[&"session"] = _session()
	var issuer_intent: EntityInitialBinding = EntityInitialBinding.new()
	issuer_intent.relation = R_IssuedBy.new()
	issuer_intent.endpoint = &"issuer"
	var package_intent: EntityInitialBinding = EntityInitialBinding.new()
	package_intent.relation = R_TargetsPackage.new()
	package_intent.endpoint = &"package"
	var session_intent: EntityInitialBinding = EntityInitialBinding.new()
	session_intent.relation = R_QuestSession.new()
	session_intent.endpoint = &"session"
	context.initial_bindings = [issuer_intent, package_intent, session_intent]
	if not EntityCompositionService.try_register(context):
		binding.free()
		return false
	return true


## Находит постоянную запись по устойчивому ID.
static func find(quest_id: StringName) -> RefusalQuestRecord:
	var state: C_QuestSession = current()
	if state != null:
		for record: RefusalQuestRecord in state.records:
			if record.quest_id == quest_id:
				return record
	return null


#endregion

#region Предложение и выбор игрока
## Вечером возвращает действующее предложение или создаёт задание для зарегистрированной будущей посылки.
static func offer(trader: Entity) -> RefusalQuestRecord:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var state: C_QuestSession = current()
	var shop: C_Trader = trader.get_component(C_Trader) as C_Trader if EntityAvailability.contains(trader, ECS.world) else null
	var ledger: C_PackageLedger = PackageQueries.ledger()
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.EVENING or state == null or shop == null or ledger == null or flow == null:
		return null

	var definition: DEF_RefusalQuest = shop.profile.refusal_quest if shop.profile != null else null
	if definition == null or not RefusalQuestValidator.issuer_issues(shop).is_empty():
		return null

	for record: RefusalQuestRecord in state.records:
		if record.issuer_key == shop.trader_key and record.state in [RefusalQuestRecord.State.OFFERED, RefusalQuestRecord.State.ACTIVE]:
			BoundaryTrace.record(&"quests.offer", record.quest_id,
				BoundaryTraceEntry.Stage.DUPLICATE, &"already_offered",
				String(record.issuer_key), String(record.quest_id))
			return record

	for registration: PackageRegistrationRecord in ledger.records:
		if not registration.active:
			continue

		var parcel: Entity = PackageQueries.find_live_package(registration.package_id)
		if not EntityAvailability.contains(parcel, ECS.world):
			continue

		for visit: CustomerVisit in flow.visits:
			if visit.package_id != registration.package_id or visit.finished or visit.arrival_day <= cycle.day_index or visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
				continue

			var target_identity: C_Package = parcel.get_component(C_Package) as C_Package
			if not RefusalQuestValidator.target_issues(visit, registration, target_identity).is_empty():
				continue

			var quest_id: StringName = StringName("refusal/" + visit.package_id)
			if find(quest_id) != null:
				continue

			var record: RefusalQuestRecord = RefusalQuestRecord.new()
			record.definition = definition
			record.quest_id = quest_id
			record.issuer_key = shop.trader_key
			record.package_id = visit.package_id
			record.visit_id = visit.visit_id
			record.display_number = registration.number
			record.offered_day = cycle.day_index
			record.deadline_day = maxi(cycle.day_index + definition.minimum_deadline_days, visit.arrival_day)
			record.reward = definition.reward
			if not _create_binding(record, trader, parcel):
				return null
			state.records.append(record)

			BoundaryTrace.record(&"quests.offer", record.quest_id,
				BoundaryTraceEntry.Stage.COMPLETED, &"offered",
				String(record.issuer_key), String(record.quest_id))
			return record
	return null


## Вечером принимает ещё открытое предложение до истечения срока.
static func accept(quest_id: StringName) -> bool:
	var record: RefusalQuestRecord = find(quest_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if record == null or cycle == null or cycle.phase != C_DayCycle.Phase.EVENING or cycle.day_index > record.deadline_day or record.state != RefusalQuestRecord.State.OFFERED:
		return _trace_choice(quest_id, &"quests.accept", false)

	record.state = RefusalQuestRecord.State.ACTIVE
	return _trace_choice(quest_id, &"quests.accept", true)


## Вечером разрешает открытое предложение отказом и снимает живые связи.
static func ignore(quest_id: StringName) -> bool:
	var record: RefusalQuestRecord = find(quest_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if record == null or cycle == null or cycle.phase != C_DayCycle.Phase.EVENING or record.state != RefusalQuestRecord.State.OFFERED:
		return _trace_choice(quest_id, &"quests.ignore", false)

	resolve(record, RefusalQuestRecord.State.IGNORED, cycle.day_index)
	return _trace_choice(quest_id, &"quests.ignore", true)


#endregion

#region Исходы, очистка и награда
## Commits one quest outcome and removes its live bindings before reporting completion.
static func resolve(record: RefusalQuestRecord, outcome: RefusalQuestRecord.State, day_index: int) -> void:
	if find(record.quest_id) != record or record.state not in [RefusalQuestRecord.State.OFFERED, RefusalQuestRecord.State.ACTIVE]:
		return
	if outcome not in [RefusalQuestRecord.State.COMPLETED, RefusalQuestRecord.State.FAILED, RefusalQuestRecord.State.IGNORED, RefusalQuestRecord.State.EXPIRED]:
		return
	if outcome in [RefusalQuestRecord.State.COMPLETED, RefusalQuestRecord.State.FAILED] and record.state != RefusalQuestRecord.State.ACTIVE:
		return

	record.state = outcome
	record.resolved_day = day_index
	var bindings: Array[Entity] = ECS.world.query.with_all([C_QuestBinding]).execute().duplicate()
	for binding: Entity in bindings:
		if (binding.get_component(C_QuestBinding) as C_QuestBinding).quest_id == record.quest_id:
			ECS.world.remove_entity(binding)

	BoundaryTrace.record(&"quests.resolve", record.quest_id, BoundaryTraceEntry.Stage.COMPLETED,
		StringName(String(RefusalQuestRecord.State.keys()[outcome]).to_lower()),
		String(record.issuer_key), String(record.quest_id))


## Submits one idempotent wallet operation; reward_paid follows the actual receipt.
static func pay_reward(record: RefusalQuestRecord, day_index: int) -> void:
	if find(record.quest_id) != record or record.state != RefusalQuestRecord.State.COMPLETED or record.reward_paid:
		return

	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = StringName("quest_reward/" + String(record.quest_id))
	operation.reason = MoneyOperation.Reason.PAYMENT
	operation.amount = record.reward
	operation.day_index = day_index
	var status: WalletService.Status = WalletService.submit(operation)
	record.reward_paid = status in [WalletService.Status.COMMITTED, WalletService.Status.DUPLICATE]

	var trace_stage: BoundaryTraceEntry.Stage = BoundaryTraceEntry.Stage.REJECTED
	if status == WalletService.Status.COMMITTED:
		trace_stage = BoundaryTraceEntry.Stage.COMPLETED
	elif status == WalletService.Status.DUPLICATE:
		trace_stage = BoundaryTraceEntry.Stage.DUPLICATE
	BoundaryTrace.record(&"quests.reward", operation.operation_id, trace_stage,
		StringName(String(WalletService.Status.keys()[status]).to_lower()),
		String(record.issuer_key), String(record.quest_id))


static func _session() -> Entity:
	return ECS.world.query.with_all([C_QuestSession, C_DayCycle]).execute_one() if is_instance_valid(ECS.world) else null

#endregion

#region Boundary diagnostics
static func _trace_choice(quest_id: StringName, operation: StringName, committed: bool) -> bool:
	var record: RefusalQuestRecord = find(quest_id)
	var trace_stage: BoundaryTraceEntry.Stage = (
		BoundaryTraceEntry.Stage.COMPLETED if committed else BoundaryTraceEntry.Stage.REJECTED
	)
	var origin_id: String = String(record.issuer_key) if record != null else ""
	BoundaryTrace.record(operation, quest_id, trace_stage,
		&"committed" if committed else &"invalid_choice", origin_id, String(quest_id))
	return committed
#endregion
