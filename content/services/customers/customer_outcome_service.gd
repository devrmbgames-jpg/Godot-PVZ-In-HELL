extends RefCounted
## Рассчитывает результаты и деньги по данным визита, без живых Node и представления.
class_name CustomerOutcomeService

const SATISFACTION_SCALE: int = 100


#region Проверка и фактическая выдача
## Проверяет регистрацию, принадлежность и состояние; held допускается только при allow_held.
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


## Однократно записывает реальное принятие или отказ и состояние предложенной коробки.
static func receive(visit: CustomerVisit, check_result: PackageDeliveryCheck, declined: bool = false) -> bool:
	if visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
		return _trace_outcome(visit, &"customers.receive", false)
	if check_result.result != PackageDeliveryCheck.Result.READY:
		return _trace_outcome(visit, &"customers.receive", false)

	var policy: DEF_Customer = visit.definition
	visit.package_damaged = check_result.damaged
	visit.package_opened = check_result.opened
	if declined or policy.voluntary_refusal or (check_result.damaged and not policy.accepts_damaged) or (check_result.opened and not policy.accepts_opened):
		visit.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
		visit.satisfaction = 0
		return _trace_outcome(visit, &"customers.receive", true)

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
	return _trace_outcome(visit, &"customers.receive", true)


#endregion

#region Реакции и заявления
## Commits a riddle answer once through the visit owner, never through Dialogue/UI fields.
static func answer_riddle(visit: CustomerVisit, correct: bool) -> bool:
	if visit.definition == null or visit.finished:
		return _trace_outcome(visit, &"customers.riddle", false)
	var duplicate: bool = visit.riddle_solved if correct else visit.riddle_wrong_answer_applied
	if not duplicate:
		if correct:
			visit.riddle_solved = true
		else:
			visit.dialogue_satisfaction_delta -= maxi(
				0, visit.definition.riddle_wrong_satisfaction_penalty
			)
			visit.riddle_wrong_answer_applied = true

	var trace_stage: BoundaryTraceEntry.Stage = (
		BoundaryTraceEntry.Stage.DUPLICATE if duplicate else BoundaryTraceEntry.Stage.COMPLETED
	)
	BoundaryTrace.record(&"customers.riddle", visit.visit_id, trace_stage,
		&"correct" if correct else &"wrong", String(visit.customer_id), String(visit.visit_id))
	return true


## Применяет результат испытания один раз для пары ключа и номера прихода.
static func apply_challenge_result(visit: CustomerVisit, event: ChallengeResolution) -> bool:
	if (
		visit == null or visit.definition == null or event == null
		or event.result not in [ChallengeResult.Type.SUCCESS, ChallengeResult.Type.FAILURE]
		or (visit.challenge_visit_count == visit.visit_count and visit.challenge_key == event.challenge_key)
	):
		return _trace_outcome(visit, &"customers.apply_challenge_result", false)

	visit.challenge_visit_count = visit.visit_count
	visit.challenge_key = event.challenge_key
	visit.challenge_result = ChallengeResult.key(event.result)
	visit.challenge_satisfaction_delta += event.satisfaction_delta
	if visit.actual == CustomerVisit.Actual.NOT_RESOLVED:
		visit.satisfaction = clampi(visit.definition.healthy_satisfaction + visit.dialogue_satisfaction_delta + visit.challenge_satisfaction_delta, 0, SATISFACTION_SCALE)
	elif visit.actual == CustomerVisit.Actual.DELIVERED:
		visit.satisfaction = clampi(visit.satisfaction + event.satisfaction_delta, 0, SATISFACTION_SCALE)
	return _trace_outcome(visit, &"customers.apply_challenge_result", true)


## Учитывает реакцию на смысл ответа; маска визита исключает повтор одного намерения.
static func apply_dialogue_intent(
	visit: CustomerVisit,
	intent: CustomerDialogueIntent.Type,
) -> bool:
	if visit == null or visit.definition == null or intent == CustomerDialogueIntent.Type.NONE:
		return _trace_outcome(visit, &"customers.apply_dialogue_intent", false)

	visit.last_dialogue_intent = intent
	var intent_bit: int = CustomerDialogueIntent.bit(intent)
	if intent_bit != 0 and bool(visit.applied_dialogue_intents & intent_bit):
		return _trace_outcome(visit, &"customers.apply_dialogue_intent", true, true)

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
	return _trace_outcome(visit, &"customers.apply_dialogue_intent", true)


