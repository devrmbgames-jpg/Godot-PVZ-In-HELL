extends NpcDialogueContext
## Typed read/action adapter exposed to DialogueManager as the "ctx" game state.
## Persistent authority remains in CustomerVisit, package state, and gameplay services.
class_name CustomerDialogueContext

const NO_COMPLAINT: int = -1
const NO_CHALLENGE_RESULT: StringName = &""
const DEFAULT_HUNGER_TIER: int = 0

var _actor: Entity = null
var _customer: E_Customer = null
var _visit_id: StringName = &""


#region Conversation lifecycle
func _init(actor: Entity, customer: E_Customer) -> void:
	super(actor, customer)
	_actor = actor
	_customer = customer
	var agent: C_CustomerAgent = _agent()
	if agent != null:
		_visit_id = agent.visit_id


## Enters the bounded R11 dialogue phase. The patience timeout remains authoritative.
func begin() -> bool:
	if not is_valid() or NpcDialogueService.participant(_customer) != null:
		return false
	if not CustomerFlowService.enter_service_phase(_customer, C_CustomerAgent.Phase.DIALOGUE):
		return false

	_customer.add_relationship(Relationship.new(R_NpcConversation.new(), _actor))
	return true


## Returns a manually closed conversation to package service without reviving a leaving/dead NPC.
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
		# Panel releases modal capture before calling end(). The timer therefore
		# starts with movement/interaction already returned to the player.
		ChallengeService.activate(_customer)


## True only while the same live CustomerVisit is still eligible for this conversation.
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


## Requires the same live interlocutor and an uninterrupted service phase.
func can_continue() -> bool:
	var agent: C_CustomerAgent = _agent()
	var awareness: C_NpcAwareness = _customer.get_component(C_NpcAwareness) as C_NpcAwareness if is_instance_valid(_customer) else null
	return is_valid() and NpcDialogueService.participant(_customer) == _actor and agent.phase == C_CustomerAgent.Phase.DIALOGUE and CombatService.target_for(_customer) == null and (awareness == null or not awareness.fleeing)


#endregion

#region Dialogue and parcel adapter
## Returns the current player-controlled phase.
func day_phase() -> int:
	var cycle: C_DayCycle = DayPhaseService.current()
	return cycle.phase if cycle != null else C_DayCycle.Phase.NIGHT


## Reads the permanent person's interests or the legacy recipient policy.
func interests_text() -> String:
	var visit: CustomerVisit = _visit()
	var identity: C_NpcIdentity = _customer.get_component(C_NpcIdentity) as C_NpcIdentity if is_instance_valid(_customer) else null
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id) if identity != null else null
	return ", ".join(person.profile.interests) if person != null else ", ".join(visit.definition.interests) if visit != null and visit.definition != null else ""


## Returns the active service phase.
func customer_phase() -> int:
	var agent: C_CustomerAgent = _agent()
	return agent.phase if agent != null else C_CustomerAgent.Phase.FINISHED


## Reports case satisfaction using existing settlement rules.
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


## Selects intrinsic personality rules while preserving parcel outcome branches.
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


## Applies parcel policy and stable social meaning, including explicit submission.
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


## Whether this recipient can offer a real registered parcel for tonight.
func can_offer_delivery() -> bool:
	return _customer is E_DistrictNpc and NpcHomeDeliveryService.offer_for(_customer as E_DistrictNpc) != null


## Accepts the optional service through its authoritative owner.
func accept_home_delivery() -> bool:
	return _customer is E_DistrictNpc and NpcHomeDeliveryService.accept(_customer as E_DistrictNpc)


## Commits a player refusal through the parcel service.
func commit_denial() -> bool:
	return is_valid() and CustomerFlowService.deny(_visit_id)


## Defers the case without changing permanent identity.
func defer_until_tomorrow() -> bool:
	return is_valid() and CustomerFlowService.defer_until_next_day(_visit_id)


## Reports whether this case has already appeared.
func is_followup() -> bool:
	var visit: CustomerVisit = _visit()
	return visit != null and visit.visit_count > 1


## Applies the wrong-answer consequence once.
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


## Unlocks the real order number without replacing the order.
func answer_riddle_correct() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false

	visit.riddle_solved = true
	return true


## Requests the existing physical recipient refusal.
func voluntary_refuse() -> bool:
	return is_valid() and CustomerFlowService.voluntary_refuse(_customer)


