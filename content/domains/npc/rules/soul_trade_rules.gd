extends RefCounted
## Pure validation of the complete durable soul ledger, including never-reused confirmation IDs.
class_name SoulTradeRules


#region Closed ledger validation
## Requires every receipt to belong to the actor whose authoritative ledger is being restored.
static func valid_for_actor(ledger: C_SoulTrade, actor_id: String) -> bool:
	if not valid(ledger) or actor_id.is_empty():
		return false
	return ledger.offers.is_empty() or ledger.offers[0].actor_id == actor_id


## Rejects malformed terms, unordered keys, impossible counts and ambiguous pending offers.
static func valid(ledger: C_SoulTrade) -> bool:
	if (
		ledger == null or ledger.next_sequence != ledger.offers.size() + 1
		or ledger.accepted_count < 0
	):
		return false
	var accepted: int = 0
	var actor_id: String = ""
	for index: int in ledger.offers.size():
		var record: SoulTradeRecord = ledger.offers[index]
		if (
			record == null or record.actor_id.is_empty() or record.dealer_id.is_empty()
			or not is_finite(record.strength_gain) or record.strength_gain <= 0.0
			or not is_finite(record.maximum_health_cost) or record.maximum_health_cost <= 0.0
			or record.fatal_deal_count < 1 or record.fatal_deal_count > 100
			or record.cooldown_ticks < 0
			or record.cooldown_ticks > 3600 * GameTimeRules.TICKS_PER_SECOND
			or record.next_offer_tick < 0 or record.outcome < SoulTradeRecord.Outcome.OFFERED
			or record.outcome > SoulTradeRecord.Outcome.DECLINED
		):
			return false
		if index == 0:
			actor_id = record.actor_id
		if (
			record.actor_id != actor_id
			or record.confirmation_key != StringName("soul/%s/%d" % [actor_id, index + 1])
		):
			return false
		if record.outcome == SoulTradeRecord.Outcome.OFFERED:
			if (
				index != ledger.offers.size() - 1 or record.next_offer_tick != 0
				or record.fatal or record.accepted_count != 0
			):
				return false
		else:
			accepted += 1 if record.outcome == SoulTradeRecord.Outcome.ACCEPTED else 0
			if (
				record.accepted_count != accepted or record.next_offer_tick < record.cooldown_ticks
				or record.fatal
				!= (
					record.outcome == SoulTradeRecord.Outcome.ACCEPTED
					and accepted >= record.fatal_deal_count
				)
				or (record.fatal and index != ledger.offers.size() - 1)
			):
				return false
	return ledger.accepted_count == accepted
#endregion