## Фиксирует фактический отказ игрока и агрессию по сохранённому броску визита.
static func commit_player_denial(visit: CustomerVisit) -> bool:
	if (
		visit == null
		or visit.definition == null
		or visit.finished
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
	):
		return _trace_outcome(visit, &"customers.commit_player_denial", false)

	visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	visit.reputation = CustomerVisit.Reputation.PLAYER_DENIAL
	visit.player_denial_count += 1
	var probability: float = clampf(
		visit.definition.immediate_aggression_probability + visit.aggression_probability_delta,
		0.0,
		1.0,
	)
	visit.aggressive = visit.aggression_roll < probability
	return _trace_outcome(visit, &"customers.commit_player_denial", true)


## Однократно фиксирует заявление игрока; повтор того же значения допускается, смена — нет.
static func declare(visit: CustomerVisit, value: CustomerVisit.Declaration) -> bool:
	if visit == null or value == CustomerVisit.Declaration.NONE:
		return _trace_outcome(visit, &"customers.declare", false)
	if not visit.started and value != CustomerVisit.Declaration.LOST:
		return _trace_outcome(visit, &"customers.declare", false)
	if value < CustomerVisit.Declaration.TAKEN or value > CustomerVisit.Declaration.LOST:
		return _trace_outcome(visit, &"customers.declare", false)
	if visit.declaration != CustomerVisit.Declaration.NONE:
		return _trace_outcome(visit, &"customers.declare", visit.declaration == value, true)

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
	return _trace_outcome(visit, &"customers.declare", true)


## Фиксирует пропущенный срок регистрации без заявления, закрытия заказа или выдуманной выдачи.
static func mark_registration_overdue(visit: CustomerVisit, day: int) -> bool:
	if (
		visit == null
		or day <= visit.arrival_day
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or visit.declaration != CustomerVisit.Declaration.NONE
		or visit.registration_overdue_day != 0
	):
		return _trace_outcome(visit, &"customers.mark_registration_overdue", false)

	visit.registration_overdue_day = day
	return _trace_outcome(visit, &"customers.mark_registration_overdue", true)


#endregion

#region Деньги и жалобы
## Однократно применяет отдельный штраф просрочки; не блокирует последующее обслуживание.
static func settle_registration_overdue(visit: CustomerVisit, wallet: C_Wallet, day: int) -> void:
	if visit.registration_overdue_day == 0 or visit.registration_penalty_committed or wallet == null:
		return
	var operation: MoneyOperation = WalletService.package_settlement(
		wallet,
		StringName("registration/" + String(visit.visit_id)),
		MoneyOperation.Reason.MISSED_REGISTRATION,
		visit.accounting_value,
		day,
	)
	var result: WalletService.Status = WalletService.apply(wallet, operation, day)
	if result == WalletService.Status.COMMITTED or result == WalletService.Status.DUPLICATE:
		visit.registration_penalty_committed = true
		visit.registration_penalty_day = operation.day_index
		visit.registration_money_delta = -operation.amount
	_trace_outcome(visit, &"customers.registration_settlement", visit.registration_penalty_committed)


## Применяет выплату или штраф через идемпотентную операцию WalletService и записывает итог.
static func settle(visit: CustomerVisit, wallet: C_Wallet, day: int) -> void:
	settle_registration_overdue(visit, wallet, day)
	if visit.settlement_committed or wallet == null:
		return

	var operation: MoneyOperation = null
	if visit.declaration == CustomerVisit.Declaration.LOST:
		operation = WalletService.package_settlement(
			wallet,
			visit.visit_id,
			MoneyOperation.Reason.LOST,
			visit.accounting_value,
			day,
		)
		if operation != null and visit.registration_penalty_committed:
			# Уже взысканная просрочка покрывает стоимость потери этой же коробки.
			operation.amount = maxi(0, operation.amount + visit.registration_money_delta)
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
	_trace_outcome(visit, &"customers.settlement", visit.settlement_committed)


