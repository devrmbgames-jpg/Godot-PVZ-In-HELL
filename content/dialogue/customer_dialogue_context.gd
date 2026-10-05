extends NpcDialogueContext
## Типизированный контекст ctx для DialogueManager: чтение состояния и запросы действий.
## Постоянные данные принадлежат CustomerVisit, состоянию коробки и игровым сервисам.
class_name CustomerDialogueContext

const NO_COMPLAINT: int = -1
const NO_CHALLENGE_RESULT: StringName = &""
const DEFAULT_HUNGER_TIER: int = 0

var _actor: Entity = null
var _customer: E_Customer = null
var _visit_id: StringName = &""


#region Жизненный цикл разговора
func _init(actor: Entity, customer: E_Customer) -> void:
	super(actor, customer)
	_actor = actor
	_customer = customer
	var agent: C_CustomerAgent = _agent()
	if agent != null:
		_visit_id = agent.visit_id


## Начинает фазу диалога; таймер терпения продолжает ограничивать обслуживание.
func begin() -> bool:
	if not is_valid() or NpcDialogueService.participant(_customer) != null:
		return false
	if not CustomerFlowService.enter_service_phase(_customer, C_CustomerAgent.Phase.DIALOGUE):
		return false

	_customer.add_relationship(Relationship.new(R_NpcConversation.new(), _actor))
	return true


## После ручного закрытия возвращает к выдаче; уходящий или погибший NPC не возобновляет обслуживание.
func end() -> void:
	if NpcDialogueService.participant(_customer) == _actor or not EntityAvailability.contains(_actor, ECS.world):
		NpcDialogueService.end(_customer)

	var agent: C_CustomerAgent = _agent()
	if (
		agent != null
		and agent.phase == C_CustomerAgent.Phase.DIALOGUE
		and _customer.get_component(C_Death) == null
		and not _visit_finished()
	):
		CustomerFlowService.enter_service_phase(
			_customer,
			C_CustomerAgent.Phase.WAITING_FOR_PACKAGE,
		)
		# Панель освобождает модальный ввод до end(), поэтому таймер запускается
		# после возврата игроку управления движением и взаимодействиями.
		ChallengeService.activate(_customer)


## Проверяет, что тот же живой CustomerVisit всё ещё допускает этот разговор.
func is_valid() -> bool:
	var visit: CustomerVisit = _visit()
	var agent: C_CustomerAgent = _agent()
	if not is_instance_valid(_actor) or not is_instance_valid(_customer) or _actor.has_component(C_Death):
		return false
	if _customer is E_DistrictNpc:
		var player_body: Node3D = _actor as Node as Node3D
		var district: C_District = DistrictPopulationService.current()
		if not GrabService.holder_available(_actor) or not GrabService.holder_available(_customer) or player_body == null or district == null:
			return false
		if _customer.global_position.distance_to(player_body.global_position) > district.definition.conversation_range:
			return false

	return (
		is_instance_valid(_actor)
		and is_instance_valid(_customer)
		and visit != null
		and agent != null
		and agent.visit_id == _visit_id
		and not visit.finished
		and _customer.get_component(C_Death) == null
	)


## Требует того же живого собеседника и непрерванной фазы обслуживания.
func can_continue() -> bool:
	var agent: C_CustomerAgent = _agent()
	var awareness: C_NpcAwareness = _customer.get_component(C_NpcAwareness) as C_NpcAwareness if is_instance_valid(_customer) else null
	return is_valid() and NpcDialogueService.participant(_customer) == _actor and agent.phase == C_CustomerAgent.Phase.DIALOGUE and CombatService.target_for(_customer) == null and (awareness == null or not awareness.fleeing)


#endregion

#region Диалог и адаптер заказа
## Возвращает фазу дня, которой управляет игрок.
func day_phase() -> int:
	var cycle: C_DayCycle = DayPhaseService.current()
	return cycle.phase if cycle != null else C_DayCycle.Phase.NIGHT


