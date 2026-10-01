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
	if cycle.phase == C_DayCycle.Phase.MORNING:
		for visit: CustomerVisit in CustomerFlowService.current().visits:
			var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
			if PackageReturnService.can_return(parcel):
				var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
				lines.append("Задача Morning: №%03d — держать и вернуть на F во дворе; прежний штраф сохраняется" % state.registration_number)
	var session: Entity = ECS.world.query.with_all([C_Autosave]).execute_one() if is_instance_valid(ECS.world) else null
	if session != null:
		var save: C_Autosave = session.get_component(C_Autosave) as C_Autosave
		lines.append("Сон / autosave: %s · сохранённое утро %d" % [save.startup_status, save.last_saved_morning])
		if save.last_error != OK:
			lines.append("Задача: завершить сохранение · ошибка %d · повтор через %.1f с" % [save.last_error, save.retry_remaining])
		for zone: Entity in ECS.world.query.with_all([C_OrderReceiving]).execute():
			if (zone.get_component(C_OrderReceiving) as C_OrderReceiving).blocked:
				lines.append("Задача: освободить место в зоне утренних заказов")
	return "\n".join(lines)
