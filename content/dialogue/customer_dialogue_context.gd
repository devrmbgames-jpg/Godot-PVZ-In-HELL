extends RefCounted
## Typed read/action adapter exposed to DialogueManager as the "ctx" game state.
## Persistent authority remains in CustomerVisit, package state, and gameplay services.
class_name CustomerDialogueContext

const NO_COMPLAINT: int = -1
const NO_CHALLENGE_RESULT: StringName = &""
const DEFAULT_HUNGER_TIER: int = 0

var _actor: Entity = null
var _customer: E_Customer = null
var _visit_id: StringName = &""


func _init(actor: Entity, customer: E_Customer) -> void:
	_actor = actor
	_customer = customer
	var agent: C_CustomerAgent = _agent()
	if agent != null:
		_visit_id = agent.visit_id


## Enters the bounded R11 dialogue phase. The patience timeout remains authoritative.
func begin() -> bool:
	return (
		is_valid()
		and CustomerFlowService.enter_service_phase(_customer, C_CustomerAgent.Phase.DIALOGUE)
	)


## Returns a manually closed conversation to package service without reviving a leaving/dead NPC.
func end() -> void:
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
		# Panel releases modal capture before calling end(). The timer therefore
		# starts with movement/interaction already returned to the player.
		ChallengeService.activate(_customer)


## True only while the same live CustomerVisit is still eligible for this conversation.
func is_valid() -> bool:
	var visit: CustomerVisit = _visit()
	var agent: C_CustomerAgent = _agent()
	return (
		is_instance_valid(_actor)
		and is_instance_valid(_customer)
		and visit != null
		and agent != null
		and agent.visit_id == _visit_id
		and not visit.finished
		and _customer.get_component(C_Death) == null
	)


func can_continue() -> bool:
	var agent: C_CustomerAgent = _agent()
	return is_valid() and agent.phase == C_CustomerAgent.Phase.DIALOGUE


func day_phase() -> int:
	var cycle: C_DayCycle = DayPhaseService.current()
	return cycle.phase if cycle != null else C_DayCycle.Phase.NIGHT


func interests_text() -> String:
	var visit: CustomerVisit = _visit()
	var identity: C_NpcIdentity = _customer.get_component(C_NpcIdentity) as C_NpcIdentity if is_instance_valid(_customer) else null
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id) if identity != null else null
	return ", ".join(person.profile.interests) if person != null else ", ".join(visit.definition.interests) if visit != null and visit.definition != null else ""


func customer_phase() -> int:
	var agent: C_CustomerAgent = _agent()
	return agent.phase if agent != null else C_CustomerAgent.Phase.FINISHED


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


func dialogue_cue() -> String:
	var visit: CustomerVisit = _visit()
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
	if (
		visit != null
		and visit.visit_count > 1
		and visit.declaration == CustomerVisit.Declaration.NONE
	):
		return "followup"
	if (
		visit != null
		and visit.definition != null
		and visit.definition.dialogue_mode == DEF_Customer.DialogueMode.RIDDLE
		and not visit.riddle_solved
	):
		return "riddle"
	return "direct"


func apply_response_tags(tags: PackedStringArray) -> bool:
	var intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.from_tags(tags)
	if intent == CustomerDialogueIntent.Type.NONE:
		return true
	var visit: CustomerVisit = _visit()
	return CustomerOutcomeService.apply_dialogue_intent(visit, intent)


func commit_denial() -> bool:
	return is_valid() and CustomerFlowService.deny(_visit_id)


func defer_until_tomorrow() -> bool:
	return is_valid() and CustomerFlowService.defer_until_next_day(_visit_id)


func is_followup() -> bool:
	var visit: CustomerVisit = _visit()
	return visit != null and visit.visit_count > 1


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


func answer_riddle_correct() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false
	visit.riddle_solved = true
	return true


func voluntary_refuse() -> bool:
	return is_valid() and CustomerFlowService.voluntary_refuse(_customer)


func schedule_non_delivery_complaint() -> bool:
	var visit: CustomerVisit = _visit()
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or cycle == null:
		return false
	return CustomerOutcomeService.create_complaint(
		visit,
		cycle.day_index,
		CustomerComplaint.Reason.NOT_DELIVERED,
		true,
	)


func false_taken_detected() -> bool:
	var visit: CustomerVisit = _visit()
	return (
		visit != null
		and visit.declaration == CustomerVisit.Declaration.TAKEN
		and visit.actual != CustomerVisit.Actual.DELIVERED
		and visit.aggressive
	)


func enter_aggressive() -> bool:
	return false_taken_detected() and CustomerFlowService.enter_aggressive(_customer)


func requested_package_id() -> String:
	var visit: CustomerVisit = _visit()
	return visit.package_id if visit != null else ""


func package_actual_outcome() -> int:
	var visit: CustomerVisit = _visit()
	return visit.actual if visit != null else CustomerVisit.Actual.NOT_RESOLVED


func terminal_declaration() -> int:
	var visit: CustomerVisit = _visit()
	return visit.declaration if visit != null else CustomerVisit.Declaration.NONE


func complaint_outcome() -> int:
	var visit: CustomerVisit = _visit()
	if visit == null or visit.complaint == null:
		return NO_COMPLAINT
	return visit.complaint.outcome


func has_complaint() -> bool:
	var visit: CustomerVisit = _visit()
	return visit != null and visit.complaint != null


func complaint_reason() -> int:
	var visit: CustomerVisit = _visit()
	if visit == null or visit.complaint == null:
		return NO_COMPLAINT
	return visit.complaint.reason


func complaint_pending() -> bool:
	var visit: CustomerVisit = _visit()
	return (
		visit != null
		and visit.complaint != null
		and visit.complaint.outcome == CustomerComplaint.Outcome.PENDING
	)


func package_opened() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false
	if visit.package_opened:
		return true
	var state: C_PackageState = _requested_package_state()
	return state != null and state.opening == C_PackageState.Opening.OPENED


func package_damaged() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false
	if visit.package_damaged:
		return true
	var state: C_PackageState = _requested_package_state()
	return state != null and state.damage != C_PackageState.Damage.UNDAMAGED


func has_registered_number() -> bool:
	return package_number() > 0


func package_number() -> int:
	var visit: CustomerVisit = _visit()
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if visit == null or ledger == null:
		return 0
	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == visit.package_id and record.active:
			return record.number
	return 0


func package_number_text() -> String:
	var number: int = package_number()
	return "%03d" % number if number > 0 else "---"


func challenge_result() -> StringName:
	return ChallengeResult.key(ChallengeService.result_for(_customer))


func has_pending_challenge() -> bool:
	if not is_valid():
		return false
	var state: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	return (
		state != null and state.definition != null and state.definition.condition != null
		and state.definition.trigger == DEF_Challenge.Trigger.AFTER_DIALOGUE
		and state.phase == C_Challenge.Phase.INACTIVE and not state.consumed
	)


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


func arm_challenge() -> bool:
	return has_pending_challenge() and ChallengeService.arm(_customer, _actor)


## Derived tier only; the context never changes Hunger or customer identity.
func hunger_tier() -> int:
	return HungerService.tier(_actor.get_component(C_Hunger) as C_Hunger) if is_instance_valid(_actor) else DEFAULT_HUNGER_TIER


## Dialogue resolves the real line/branch first; only perceived NPC speech changes.
func perceived_text(actual_text: String) -> String:
	return "Съешь меня" if hunger_tier() == C_Hunger.Tier.STARVING and not actual_text.is_empty() else actual_text


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
