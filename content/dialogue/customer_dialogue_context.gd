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
		base + visit.dialogue_satisfaction_delta,
		0,
		CustomerOutcomeService.SATISFACTION_SCALE,
	)


func dialogue_cue() -> String:
	var visit: CustomerVisit = _visit()
	if false_taken_detected():
		return "false_taken"
	if (
		visit != null
		and visit.definition != null
		and visit.definition.voluntary_refusal
		and visit.actual == CustomerVisit.Actual.NOT_RESOLVED
	):
		return "voluntary_refusal"
	if (
		visit != null
		and visit.definition != null
		and visit.definition.dialogue_mode == DEF_Customer.DialogueMode.RIDDLE
		and not visit.riddle_solved
	):
		return "riddle"
	return "direct"


func apply_response_tags(tags: Array[String]) -> bool:
	var intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.from_tags(tags)
	if intent == CustomerDialogueIntent.Type.NONE:
		return true
	var visit: CustomerVisit = _visit()
	return CustomerOutcomeService.apply_dialogue_intent(visit, intent)


func commit_denial() -> bool:
	return is_valid() and CustomerFlowService.deny(_visit_id)


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


## R14 will own challenge authority. R12 only exposes the future typed query surface.
func challenge_result() -> StringName:
	return NO_CHALLENGE_RESULT


## R18 will replace this placeholder with its authoritative Hunger tier.
func hunger_tier() -> int:
	return DEFAULT_HUNGER_TIER


## Dialogue always resolves the real line first. R18 may later transform only this presentation result.
func perceived_text(actual_text: String) -> String:
	return actual_text


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
