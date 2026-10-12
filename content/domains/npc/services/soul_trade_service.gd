extends RefCounted
## Explicit soul offers and receipts; the ledger owns history and common stat transactions commit.
class_name SoulTradeService


#region Read-only capability and ledger views
## Finds a selected typed soul capability without using an archetype-name switch.
static func rule_for(dealer: Entity) -> DEF_NpcSoulTrade:
	var identity: C_NpcIdentity = dealer.get_component(C_NpcIdentity) as C_NpcIdentity
	if identity == null:
		return null
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	for rule: DEF_NpcTrait in person.rules_for():
		if rule is DEF_NpcSoulTrade:
			return rule as DEF_NpcSoulTrade
	return null


## Reads a receipt or pending offer from the current player ledger.
static func receipt_for(actor: Entity, key: StringName) -> SoulTradeRecord:
	var ledger: C_SoulTrade = actor.get_component(C_SoulTrade) as C_SoulTrade
	if ledger == null:
		return null
	for offer: SoulTradeRecord in ledger.offers:
		if offer.confirmation_key == key:
			return offer
	return null


## Observes eligibility and the dealer's saved deadline without allocating or changing an offer.
static func available(actor: Entity, dealer: Entity) -> bool:
	if not _participants(actor, dealer):
		return false
	var ledger: C_SoulTrade = actor.get_component(C_SoulTrade) as C_SoulTrade
	var rule: DEF_NpcSoulTrade = rule_for(dealer)
	if not SoulTradeRules.valid(ledger) or rule == null or not rule.valid_configuration():
		return false
	var dealer_id: StringName = NpcSocialService.identity_for(dealer)
	if not ledger.offers.is_empty():
		var pending: SoulTradeRecord = ledger.offers.back()
		if pending.actor_id != ActorIdentityRules.trace_key_for(actor):
			return false
		if pending.outcome == SoulTradeRecord.Outcome.OFFERED and pending.dealer_id != dealer_id:
			return false
	var current: SoulTradeRecord = _latest(ledger, dealer_id)
	if current != null and current.outcome == SoulTradeRecord.Outcome.OFFERED:
		return CharacterStatsTransactionService.can_apply(_change(actor, current, ledger))
	return (
		(current == null or GameTimeQueries.current().elapsed_ticks >= current.next_offer_tick)
		and CharacterStatsTransactionService.can_apply(_preview(actor, dealer_id, rule))
	)
#endregion


#region Explicit offer creation and resolution
## Allocates captured terms once, or returns the unresolved offer after UI closure/save restoration.
static func offer(actor: Entity, dealer: Entity) -> SoulTradeRecord:
	if not available(actor, dealer):
		return null
	var ledger: C_SoulTrade = actor.get_component(C_SoulTrade) as C_SoulTrade
	var dealer_id: StringName = NpcSocialService.identity_for(dealer)
	var current: SoulTradeRecord = _latest(ledger, dealer_id)
	if current != null and current.outcome == SoulTradeRecord.Outcome.OFFERED:
		return current
	var rule: DEF_NpcSoulTrade = rule_for(dealer)
	var record: SoulTradeRecord = SoulTradeRecord.new()
	record.actor_id = ActorIdentityRules.trace_key_for(actor)
	record.dealer_id = dealer_id
	record.confirmation_key = StringName("soul/%s/%d" % [record.actor_id, ledger.next_sequence])
	record.strength_gain = rule.strength_gain
	record.maximum_health_cost = rule.maximum_health_cost
	record.fatal_deal_count = rule.fatal_deal_count
	record.cooldown_ticks = GameTimeRules.duration_ticks(rule.offer_cooldown_seconds)
	ledger.next_sequence += 1
	ledger.offers.append(record)
	return record


