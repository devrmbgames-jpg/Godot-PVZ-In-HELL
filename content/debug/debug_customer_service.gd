extends RefCounted
## Test-only adapters for persistent CustomerVisit facts; no presentation authority.
class_name DebugCustomerService

const DEFAULT_CUSTOMER_KEY: String = "default"


static func create_visit(
	target: DebugTarget,
	customer_key: String,
	arrive: bool = false,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if target.kind != DebugTarget.Kind.PACKAGE:
		result.message = target.error if not target.error.is_empty() else "target is not a package"
		return result
	if target.visit != null:
		result.success = true
		result.message = "existing visit"
		result.details.append("visit=%s" % String(target.visit.visit_id))
		return result

	var flow: C_CustomerFlow = CustomerFlowService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	var wallet: C_Wallet = WalletService.current()
	var definition: DEF_Package = _package_definition(target)
	if flow == null or flow.schedule == null or cycle == null or definition == null:
		result.message = "customer flow/day/package definition is unavailable"
		return result

	var policy: DEF_Customer = _customer_policy(flow.schedule, definition, customer_key)
	if policy == null:
		result.message = "customer definition was not found: %s" % customer_key
		return result

	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = StringName("visit/" + target.package_id)
	visit.package_id = target.package_id
	visit.customer_id = StringName(
		"debug:%s:%d" % [String(definition.recipient_id), cycle.day_index]
	)
	visit.definition = policy
	visit.arrival_day = cycle.day_index
	visit.accounting_value = definition.accounting_value
	visit.payment = (
		wallet.policy.delivery_payment
		if wallet != null and wallet.policy != null
		else 0
	)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = String(visit.visit_id).hash()
	visit.complaint_roll = random.randf()
	visit.aggression_roll = random.randf()
	visit.started = not arrive
	visit.finished = not arrive
	visit.finished_day = cycle.day_index if not arrive else 0
	flow.visits.append(visit)

	result.success = true
	result.message = "queued live visit" if arrive else "created accounting visit"
	result.details.append("visit=%s" % String(visit.visit_id))
	result.details.append("customer=%s" % String(policy.key))
	return result


static func set_actual(
	target: DebugTarget,
	actual: CustomerVisit.Actual,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	var visit: CustomerVisit = target.visit
	if visit == null:
		result.message = "target has no CustomerVisit"
		return result
	if visit.actual == actual:
		result.success = true
		result.message = "actual already set"
		result.details.append("actual=%s" % _enum_name(CustomerVisit.Actual, actual))
		return result
	if visit.settlement_committed or visit.complaint != null:
		result.message = "cannot change actual after settlement/complaint history"
		return result
	if (
		actual == CustomerVisit.Actual.NOT_RESOLVED
		and visit.declaration != CustomerVisit.Declaration.NONE
	):
		result.message = "cannot reset actual while declaration is committed"
		return result

	visit.actual = actual
	match actual:
		CustomerVisit.Actual.NOT_RESOLVED:
			visit.disposition = CustomerVisit.Disposition.WAREHOUSE
			visit.reputation = CustomerVisit.Reputation.NONE
			visit.satisfaction = 0
		CustomerVisit.Actual.DELIVERED:
			visit.disposition = CustomerVisit.Disposition.DELIVERED
			visit.reputation = CustomerVisit.Reputation.NONE
			visit.satisfaction = (
				visit.definition.healthy_satisfaction
				if visit.definition != null
				else CustomerOutcomeService.SATISFACTION_SCALE
			)
		CustomerVisit.Actual.CUSTOMER_REFUSED:
			visit.disposition = CustomerVisit.Disposition.WAREHOUSE
			visit.reputation = CustomerVisit.Reputation.NONE
			visit.satisfaction = 0
		CustomerVisit.Actual.PLAYER_DENIED:
			visit.disposition = CustomerVisit.Disposition.WAREHOUSE
			visit.reputation = CustomerVisit.Reputation.PLAYER_DENIAL

	result.success = true
	result.message = "actual updated"
	result.details.append("actual=%s" % _enum_name(CustomerVisit.Actual, visit.actual))
	return result


static func declare(
	target: DebugTarget,
	declaration: CustomerVisit.Declaration,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if target.visit == null:
		result.message = "target has no CustomerVisit"
		return result
	if not CustomerFlowService.declare(target.visit.visit_id, declaration):
		result.message = "declaration was rejected by CustomerFlowService"
		return result
	result.success = true
	result.message = "declaration committed"
	result.details.append(
		"declaration=%s"
		% _enum_name(CustomerVisit.Declaration, target.visit.declaration)
	)
	return result


static func complaint(
	target: DebugTarget,
	reason: CustomerComplaint.Reason,
	resolve_now: bool,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	var visit: CustomerVisit = target.visit
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null:
		result.message = "target has no CustomerVisit"
		return result
	if cycle == null:
		result.message = "day cycle is unavailable"
		return result

	if reason == CustomerComplaint.Reason.DAMAGED:
		var state: C_PackageState = (
			target.entity.get_component(C_PackageState) as C_PackageState
			if EntityAvailability.contains(target.entity, ECS.world)
			else null
		)
		if state != null and state.damage != C_PackageState.Damage.UNDAMAGED:
			visit.package_damaged = true

	if not CustomerOutcomeService.create_complaint(visit, cycle.day_index, reason, true):
		result.message = "complaint conflicts with existing complaint"
		return result
	if resolve_now:
		CustomerOutcomeService.resolve_complaint(
			visit,
			WalletService.current(),
			cycle.day_index,
			true,
		)

	result.success = true
	result.message = "complaint resolved" if resolve_now else "complaint created"
	result.details.append("complaint=%s" % String(visit.complaint.complaint_id))
	result.details.append(
		"reason=%s" % _enum_name(CustomerComplaint.Reason, visit.complaint.reason)
	)
	result.details.append(
		"outcome=%s" % _enum_name(CustomerComplaint.Outcome, visit.complaint.outcome)
	)
	return result


static func resolve_complaint(target: DebugTarget) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	var visit: CustomerVisit = target.visit
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or visit.complaint == null:
		result.message = "target has no complaint"
		return result
	if cycle == null:
		result.message = "day cycle is unavailable"
		return result
	CustomerOutcomeService.resolve_complaint(
		visit,
		WalletService.current(),
		cycle.day_index,
		true,
	)
	result.success = visit.complaint.outcome != CustomerComplaint.Outcome.PENDING
	result.message = "complaint resolved" if result.success else "complaint remains pending"
	result.details.append(
		"outcome=%s" % _enum_name(CustomerComplaint.Outcome, visit.complaint.outcome)
	)
	return result


static func approve(
	target: DebugTarget,
	satisfaction: int,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if target.visit == null:
		result.message = "target has no CustomerVisit"
		return result
	if satisfaction < 0 or satisfaction > CustomerOutcomeService.SATISFACTION_SCALE:
		result.message = "satisfaction must be between 0 and 100"
		return result
	if not CustomerOutcomeService.approve(target.visit, satisfaction):
		result.message = "approval was rejected"
		return result
	result.success = true
	result.message = "customer approval recorded"
	result.details.append("satisfaction=%d" % target.visit.satisfaction)
	return result


static func _package_definition(target: DebugTarget) -> DEF_Package:
	if EntityAvailability.contains(target.entity, ECS.world):
		var identity: C_Package = target.entity.get_component(C_Package) as C_Package
		if identity != null and identity.definition != null:
			return identity.definition
	if target.registration != null:
		return target.registration.definition
	return null


static func _customer_policy(
	schedule: DEF_CustomerSchedule,
	package_definition: DEF_Package,
	customer_key: String,
) -> DEF_Customer:
	var normalized: String = customer_key.strip_edges()
	if normalized.is_empty():
		normalized = DEFAULT_CUSTOMER_KEY
	if normalized != DEFAULT_CUSTOMER_KEY:
		for event: DEF_CustomerEvent in schedule.events:
			if event.customer != null and String(event.customer.key) == normalized:
				return event.customer
		return null
	for event: DEF_CustomerEvent in schedule.events:
		if event.package_key == package_definition.key and event.customer != null:
			return event.customer
	for event: DEF_CustomerEvent in schedule.events:
		if event.customer != null:
			return event.customer
	return null


static func _enum_name(values: Dictionary, value: int) -> String:
	var keys: Array = values.keys()
	if value < 0 or value >= keys.size():
		return "UNKNOWN(%d)" % value
	return String(keys[value])
