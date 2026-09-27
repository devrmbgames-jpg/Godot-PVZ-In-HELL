extends RefCounted
## Deterministic outcome/finance rules, independent of live Nodes and presentation.
class_name CustomerOutcomeService

const SATISFACTION_SCALE: int = 100


static func check(visit: CustomerVisit, package: C_Package, state: C_PackageState, assigned: bool, held: bool) -> PackageDeliveryCheck:
	var check_result: PackageDeliveryCheck = PackageDeliveryCheck.new()
	if visit.actual != CustomerVisit.Actual.NOT_RESOLVED or visit.finished:
		check_result.result = PackageDeliveryCheck.Result.ALREADY_CLOSED
	elif package == null or state == null:
		check_result.result = PackageDeliveryCheck.Result.MISSING
	elif state.registration != C_PackageState.Registration.REGISTERED:
		check_result.result = PackageDeliveryCheck.Result.UNREGISTERED
	elif package.package_id != visit.package_id:
		check_result.result = PackageDeliveryCheck.Result.WRONG_PACKAGE
	elif not assigned:
		check_result.result = PackageDeliveryCheck.Result.UNASSIGNED
	elif state.damage == C_PackageState.Damage.DESTROYED:
		check_result.result = PackageDeliveryCheck.Result.DESTROYED
	elif held:
		check_result.result = PackageDeliveryCheck.Result.HELD
	else:
		check_result.result = PackageDeliveryCheck.Result.READY
		check_result.damaged = state.damage == C_PackageState.Damage.DAMAGED
		check_result.opened = state.opening == C_PackageState.Opening.OPENED
	return check_result


static func receive(visit: CustomerVisit, check_result: PackageDeliveryCheck) -> bool:
	if visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
		return false
	if check_result.result != PackageDeliveryCheck.Result.READY:
		return false
	var policy: DEF_Customer = visit.definition
	if policy.voluntary_refusal or (check_result.damaged and not policy.accepts_damaged) or (check_result.opened and not policy.accepts_opened):
		visit.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
		visit.satisfaction = 0
		return true
	visit.actual = CustomerVisit.Actual.DELIVERED
	visit.disposition = CustomerVisit.Disposition.DELIVERED
	visit.satisfaction = policy.healthy_satisfaction
	if check_result.damaged:
		visit.satisfaction = mini(visit.satisfaction, policy.damaged_satisfaction)
	if check_result.opened:
		visit.satisfaction = mini(visit.satisfaction, policy.opened_satisfaction)
	return true


static func declare(visit: CustomerVisit, value: CustomerVisit.Declaration) -> bool:
	if not visit.started or value == CustomerVisit.Declaration.NONE:
		return false
	if value < CustomerVisit.Declaration.TAKEN or value > CustomerVisit.Declaration.LOST:
		return false
	if visit.declaration != CustomerVisit.Declaration.NONE:
		return visit.declaration == value
	visit.declaration = value
	if visit.actual == CustomerVisit.Actual.NOT_RESOLVED and value != CustomerVisit.Declaration.TAKEN:
		visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	if value == CustomerVisit.Declaration.LOST:
		visit.reputation = CustomerVisit.Reputation.LOST
	elif visit.actual == CustomerVisit.Actual.PLAYER_DENIED:
		visit.reputation = CustomerVisit.Reputation.PLAYER_DENIAL
	if value == CustomerVisit.Declaration.TAKEN and visit.actual != CustomerVisit.Actual.DELIVERED:
		visit.aggressive = visit.aggression_roll < visit.definition.immediate_aggression_probability
	return true


