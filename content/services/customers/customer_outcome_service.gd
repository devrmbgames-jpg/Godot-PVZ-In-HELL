extends RefCounted
## Deterministic outcome/finance rules, independent of live Nodes and presentation.
class_name CustomerOutcomeService

const SATISFACTION_SCALE: int = 100


static func check(
	visit: CustomerVisit,
	package: C_Package,
	state: C_PackageState,
	assigned: bool,
	held: bool,
	allow_held: bool = false,
) -> PackageDeliveryCheck:
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
	elif held and not allow_held:
		check_result.result = PackageDeliveryCheck.Result.HELD
	else:
		check_result.result = PackageDeliveryCheck.Result.READY
		check_result.damaged = state.damage == C_PackageState.Damage.DAMAGED
		check_result.opened = state.opening == C_PackageState.Opening.OPENED
	return check_result


static func receive(visit: CustomerVisit, check_result: PackageDeliveryCheck, declined: bool = false) -> bool:
	if visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
		return false
	if check_result.result != PackageDeliveryCheck.Result.READY:
		return false

	var policy: DEF_Customer = visit.definition
	visit.package_damaged = check_result.damaged
	visit.package_opened = check_result.opened
	if declined or policy.voluntary_refusal or (check_result.damaged and not policy.accepts_damaged) or (check_result.opened and not policy.accepts_opened):
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
	visit.satisfaction = clampi(
		visit.satisfaction + visit.dialogue_satisfaction_delta + visit.challenge_satisfaction_delta,
		0,
		SATISFACTION_SCALE,
	)
	return true


static func apply_challenge_result(visit: CustomerVisit, event: ChallengeResolution) -> bool:
	if (
		visit == null or visit.definition == null or event == null
		or event.result not in [ChallengeResult.Type.SUCCESS, ChallengeResult.Type.FAILURE]
		or (visit.challenge_visit_count == visit.visit_count and visit.challenge_key == event.challenge_key)
	):
		return false

	visit.challenge_visit_count = visit.visit_count
	visit.challenge_key = event.challenge_key
	visit.challenge_result = ChallengeResult.key(event.result)
	visit.challenge_satisfaction_delta += event.satisfaction_delta
	if visit.actual == CustomerVisit.Actual.NOT_RESOLVED:
		visit.satisfaction = clampi(visit.definition.healthy_satisfaction + visit.dialogue_satisfaction_delta + visit.challenge_satisfaction_delta, 0, SATISFACTION_SCALE)
	elif visit.actual == CustomerVisit.Actual.DELIVERED:
		visit.satisfaction = clampi(visit.satisfaction + event.satisfaction_delta, 0, SATISFACTION_SCALE)
	return true


static func apply_dialogue_intent(
	visit: CustomerVisit,
	intent: CustomerDialogueIntent.Type,
) -> bool:
	if visit == null or visit.definition == null or intent == CustomerDialogueIntent.Type.NONE:
		return false
	visit.last_dialogue_intent = intent
	var intent_bit: int = CustomerDialogueIntent.bit(intent)
	if intent_bit != 0 and bool(visit.applied_dialogue_intents & intent_bit):
		return true

	for reaction: DEF_CustomerDialogueReaction in visit.definition.dialogue_reactions:
		if reaction == null or reaction.intent != intent:
			continue
		visit.dialogue_satisfaction_delta += reaction.satisfaction_delta
		visit.complaint_probability_delta += reaction.complaint_probability_delta
		visit.aggression_probability_delta += reaction.aggression_probability_delta
		visit.followup_probability_delta += reaction.followup_probability_delta
		break

	if intent_bit != 0:
		visit.applied_dialogue_intents |= intent_bit
	return true


static func commit_player_denial(visit: CustomerVisit) -> bool:
	if (
		visit == null
		or visit.definition == null
		or visit.finished
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
	):
		return false

	visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	visit.reputation = CustomerVisit.Reputation.PLAYER_DENIAL
	visit.player_denial_count += 1
	var probability: float = clampf(
		visit.definition.immediate_aggression_probability + visit.aggression_probability_delta,
		0.0,
		1.0,
	)
	visit.aggressive = visit.aggression_roll < probability
	return true


static func declare(visit: CustomerVisit, value: CustomerVisit.Declaration) -> bool:
	if not visit.started or value == CustomerVisit.Declaration.NONE:
		return false
	if value < CustomerVisit.Declaration.TAKEN or value > CustomerVisit.Declaration.LOST:
		return false
	if visit.declaration != CustomerVisit.Declaration.NONE:
		return visit.declaration == value

	visit.declaration = value
	if value == CustomerVisit.Declaration.LOST:
		visit.loss_cause = CustomerVisit.LossCause.DECLARED_LOST
		visit.reputation = CustomerVisit.Reputation.LOST
	elif visit.actual == CustomerVisit.Actual.PLAYER_DENIED:
		visit.reputation = CustomerVisit.Reputation.PLAYER_DENIAL
	if value == CustomerVisit.Declaration.TAKEN and visit.actual != CustomerVisit.Actual.DELIVERED:
		var probability: float = clampf(
			visit.definition.immediate_aggression_probability + visit.aggression_probability_delta,
			0.0,
			1.0,
		)
		visit.aggressive = visit.aggression_roll < probability
	return true