## Читает интересы постоянной личности или правила старого клиента.
func interests_text() -> String:
	var visit: CustomerVisit = _visit()
	var identity: C_NpcIdentity = _customer.get_component(C_NpcIdentity) as C_NpcIdentity if is_instance_valid(_customer) else null
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id) if identity != null else null
	return ", ".join(person.profile.interests) if person != null else ", ".join(visit.definition.interests) if visit != null and visit.definition != null else ""


## Возвращает текущую фазу обслуживания.
func customer_phase() -> int:
	var agent: C_CustomerAgent = _agent()
	return agent.phase if agent != null else C_CustomerAgent.Phase.FINISHED


## Читает довольство визитом по существующим правилам расчёта.
func satisfaction() -> int:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return 0
	if visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
		return visit.satisfaction

	var base: int = (
		visit.definition.healthy_satisfaction
		if visit.definition != null
		else CustomerOutcomeService.SATISFACTION_SCALE
	)
	return clampi(
		base + visit.dialogue_satisfaction_delta + visit.challenge_satisfaction_delta,
		0,
		CustomerOutcomeService.SATISFACTION_SCALE,
	)


## Выбирает ветку по личности NPC, сохраняя ветки результатов обслуживания.
func dialogue_cue() -> String:
	var visit: CustomerVisit = _visit()
	var identity: C_NpcIdentity = _customer.get_component(C_NpcIdentity) as C_NpcIdentity if is_instance_valid(_customer) else null
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id) if identity != null else null
	if false_taken_detected():
		return "false_taken"
	if has_pending_challenge():
		return "challenge"
	if (
		visit != null
		and visit.definition != null
		and visit.definition.voluntary_refusal
		and visit.actual == CustomerVisit.Actual.CUSTOMER_REFUSED
	):
		return "voluntary_refusal"
	if person != null and person.profile.rule_for(DEF_NpcTrait.Kind.RIDDLE) != null and not visit.riddle_solved:
		return "riddle"
	if can_offer_delivery():
		return "home_request"
	if has_broken_promise():
		return "broken_promise"
	if person != null and person.profile.rule_for(DEF_NpcTrait.Kind.PROVOCATEUR) != null:
		return "provocation"
	if (
		visit != null
		and visit.visit_count > 1
		and visit.declaration == CustomerVisit.Declaration.NONE
	):
		return "followup"
	if (
		person == null
		and visit != null
		and visit.definition != null
		and visit.definition.dialogue_mode == DEF_Customer.DialogueMode.RIDDLE
		and not visit.riddle_solved
	):
		return "riddle"
	return "direct"


## Применяет правила обслуживания и социальные теги, включая явное подчинение.
func apply_response_tags(tags: PackedStringArray) -> bool:
	if not is_valid():
		return false
	if tags.has("sub") and _customer is E_DistrictNpc:
		NpcSocialService.react(_customer as E_DistrictNpc, _actor, NpcMemory.Kind.SUBMISSION, StringName("dialogue/%s/sub" % _visit_id))
		return true

	var intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.from_tags(tags)
	if intent == CustomerDialogueIntent.Type.NONE:
		return true

	var visit: CustomerVisit = _visit()
	var applied: bool = CustomerOutcomeService.apply_dialogue_intent(visit, intent)
	if applied and _customer is E_DistrictNpc:
		NpcSocialService.dialogue_response(_customer as E_DistrictNpc, _actor, intent, StringName("dialogue/%s/%d" % [_visit_id, intent]))
	return applied


## Проверяет, может ли получатель предложить реальную зарегистрированную коробку на вечер.
func can_offer_delivery() -> bool:
	return _customer is E_DistrictNpc and NpcHomeDeliveryService.offer_for(_customer as E_DistrictNpc) != null


## Принимает допуслугу через сервис домашних доставок.
func accept_home_delivery() -> bool:
	return _customer is E_DistrictNpc and NpcHomeDeliveryService.accept(_customer as E_DistrictNpc)

