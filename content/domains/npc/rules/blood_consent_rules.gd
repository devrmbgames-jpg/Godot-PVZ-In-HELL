extends RefCounted
## Pure validation of personal blood confirmation history, independent of transient NPC bodies.
class_name BloodConsentRules


#region Closed personal receipt validation
static func valid(person: NpcRecord) -> bool:
	if person.blood_offer_sequence != person.blood_offers.size() + 1:
		return false
	for index: int in person.blood_offers.size():
		var record: BloodConsentRecord = person.blood_offers[index]
		if (
			record == null or record.actor_id.is_empty() or record.dealer_id != person.npc_id
			or record.confirmation_key != key_for(person.npc_id, index + 1)
			or record.percent < 5 or record.percent > 40 or record.cooldown_ticks < 0
			or record.cooldown_ticks > 3600 * GameTimeRules.TICKS_PER_SECOND
			or record.next_offer_tick < 0 or not is_finite(record.previous_health)
			or not is_finite(record.applied_amount)
			or record.outcome < BloodConsentRecord.Outcome.OFFERED
			or record.outcome > BloodConsentRecord.Outcome.DECLINED
		):
			return false
		if record.outcome == BloodConsentRecord.Outcome.OFFERED:
			if index != person.blood_offers.size() - 1 or record.next_offer_tick != 0:
				return false
		elif record.next_offer_tick < record.cooldown_ticks:
			return false
		if record.outcome == BloodConsentRecord.Outcome.ACCEPTED:
			if (
				record.previous_health <= 0.0 or record.applied_amount <= 0.0
				or not is_equal_approx(
					record.applied_amount,
					record.previous_health * record.percent / 100.0,
				)
				or record.applied_amount >= record.previous_health
			):
				return false
		elif record.previous_health != 0.0 or record.applied_amount != 0.0:
			return false
	return true


## Person-owned sequence survives body replacement, days and save/load.
static func key_for(person_id: StringName, sequence: int) -> StringName:
	return StringName("blood/%s/%d" % [person_id, sequence])
#endregion
