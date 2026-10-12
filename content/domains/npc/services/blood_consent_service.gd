extends RefCounted
## Explicit personal blood offers; durable district receipts own idempotency and cooldown.
class_name BloodConsentService


#region Read-only capability and pending offer views
static func rule_for(dealer: Entity) -> DEF_NpcBloodConsent:
	var identity: C_NpcIdentity = dealer.get_component(C_NpcIdentity) as C_NpcIdentity
	if identity == null:
		return null
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	for rule: DEF_NpcTrait in person.rules_for():
		if rule is DEF_NpcBloodConsent:
			return rule as DEF_NpcBloodConsent
	return null


## Finds a durable receipt without allocating confirmation IDs or reading transient UI lines.
static func receipt_for(dealer: Entity, key: StringName) -> BloodConsentRecord:
	var person: NpcRecord = _person(dealer)
	if person == null:
		return null
	for record: BloodConsentRecord in person.blood_offers:
		if record.confirmation_key == key:
			return record
	return null


## Observes current participants, captured pending terms and the saved simulation deadline.
static func available(actor: Entity, dealer: Entity) -> bool:
	if not _participants(actor, dealer):
		return false
	var person: NpcRecord = _person(dealer)
	var rule: DEF_NpcBloodConsent = rule_for(dealer)
	if not BloodConsentRules.valid(person) or rule == null or not rule.valid_configuration():
		return false
	var current: BloodConsentRecord = _latest(person)
	var percent: int = rule.minimum_percent
	if current != null:
		if current.outcome == BloodConsentRecord.Outcome.OFFERED:
			if current.actor_id != ActorIdentityRules.trace_key_for(actor):
				return false
			percent = current.percent
		elif GameTimeQueries.current().elapsed_ticks < current.next_offer_tick:
			return false
	return HealthConsentTransactionService.can_apply(
		_change(actor, person.npc_id, &"blood/preflight", percent),
	)
#endregion


#region Explicit captured offer and terminal confirmation
## Commits one deterministic percentage; reopening/restoring returns the same pending key.
static func offer(actor: Entity, dealer: Entity) -> BloodConsentRecord:
	if not available(actor, dealer):
		return null
	var person: NpcRecord = _person(dealer)
	var current: BloodConsentRecord = _latest(person)
	if current != null and current.outcome == BloodConsentRecord.Outcome.OFFERED:
		return current
	var rule: DEF_NpcBloodConsent = rule_for(dealer)
	var clock: GameClock = GameTimeQueries.current()
	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		clock.world_seed,
		String(person.npc_id),
		DayPhaseQueries.current().day_index,
		"blood/offer",
		person.blood_offer_sequence,
	)
	var record: BloodConsentRecord = BloodConsentRecord.new()
	record.actor_id = ActorIdentityRules.trace_key_for(actor)
	record.dealer_id = person.npc_id
	record.confirmation_key = BloodConsentRules.key_for(person.npc_id, person.blood_offer_sequence)
	record.percent = random.randi_range(rule.minimum_percent, rule.maximum_percent)
	record.cooldown_ticks = GameTimeRules.duration_ticks(rule.offer_cooldown_seconds)
	person.blood_offer_sequence += 1
	person.blood_offers.append(record)
	return record


## Resolves one displayed offer; terminal replay cannot damage, heal or allocate another offer.
static func submit(request: BloodConsentRequest) -> BloodConsentResult:
	var result: BloodConsentResult = BloodConsentResult.new()
	if request == null:
		return result
	result.confirmation_key = request.confirmation_key
	if (
		not EntityAvailability.contains(request.actor, ECS.world)
		or not EntityAvailability.contains(request.dealer, ECS.world)
		or request.confirmation_key.is_empty()
	):
		return result
	var person: NpcRecord = _person(request.dealer)
	var record: BloodConsentRecord = receipt_for(request.dealer, request.confirmation_key)
	if (
		person == null or not BloodConsentRules.valid(person) or record == null
		or record.actor_id != ActorIdentityRules.trace_key_for(request.actor)
		or record.dealer_id != NpcSocialService.identity_for(request.dealer)
	):
		result.reason = &"offer_mismatch"
		return result
	if record.outcome != BloodConsentRecord.Outcome.OFFERED:
		result.receipt = record
		result.replayed = true
		result.reason = (
			&"accepted" if record.outcome == BloodConsentRecord.Outcome.ACCEPTED else &"declined"
		)
		return result
	if not _participants(request.actor, request.dealer) or rule_for(request.dealer) == null:
		result.reason = &"participants_unavailable"
		return result
	var change: HealthConsentChange = _change(
		request.actor,
		record.dealer_id,
		record.confirmation_key,
		record.percent,
	)
	if request.accept and not HealthConsentTransactionService.can_apply(change):
		result.reason = &"invalid_health"
		return result

	# Seal before common Health property/result callbacks can re-enter, save or retire participants.
	if request.accept:
		record.outcome = BloodConsentRecord.Outcome.ACCEPTED
	else:
		record.outcome = BloodConsentRecord.Outcome.DECLINED
	record.next_offer_tick = GameTimeQueries.current().elapsed_ticks + record.cooldown_ticks
	if request.accept:
		var health: C_Health = request.actor.get_component(C_Health) as C_Health
		record.previous_health = health.current
		record.applied_amount = health.current * change.fraction
	result.receipt = record
	result.reason = &"accepted" if request.accept else &"declined"
	if request.accept:
		HealthConsentTransactionService.commit(change)
	return result
#endregion


#region Synchronous participants and captured terms
static func _person(dealer: Entity) -> NpcRecord:
	var identity: C_NpcIdentity = dealer.get_component(C_NpcIdentity) as C_NpcIdentity
	return NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null


static func _participants(actor: Entity, dealer: Entity) -> bool:
	return (
		EntityAvailability.contains(actor, ECS.world)
		and EntityAvailability.contains(dealer, ECS.world) and actor.enabled and dealer.enabled
		and not actor.has_component(C_Death) and not dealer.has_component(C_Death)
		and dealer is E_DistrictNpc and NpcDialogueService.participant(dealer) == actor
		and NpcDialogueService.valid_participants(actor, dealer as E_DistrictNpc)
	)


static func _latest(person: NpcRecord) -> BloodConsentRecord:
	return person.blood_offers.back() if not person.blood_offers.is_empty() else null


static func _change(
	actor: Entity,
	dealer_id: StringName,
	key: StringName,
	percent: int,
) -> HealthConsentChange:
	var change: HealthConsentChange = HealthConsentChange.new()
	change.target = actor
	change.origin_id = String(dealer_id)
	change.confirmation_key = key
	change.fraction = percent / 100.0
	return change
#endregion