## System-owned closeout for a package-pickup visit that never spawned because the
## parcel was not registered before the next Morning.
static func mark_missed_registration_lost(visit: CustomerVisit, day: int) -> bool:
	if (
		visit == null
		or day <= visit.arrival_day
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or visit.declaration != CustomerVisit.Declaration.NONE
	):
		return false

	visit.declaration = CustomerVisit.Declaration.LOST
	visit.loss_cause = CustomerVisit.LossCause.MISSED_REGISTRATION
	visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	visit.disposition = CustomerVisit.Disposition.LOST
	visit.reputation = CustomerVisit.Reputation.LOST
	visit.finished = true
	visit.finished_day = day
	return true


static func settle(visit: CustomerVisit, wallet: C_Wallet, day: int) -> void:
	if visit.settlement_committed or wallet == null:
		return

	var operation: MoneyOperation = null
	if visit.declaration == CustomerVisit.Declaration.LOST:
		var reason: MoneyOperation.Reason = (
			MoneyOperation.Reason.MISSED_REGISTRATION
			if visit.loss_cause == CustomerVisit.LossCause.MISSED_REGISTRATION
			else MoneyOperation.Reason.LOST
		)
		operation = WalletService.package_settlement(
			wallet,
			visit.visit_id,
			reason,
			visit.accounting_value,
			day,
		)
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


static func create_complaint(
	visit: CustomerVisit,
	day: int,
	reason: CustomerComplaint.Reason = CustomerComplaint.Reason.NOT_DELIVERED,
	force: bool = false,
) -> bool:
	if visit == null or visit.definition == null:
		return false
	if visit.complaint != null:
		return visit.complaint.reason == reason
	if not force and not visit.finished:
		return false

	if not force:
		var probability: float = visit.definition.complaint_probability
		if visit.actual == CustomerVisit.Actual.NOT_RESOLVED:
			probability = visit.definition.unresolved_complaint_probability
		elif visit.actual == CustomerVisit.Actual.DELIVERED:
			probability = visit.definition.false_complaint_probability
		elif visit.actual == CustomerVisit.Actual.CUSTOMER_REFUSED:
			probability = visit.definition.voluntary_complaint_probability
		probability = clampf(
			probability + visit.complaint_probability_delta,
			0.0,
			1.0,
		)
		if visit.complaint_roll >= probability:
			return false

	var complaint: CustomerComplaint = CustomerComplaint.new()
	complaint.complaint_id = StringName("complaint/" + String(visit.visit_id))
	complaint.reason = reason
	complaint.created_day = day
	complaint.resolve_day = day + maxi(1, visit.definition.complaint_delay_days)
	visit.complaint = complaint
	return true


static func resolve_complaint(
	visit: CustomerVisit,
	wallet: C_Wallet,
	day: int,
	ignore_delay: bool = false,
) -> void:
	var complaint: CustomerComplaint = visit.complaint
	if complaint == null or complaint.outcome != CustomerComplaint.Outcome.PENDING:
		return
	if not ignore_delay and day < complaint.resolve_day:
		return

	if complaint.reason == CustomerComplaint.Reason.DAMAGED:
		if visit.package_damaged:
			complaint.outcome = CustomerComplaint.Outcome.CONFIRMED
			visit.reputation = CustomerVisit.Reputation.DAMAGED_COMPLAINT
		else:
			_mark_false_claim(visit, complaint, day)
		complaint.resolved_day = day
		return

	if visit.actual == CustomerVisit.Actual.DELIVERED:
		_mark_false_claim(visit, complaint, day)
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
		var operation: MoneyOperation = WalletService.package_settlement(
			wallet,
			complaint.complaint_id,
			MoneyOperation.Reason.CONFIRMED_FRAUD,
			visit.accounting_value,
			day,
		)
		var result: WalletService.Status = WalletService.apply(wallet, operation, day)
		if result != WalletService.Status.COMMITTED and result != WalletService.Status.DUPLICATE:
			return
		complaint.outcome = CustomerComplaint.Outcome.CONFIRMED
		complaint.money_delta = -operation.amount
		if visit.actual != CustomerVisit.Actual.CUSTOMER_REFUSED:
			visit.settlement_committed = true
			visit.settlement_day = day
			visit.reputation = (
				CustomerVisit.Reputation.FRAUD
				if visit.declaration == CustomerVisit.Declaration.TAKEN
				else CustomerVisit.Reputation.CONFIRMED_REFUSAL
			)
	complaint.resolved_day = day


static func approve(visit: CustomerVisit, satisfaction: int) -> bool:
	if visit == null:
		return false

	visit.feedback = CustomerVisit.Feedback.APPROVED
	visit.satisfaction = clampi(satisfaction, 0, SATISFACTION_SCALE)
	return true


static func _mark_false_claim(
	visit: CustomerVisit,
	complaint: CustomerComplaint,
	day: int,
) -> void:
	complaint.outcome = CustomerComplaint.Outcome.FALSE_CLAIM
	complaint.retaliation_start_day = day
	complaint.retaliation_end_day = day + visit.definition.retaliation_days
	visit.reputation = CustomerVisit.Reputation.FALSE_COMPLAINT


static func retaliation_allowed(visit: CustomerVisit, day: int) -> bool:
	var complaint: CustomerComplaint = visit.complaint
	return complaint != null and complaint.outcome == CustomerComplaint.Outcome.FALSE_CLAIM and day >= complaint.retaliation_start_day and day < complaint.retaliation_end_day
