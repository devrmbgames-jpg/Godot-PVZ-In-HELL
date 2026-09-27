extends RefCounted
## Read-only developer-console projections over authoritative runtime state.
class_name DeveloperConsoleDiagnostics

const RECENT_MONEY_OPERATIONS: int = 5


static func package_list(include_inactive: bool) -> PackedStringArray:
	var lines: PackedStringArray = []
	var seen: Dictionary[String, bool] = { }
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records:
			if not include_inactive and not record.active:
				continue
			var live: Entity = _package_entity(record.package_id)
			lines.append(_package_list_line(record.package_id, record, live))
			seen[record.package_id] = true

	if is_instance_valid(ECS.world):
		for entity: Entity in ECS.world.query.with_all([C_Package]).execute():
			var identity: C_Package = entity.get_component(C_Package) as C_Package
			if identity == null or seen.has(identity.package_id):
				continue
			lines.append(_package_list_line(identity.package_id, null, entity))

	if lines.is_empty():
		lines.append("no packages")
	return lines


static func package_info(target: DebugTarget) -> PackedStringArray:
	var lines: PackedStringArray = [
		"package_id=%s" % target.package_id,
		"live=%s" % str(EntityAvailability.contains(target.entity, ECS.world)),
	]
	var definition: DEF_Package = _package_definition(target)
	if definition != null:
		lines.append("definition=%s" % String(definition.key))
		lines.append("description=%s" % definition.description)
		lines.append("accounting_value=%d" % definition.accounting_value)

	if target.registration != null:
		lines.append("number=#%03d" % target.registration.number)
		lines.append("registration_active=%s" % str(target.registration.active))
	else:
		lines.append("number=unregistered")

	if EntityAvailability.contains(target.entity, ECS.world):
		var state: C_PackageState = target.entity.get_component(C_PackageState) as C_PackageState
		var health: C_Health = target.entity.get_component(C_Health) as C_Health
		if health != null:
			lines.append("hp=%.1f/%.1f" % [health.get_hp_current(), health.get_hp_max()])
			lines.append("depleted=%s" % str(health.depleted))
		if state != null:
			lines.append("registration=%s" % _enum_name(C_PackageState.Registration, state.registration))
			lines.append("scan=%s" % _enum_name(C_PackageState.Scan, state.scan))
			lines.append("opening=%s" % _enum_name(C_PackageState.Opening, state.opening))
			lines.append("damage=%s" % _enum_name(C_PackageState.Damage, state.damage))
			lines.append("leaking=%s" % str(state.leaking))

	if target.visit != null:
		lines.append_array(visit_info(target.visit))
	else:
		lines.append("visit=none")
	return lines


static func visit_info(visit: CustomerVisit) -> PackedStringArray:
	var lines: PackedStringArray = [
		"visit=%s" % String(visit.visit_id),
		"customer=%s" % String(visit.customer_id),
		"package_id=%s" % visit.package_id,
		"actual=%s" % _enum_name(CustomerVisit.Actual, visit.actual),
		"declaration=%s" % _enum_name(CustomerVisit.Declaration, visit.declaration),
		"disposition=%s" % _enum_name(CustomerVisit.Disposition, visit.disposition),
		"reputation=%s" % _enum_name(CustomerVisit.Reputation, visit.reputation),
		"satisfaction=%d" % visit.satisfaction,
		"started=%s" % str(visit.started),
		"finished=%s" % str(visit.finished),
		"settlement_committed=%s" % str(visit.settlement_committed),
		"money_delta=%d" % visit.money_delta,
	]
	if visit.complaint == null:
		lines.append("complaint=none")
	else:
		lines.append("complaint=%s" % String(visit.complaint.complaint_id))
		lines.append(
			"complaint_outcome=%s"
			% _enum_name(CustomerComplaint.Outcome, visit.complaint.outcome)
		)
		lines.append("complaint_resolve_day=%d" % visit.complaint.resolve_day)
	return lines