## Отказывает в допуслуге; получатель заберёт эту же коробку через 1–3 дня.
func decline_home_delivery() -> bool:
	return _customer is E_DistrictNpc and NpcHomeDeliveryService.decline(_customer as E_DistrictNpc)

## Позволяет синхронно закрыть именно разговор с этим NPC перед нападением.
func speaks_with(npc: Entity) -> bool:
	return _customer == npc

func _delivery_offer() -> NpcHomeDelivery:
	var visit: CustomerVisit = NpcHomeDeliveryService.offer_for(_customer as E_DistrictNpc) if _customer is E_DistrictNpc else null
	return NpcDeliveryOfferService.personal_for(visit.customer_id, visit.visit_id) if visit != null else null

func _delivery_npc() -> E_DistrictNpc:
	return _customer as E_DistrictNpc

func _delivery_player() -> Entity:
	return _actor


## Фиксирует отказ игрока через сервис обслуживания.
func commit_denial() -> bool:
	return is_valid() and CustomerFlowService.deny(_visit_id)


## Переносит визит, сохраняя постоянную личность получателя.
func defer_until_tomorrow() -> bool:
	return is_valid() and CustomerFlowService.defer_until_next_day(_visit_id)


## Проверяет, состоялся ли предыдущий приход по этому заказу.
func is_followup() -> bool:
	var visit: CustomerVisit = _visit()
	return visit != null and visit.visit_count > 1


## Применяет последствие неверного ответа однократно.
func answer_riddle_wrong() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null or visit.definition == null:
		return false
	if visit.riddle_wrong_answer_applied:
		return true

	visit.dialogue_satisfaction_delta -= maxi(
		0,
		visit.definition.riddle_wrong_satisfaction_penalty,
	)
	visit.riddle_wrong_answer_applied = true
	return true


## Раскрывает настоящий номер, не заменяя заказ.
func answer_riddle_correct() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false

	visit.riddle_solved = true
	return true


## Запрашивает физический отказ получателя от предлагаемой коробки.
func voluntary_refuse() -> bool:
	return is_valid() and CustomerFlowService.voluntary_refuse(_customer)


## Создаёт жалобу о невыдаче однократно.
func schedule_non_delivery_complaint() -> bool:
	var visit: CustomerVisit = _visit()
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or cycle == null:
		return false
	return CustomerFlowService.create_complaint(
		visit,
		cycle.day_index,
		CustomerComplaint.Reason.NOT_DELIVERED,
		true,
	)


## Проверяет, обнаружено ли ложное заявление о выдаче.
func false_taken_detected() -> bool:
	var visit: CustomerVisit = _visit()
	return (
		visit != null
		and visit.declaration == CustomerVisit.Declaration.TAKEN
		and visit.actual != CustomerVisit.Actual.DELIVERED
		and visit.aggressive
	)


## Передаёт обнаруженное ложное заявление сервису эскалации.
func enter_aggressive() -> bool:
	return false_taken_detected() and CustomerFlowService.enter_aggressive(_customer)


## Возвращает ID конкретной коробки этого заказа.
func requested_package_id() -> String:
	var visit: CustomerVisit = _visit()
	return visit.package_id if visit != null else ""


## Читает фактический результат обслуживания.
func package_actual_outcome() -> int:
	var visit: CustomerVisit = _visit()
	return visit.actual if visit != null else CustomerVisit.Actual.NOT_RESOLVED


## Читает заявление игрока в журнале.
func terminal_declaration() -> int:
	var visit: CustomerVisit = _visit()
	return visit.declaration if visit != null else CustomerVisit.Declaration.NONE


## Читает решение по жалобе.
func complaint_outcome() -> int:
	var visit: CustomerVisit = _visit()
	if visit == null or visit.complaint == null:
		return NO_COMPLAINT
	return visit.complaint.outcome


## Проверяет наличие жалобы по этому заказу.
func has_complaint() -> bool:
	var visit: CustomerVisit = _visit()
	return visit != null and visit.complaint != null