## Создаёт единственную жалобу; force обходит ожидание завершения и проверку вероятности.
## claimant_name сохраняет известное имя, иначе используется авторское имя обычного клиента.
static func create_complaint(
	visit: CustomerVisit,
	day: int,
	reason: CustomerComplaint.Reason = CustomerComplaint.Reason.NOT_DELIVERED,
	force: bool = false,
	claimant_name: String = "",
) -> bool:
	if visit == null or visit.definition == null:
		return _trace_outcome(visit, &"customers.create_complaint", false)
	if visit.complaint != null:
		return _trace_outcome(
			visit, &"customers.create_complaint", visit.complaint.reason == reason, true
		)
	if not force and not visit.finished:
		return _trace_outcome(visit, &"customers.create_complaint", false)

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
			return _trace_outcome(visit, &"customers.create_complaint", false)

	var complaint: CustomerComplaint = CustomerComplaint.new()
	complaint.complaint_id = StringName("complaint/" + String(visit.visit_id))
	complaint.customer_id = visit.customer_id
	complaint.customer_name = claimant_name if not claimant_name.is_empty() else visit.definition.display_name
	complaint.message = visit.definition.complaint_text
	if complaint.message.is_empty():
		complaint.message = (
			"Мне не выдали посылку. Прошу разобраться."
			if reason == CustomerComplaint.Reason.NOT_DELIVERED
			else "Мне выдали повреждённую посылку. Прошу разобраться."
		)
	complaint.reason = reason
	complaint.created_day = day
	complaint.resolve_day = day + maxi(1, visit.definition.complaint_delay_days)
	visit.complaint = complaint
	return _trace_outcome(visit, &"customers.create_complaint", true)


## Разрешает созревшую жалобу по фактам; ignore_delay допускает досрочный разбор.
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


## Записывает одобрение и довольство, ограниченное диапазоном 0–100.
static func approve(visit: CustomerVisit, satisfaction: int) -> bool:
	if visit == null:
		return _trace_outcome(visit, &"customers.approve", false)

	visit.feedback = CustomerVisit.Feedback.APPROVED
	visit.satisfaction = clampi(satisfaction, 0, SATISFACTION_SCALE)
	return _trace_outcome(visit, &"customers.approve", true)


static func _mark_false_claim(
	visit: CustomerVisit,
	complaint: CustomerComplaint,
	day: int,
) -> void:
	complaint.outcome = CustomerComplaint.Outcome.FALSE_CLAIM
	complaint.retaliation_start_day = day
	complaint.retaliation_end_day = day + visit.definition.retaliation_days
	visit.reputation = CustomerVisit.Reputation.FALSE_COMPLAINT


## Разрешает ответ игрока на ложную жалобу в интервале [начало, конец) по дням.
static func retaliation_allowed(visit: CustomerVisit, day: int) -> bool:
	var complaint: CustomerComplaint = visit.complaint
	return complaint != null and complaint.outcome == CustomerComplaint.Outcome.FALSE_CLAIM and day >= complaint.retaliation_start_day and day < complaint.retaliation_end_day

#endregion

#region Boundary diagnostics
static func _trace_outcome(
	visit: CustomerVisit, operation: StringName, committed: bool, duplicate: bool = false,
) -> bool:
	var trace_stage: BoundaryTraceEntry.Stage = (
		BoundaryTraceEntry.Stage.COMPLETED if committed else BoundaryTraceEntry.Stage.REJECTED
	)
	var correlation_id: StringName = visit.visit_id if visit != null else &""
	if committed and duplicate:
		trace_stage = BoundaryTraceEntry.Stage.DUPLICATE
	var target_id: String = String(correlation_id)
	var origin_id: String = String(visit.customer_id) if visit != null else ""
	var reason: StringName = &"invalid_or_closed"
	if committed:
		reason = &"duplicate" if duplicate else &"committed"
	BoundaryTrace.record(operation, correlation_id, trace_stage, reason, origin_id, target_id)
	return committed
#endregion