## Resolves synchronously; a terminal key never repeats stats, death or publication.
static func submit(request: SoulTradeRequest) -> SoulTradeResult:
	var result: SoulTradeResult = SoulTradeResult.new()
	if request == null:
		return result
	result.confirmation_key = request.confirmation_key
	if (
		not EntityAvailability.contains(request.actor, ECS.world)
		or not EntityAvailability.contains(request.dealer, ECS.world)
		or request.confirmation_key.is_empty()
	):
		return result
	var ledger: C_SoulTrade = request.actor.get_component(C_SoulTrade) as C_SoulTrade
	var record: SoulTradeRecord = receipt_for(request.actor, request.confirmation_key)
	if (
		not SoulTradeRules.valid(ledger) or record == null
		or record.actor_id != ActorIdentityRules.trace_key_for(request.actor)
		or record.dealer_id != NpcSocialService.identity_for(request.dealer)
	):
		result.reason = &"offer_mismatch"
		return result
	if record.outcome != SoulTradeRecord.Outcome.OFFERED:
		result.receipt = record
		result.replayed = true
		if record.outcome == SoulTradeRecord.Outcome.ACCEPTED:
			result.reason = &"accepted"
		else:
			result.reason = &"declined"
		return result
	if not _participants(request.actor, request.dealer) or rule_for(request.dealer) == null:
		result.reason = &"participants_unavailable"
		return result
	var change: CharacterStatsChange = _change(request.actor, record, ledger)
	if request.accept and not CharacterStatsTransactionService.can_apply(change):
		result.reason = &"invalid_attributes"
		return result

	var world: World = ECS.world
	var actor_reference: WeakRef = weakref(request.actor)
	# Commit the terminal key before any common damage/result/property callback can re-enter.
	if request.accept:
		record.outcome = SoulTradeRecord.Outcome.ACCEPTED
	else:
		record.outcome = SoulTradeRecord.Outcome.DECLINED
	if request.accept:
		ledger.accepted_count += 1
	record.accepted_count = ledger.accepted_count
	record.fatal = request.accept and change.forfeit_life
	record.next_offer_tick = GameTimeQueries.current().elapsed_ticks + record.cooldown_ticks
	result.receipt = record
	result.reason = &"accepted" if request.accept else &"declined"
	if request.accept:
		CharacterStatsTransactionService.commit(change)
	# The stat publication can retire the player; the durable receipt is still authoritative.
	var actor: Entity = actor_reference.get_ref() as Entity
	world.emit_event(SoulTradeResult.EVENT, actor, result)
	return result
#endregion


#region Captured terms and participant boundary
static func _participants(actor: Entity, dealer: Entity) -> bool:
	return (
		EntityAvailability.contains(actor, ECS.world)
		and EntityAvailability.contains(dealer, ECS.world) and actor.enabled and dealer.enabled
		and not actor.has_component(C_Death) and not dealer.has_component(C_Death)
		and NpcDialogueService.participant(dealer) == actor and dealer is E_DistrictNpc
		and NpcDialogueService.valid_participants(actor, dealer as E_DistrictNpc)
	)


static func _latest(ledger: C_SoulTrade, dealer_id: StringName) -> SoulTradeRecord:
	for index: int in range(ledger.offers.size() - 1, -1, -1):
		var record: SoulTradeRecord = ledger.offers[index]
		if record.dealer_id == dealer_id:
			return record
	return null


static func _preview(
	actor: Entity,
	dealer_id: StringName,
	rule: DEF_NpcSoulTrade,
) -> CharacterStatsChange:
	var change: CharacterStatsChange = CharacterStatsChange.new()
	change.target = actor
	change.origin_id = String(dealer_id)
	change.confirmation_key = &"soul/preflight"
	change.strength_delta = rule.strength_gain
	change.maximum_health_delta = -rule.maximum_health_cost
	return change


static func _change(
	actor: Entity,
	record: SoulTradeRecord,
	ledger: C_SoulTrade,
) -> CharacterStatsChange:
	var change: CharacterStatsChange = CharacterStatsChange.new()
	change.target = actor
	change.origin_id = String(record.dealer_id)
	change.confirmation_key = record.confirmation_key
	change.strength_delta = record.strength_gain
	change.maximum_health_delta = -record.maximum_health_cost
	change.forfeit_life = ledger.accepted_count + 1 >= record.fatal_deal_count
	return change
#endregion