## Читает причину жалобы.
func complaint_reason() -> int:
	var visit: CustomerVisit = _visit()
	if visit == null or visit.complaint == null:
		return NO_COMPLAINT
	return visit.complaint.reason


## Проверяет наличие неразрешённой жалобы.
func complaint_pending() -> bool:
	var visit: CustomerVisit = _visit()
	return (
		visit != null
		and visit.complaint != null
		and visit.complaint.outcome == CustomerComplaint.Outcome.PENDING
	)


## Читает сохранённое при выдаче или текущее физическое вскрытие коробки.
func package_opened() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false
	if visit.package_opened:
		return true

	var state: C_PackageState = _requested_package_state()
	return state != null and state.opening == C_PackageState.Opening.OPENED


## Читает сохранённое при выдаче или текущее физическое повреждение коробки.
func package_damaged() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false
	if visit.package_damaged:
		return true

	var state: C_PackageState = _requested_package_state()
	return state != null and state.damage != C_PackageState.Damage.UNDAMAGED


## Проверяет, присвоен ли настоящий регистрационный номер.
func has_registered_number() -> bool:
	return package_number() > 0


## Читает регистрацию именно этой коробки.
func package_number() -> int:
	var visit: CustomerVisit = _visit()
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if visit == null or ledger == null:
		return 0

	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == visit.package_id and record.active:
			return record.number
	return 0


## Форматирует существующий регистрационный номер.
func package_number_text() -> String:
	var number: int = package_number()
	return "%03d" % number if number > 0 else "---"


## Читает результат старого испытания.
func challenge_result() -> StringName:
	return ChallengeResult.key(ChallengeService.result_for(_customer))


## Проверяет старое испытание; районные NPC используют собственные особенности.
func has_pending_challenge() -> bool:
	if not is_valid():
		return false

	var state: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	return (
		state != null and state.definition != null and state.definition.condition != null
		and state.definition.trigger == DEF_Challenge.Trigger.AFTER_DIALOGUE
		and state.phase == C_Challenge.Phase.INACTIVE and not state.consumed
	)


## Возвращает предупреждение старого испытания.
func challenge_rule() -> String:
	if not is_instance_valid(_customer):
		return ""

	var state: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	if state == null or state.definition == null:
		return ""

	var text: String = state.definition.rule_text
	if state.definition.timeout_seconds > 0.0:
		text += " У вас %d секунд после разговора." % ceili(state.definition.timeout_seconds)
	return text


## Запускает старое испытание через его игровой сервис.
func arm_challenge() -> bool:
	return has_pending_challenge() and ChallengeService.arm(_customer, _actor)


## Читает уровень голода без изменения Hunger и личности получателя.
func hunger_tier() -> int:
	return HungerService.tier(_actor.get_component(C_Hunger) as C_Hunger) if is_instance_valid(_actor) else DEFAULT_HUNGER_TIER


## Меняет только восприятие реплики; настоящую ветку и текст выбирает DialogueManager.
func perceived_text(actual_text: String) -> String:
	var hunger: C_Hunger = _actor.get_component(C_Hunger) as C_Hunger if is_instance_valid(_actor) else null
	return "Съешь меня" if HungerService.sees_npcs_as_food(hunger) and not actual_text.is_empty() else actual_text


#endregion

#region Чтение заказа
func _visit() -> CustomerVisit:
	return CustomerFlowService.find_visit(_visit_id) if _visit_id != &"" else null


func _visit_finished() -> bool:
	var visit: CustomerVisit = _visit()
	return visit == null or visit.finished


func _agent() -> C_CustomerAgent:
	if not is_instance_valid(_customer):
		return null
	return _customer.get_component(C_CustomerAgent) as C_CustomerAgent


func _requested_package_state() -> C_PackageState:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return null

	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	return parcel.get_component(C_PackageState) as C_PackageState if parcel != null else null
#endregion
