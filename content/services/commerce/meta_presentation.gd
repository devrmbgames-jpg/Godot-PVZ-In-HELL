extends RefCounted
class_name MetaPresentation


static func debug_text() -> String:
	var commerce: C_Commerce = CommerceService.current()
	var quests: C_QuestSession = RefusalQuestService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if commerce == null or quests == null or cycle == null:
		return ""
	var lines: PackedStringArray = ["Задача Evening: торговец во дворе; заказ на завтра — в Terminal"]
	for pending: PendingDelivery in commerce.pending_deliveries:
		if not pending.fulfilled:
			lines.append("Заказ %s ×%d · утро дня %d · осталось %d дней" % [pending.item.display_name, pending.quantity, pending.delivery_day, maxi(0, pending.delivery_day - cycle.day_index)])
	for quest: RefusalQuestRecord in quests.records:
		lines.append("Не выдавай №%03d · %s · срок Night дня %d (ещё %d дней)" % [quest.display_number, RefusalQuestRecord.State.keys()[quest.state], quest.deadline_day, maxi(0, quest.deadline_day - cycle.day_index)])
	return "\n".join(lines)