static func settle(visit: CustomerVisit, wallet: C_Wallet, day: int) -> void:
	if visit.settlement_committed or wallet == null:
		return
	var operation: MoneyOperation = null
	if visit.declaration == CustomerVisit.Declaration.LOST:
		operation = WalletService.package_settlement(wallet, visit.visit_id, MoneyOperation.Reason.LOST, visit.accounting_value, day)
	elif visit.actual == CustomerVisit.Actual.PLAYER_DENIED and visit.declaration == CustomerVisit.Declaration.REFUSED:
		operation = WalletService.package_settlement(wallet, visit.visit_id, MoneyOperation.Reason.PLAYER_REFUSAL, visit.accounting_value, day)
	elif visit.actual == CustomerVisit.Actual.DELIVERED and visit.declaration == CustomerVisit.Declaration.TAKEN:
		operation = MoneyOperation.new()
		operation.operation_id = StringName("delivery/" + String(visit.visit_id))
		operation.settlement_id = visit.visit_id
		operation.day_index = day
		@warning_ignore("integer_division")
		operation.amount = visit.payment * clampi(visit.satisfaction, 0, SATISFACTION_SCALE) / SATISFACTION_SCALE
	if operation == null:
		return
	var result: WalletService.Status = WalletService.apply(wallet, operation, day)
	if result == WalletService.Status.COMMITTED or result == WalletService.Status.DUPLICATE:
		visit.settlement_committed = true
		visit.settlement_day = day
		visit.money_delta = operation.amount if operation.reason == MoneyOperation.Reason.PAYMENT else -operation.amount


static func create_complaint(visit: CustomerVisit, day: int) -> void:
	if visit.complaint != null or not visit.finished:
		return
	var probability: float = visit.definition.complaint_probability
	if visit.actual == CustomerVisit.Actual.DELIVERED:
		probability = visit.definition.false_complaint_probability
	elif visit.actual == CustomerVisit.Actual.CUSTOMER_REFUSED:
		probability = visit.definition.voluntary_complaint_probability
	if visit.complaint_roll >= probability:
		return
	var complaint: CustomerComplaint = CustomerComplaint.new()
	complaint.complaint_id = StringName("complaint/" + String(visit.visit_id))
	complaint.created_day = day
	complaint.resolve_day = day + maxi(1, visit.definition.complaint_delay_days)
	visit.complaint = complaint


static func resolve_complaint(visit: CustomerVisit, wallet: C_Wallet, day: int) -> void:
	var complaint: CustomerComplaint = visit.complaint
	if complaint == null or complaint.outcome != CustomerComplaint.Outcome.PENDING or day < complaint.resolve_day:
		return
	if visit.actual == CustomerVisit.Actual.DELIVERED:
		complaint.outcome = CustomerComplaint.Outcome.FALSE_CLAIM
		complaint.retaliation_start_day = day
		complaint.retaliation_end_day = day + visit.definition.retaliation_days
		visit.reputation = CustomerVisit.Reputation.FALSE_COMPLAINT
	elif visit.declaration == CustomerVisit.Declaration.TAKEN and visit.defeated_by_player:
		complaint.outcome = CustomerComplaint.Outcome.WAIVED_PLAYER_DEFEAT
		visit.reputation = CustomerVisit.Reputation.FRAUD
	elif visit.customer_dead:
		complaint.outcome = CustomerComplaint.Outcome.NO_LIVING_CLAIMANT
	elif visit.settlement_committed and visit.actual != CustomerVisit.Actual.CUSTOMER_REFUSED:
		complaint.outcome = CustomerComplaint.Outcome.ALREADY_SETTLED
	else:
		if wallet == null:
			return
		var operation: MoneyOperation = WalletService.package_settlement(wallet, complaint.complaint_id, MoneyOperation.Reason.CONFIRMED_FRAUD, visit.accounting_value, day)
		var result: WalletService.Status = WalletService.apply(wallet, operation, day)
		if result != WalletService.Status.COMMITTED and result != WalletService.Status.DUPLICATE:
			return
		complaint.outcome = CustomerComplaint.Outcome.CONFIRMED
		complaint.money_delta = -operation.amount
		if visit.actual != CustomerVisit.Actual.CUSTOMER_REFUSED:
			visit.settlement_committed = true
			visit.settlement_day = day
		visit.reputation = CustomerVisit.Reputation.FRAUD if visit.declaration == CustomerVisit.Declaration.TAKEN else CustomerVisit.Reputation.CONFIRMED_REFUSAL
	complaint.resolved_day = day


static func retaliation_allowed(visit: CustomerVisit, day: int) -> bool:
	var complaint: CustomerComplaint = visit.complaint
	return complaint != null and complaint.outcome == CustomerComplaint.Outcome.FALSE_CLAIM and day >= complaint.retaliation_start_day and day < complaint.retaliation_end_day