## Creates the existing non-delivery complaint once.
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


## Detects a false terminal declaration.
func false_taken_detected() -> bool:
	var visit: CustomerVisit = _visit()
	return (
		visit != null
		and visit.declaration == CustomerVisit.Declaration.TAKEN
		and visit.actual != CustomerVisit.Actual.DELIVERED
		and visit.aggressive
	)


## Delegates a false declaration to the escalation owner.
func enter_aggressive() -> bool:
	return false_taken_detected() and CustomerFlowService.enter_aggressive(_customer)


## Returns the exact parcel identity for the case.
func requested_package_id() -> String:
	var visit: CustomerVisit = _visit()
	return visit.package_id if visit != null else ""


## Reads the physical service outcome.
func package_actual_outcome() -> int:
	var visit: CustomerVisit = _visit()
	return visit.actual if visit != null else CustomerVisit.Actual.NOT_RESOLVED


## Reads the player's journal declaration.
func terminal_declaration() -> int:
	var visit: CustomerVisit = _visit()
	return visit.declaration if visit != null else CustomerVisit.Declaration.NONE


## Reads the complaint resolution.
func complaint_outcome() -> int:
	var visit: CustomerVisit = _visit()
	if visit == null or visit.complaint == null:
		return NO_COMPLAINT
	return visit.complaint.outcome


## Reports whether the case has a complaint.
func has_complaint() -> bool:
	var visit: CustomerVisit = _visit()
	return visit != null and visit.complaint != null


## Reads the complaint reason.
func complaint_reason() -> int:
	var visit: CustomerVisit = _visit()
	if visit == null or visit.complaint == null:
		return NO_COMPLAINT
	return visit.complaint.reason


## Reports an unresolved complaint.
func complaint_pending() -> bool:
	var visit: CustomerVisit = _visit()
	return (
		visit != null
		and visit.complaint != null
		and visit.complaint.outcome == CustomerComplaint.Outcome.PENDING
	)


## Reads recorded or current physical opening state.
func package_opened() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false
	if visit.package_opened:
		return true

	var state: C_PackageState = _requested_package_state()
	return state != null and state.opening == C_PackageState.Opening.OPENED


## Reads recorded or current physical damage state.
func package_damaged() -> bool:
	var visit: CustomerVisit = _visit()
	if visit == null:
		return false
	if visit.package_damaged:
		return true

	var state: C_PackageState = _requested_package_state()
	return state != null and state.damage != C_PackageState.Damage.UNDAMAGED


## Reports whether registration assigned a real number.
func has_registered_number() -> bool:
	return package_number() > 0


## Looks up the registration of the exact parcel.
func package_number() -> int:
	var visit: CustomerVisit = _visit()
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if visit == null or ledger == null:
		return 0

	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == visit.package_id and record.active:
			return record.number
	return 0


## Formats the existing registration number.
func package_number_text() -> String:
	var number: int = package_number()
	return "%03d" % number if number > 0 else "---"


## Reads the legacy challenge outcome.
func challenge_result() -> StringName:
	return ChallengeResult.key(ChallengeService.result_for(_customer))


## Reports a legacy challenge; district NPCs use intrinsic rules.
func has_pending_challenge() -> bool:
	if not is_valid():
		return false

	var state: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	return (
		state != null and state.definition != null and state.definition.condition != null
		and state.definition.trigger == DEF_Challenge.Trigger.AFTER_DIALOGUE
		and state.phase == C_Challenge.Phase.INACTIVE and not state.consumed
	)


## Presents the legacy challenge warning.
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


## Arms the legacy challenge through its gameplay owner.
func arm_challenge() -> bool:
	return has_pending_challenge() and ChallengeService.arm(_customer, _actor)


## Derived tier only; the context never changes Hunger or customer identity.
func hunger_tier() -> int:
	return HungerService.tier(_actor.get_component(C_Hunger) as C_Hunger) if is_instance_valid(_actor) else DEFAULT_HUNGER_TIER


## Dialogue resolves the real line/branch first; only perceived NPC speech changes.
func perceived_text(actual_text: String) -> String:
	return "Съешь меня" if hunger_tier() == C_Hunger.Tier.STARVING and not actual_text.is_empty() else actual_text


#endregion

#region Case lookups
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