static func wallet_info() -> PackedStringArray:
	var wallet: C_Wallet = WalletService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if wallet == null:
		return PackedStringArray(["wallet=unavailable"])

	var lines: PackedStringArray = [
		"balance=%d" % wallet.balance,
		"penalties=%d" % wallet.penalties,
		"completed_days=%d" % wallet.completed_days,
	]
	if cycle != null:
		lines.append("day=%d" % cycle.day_index)
		var daily: DailyMoneyResult = _daily_result(wallet, cycle.day_index)
		if daily != null:
			lines.append("today_income=%d" % daily.income)
			lines.append("today_spending=%d" % daily.spending)
			lines.append("today_penalties=%d" % daily.penalties)
			lines.append("today_closing_balance=%d" % daily.closing_balance)

	var start: int = maxi(0, wallet.operations.size() - RECENT_MONEY_OPERATIONS)
	for index: int in range(start, wallet.operations.size()):
		var operation: MoneyOperation = wallet.operations[index]
		lines.append(
			"op[%d]=%s amount=%d id=%s"
			% [
				index,
				_enum_name(MoneyOperation.Reason, operation.reason),
				operation.amount,
				String(operation.operation_id),
			]
		)
	return lines


static func health_info(target: DebugTarget) -> PackedStringArray:
	if not EntityAvailability.contains(target.entity, ECS.world):
		return PackedStringArray(["live=false"])
	var entity: Entity = target.entity
	var health: C_Health = entity.get_component(C_Health) as C_Health
	if health == null:
		return PackedStringArray([
			"entity=%s" % entity.id,
			"health=none",
		])

	var lines: PackedStringArray = [
		"entity=%s" % entity.id,
		"hp=%.1f/%.1f" % [health.get_hp_current(), health.get_hp_max()],
		"depleted=%s" % str(health.depleted),
		"living=%s" % str(entity.has_component(C_Living)),
		"dead=%s" % str(entity.has_component(C_Death)),
		"player=%s" % str(entity.has_component(C_PlayerInputController)),
	]
	if entity.has_component(C_PackageState):
		var state: C_PackageState = entity.get_component(C_PackageState) as C_PackageState
		lines.append("package_damage=%s" % _enum_name(C_PackageState.Damage, state.damage))
	return lines


static func _package_list_line(
	package_id: String,
	record: PackageRegistrationRecord,
	entity: Entity,
) -> String:
	var number_text: String = "#%03d" % record.number if record != null else "---"
	var active_text: String = "ACTIVE" if record != null and record.active else "UNREGISTERED"
	var live_text: String = "LIVE" if EntityAvailability.contains(entity, ECS.world) else "MISSING"
	var definition: DEF_Package = null
	if EntityAvailability.contains(entity, ECS.world):
		var identity: C_Package = entity.get_component(C_Package) as C_Package
		definition = identity.definition if identity != null else null
	if definition == null and record != null:
		definition = record.definition
	var definition_key: String = String(definition.key) if definition != null else "unknown"
	var condition: String = "NO_STATE"
	if EntityAvailability.contains(entity, ECS.world):
		var state: C_PackageState = entity.get_component(C_PackageState) as C_PackageState
		if state != null:
			condition = _enum_name(C_PackageState.Damage, state.damage)
	return "%s | %s | %s | %s | %s | %s" % [
		number_text,
		definition_key,
		package_id,
		live_text,
		active_text,
		condition,
	]


static func _package_definition(target: DebugTarget) -> DEF_Package:
	if EntityAvailability.contains(target.entity, ECS.world):
		var identity: C_Package = target.entity.get_component(C_Package) as C_Package
		if identity != null and identity.definition != null:
			return identity.definition
	if target.registration != null:
		return target.registration.definition
	return null


static func _package_entity(package_id: String) -> Entity:
	if not is_instance_valid(ECS.world):
		return null
	for entity: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = entity.get_component(C_Package) as C_Package
		if identity != null and identity.package_id == package_id:
			return entity
	return null


static func _daily_result(wallet: C_Wallet, day_index: int) -> DailyMoneyResult:
	for daily: DailyMoneyResult in wallet.daily_results:
		if daily.day_index == day_index:
			return daily
	return null


static func _enum_name(values: Dictionary, value: int) -> String:
	var keys: Array = values.keys()
	if value < 0 or value >= keys.size():
		return "UNKNOWN(%d)" % value
	return String(keys[value])
