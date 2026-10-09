extends RefCounted
## Адаптирует диалоговые решения и последствия домашнего обещания к памяти NPC.
class_name CustomerSocialService

#region Диалог и обещания
## Применяет смысл диалогового выбора, не изменяя расчёты посылки.
static func dialogue_response(body: E_DistrictNpc, actor: Entity, intent: CustomerDialogueIntent.Type, incident: StringName) -> NpcMemory.Reaction:
	var kind: NpcMemory.Kind = NpcMemory.Kind.HELP
	match intent:
		CustomerDialogueIntent.Type.THREAT:
			kind = NpcMemory.Kind.THREAT
		CustomerDialogueIntent.Type.LIE:
			kind = NpcMemory.Kind.LIE
		CustomerDialogueIntent.Type.JOKE:
			kind = NpcMemory.Kind.JOKE
	return NpcSocialService.react(body, actor, kind, incident)

## Находит ещё не применённую личную реакцию, независимо от нового заказа NPC.
static func pending_promise(body: E_DistrictNpc) -> NpcHomeDelivery:
	var district: C_District = NpcPopulationQueries.current()
	if body == null or district == null:
		return null
	var npc_id: StringName = NpcSocialService.identity_for(body)
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.npc_id == npc_id and job.source == NpcHomeDelivery.Source.PERSONAL and job.status == NpcHomeDelivery.Status.FAILED and not job.promise_reaction_applied:
			return job
	return null

## Применяет сохранённую реакцию при распознанном разговоре; повтор и загрузка не перебрасывают её.
static func resolve_promise(body: E_DistrictNpc, actor: Entity) -> bool:
	var job: NpcHomeDelivery = pending_promise(body)
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	if job == null or person == null or person.death_day != 0 or NpcDialogueService.participant(body) != actor:
		return false

	for memory: NpcMemory in person.memories:
		if memory.incident_id != job.job_id:
			continue

		job.promise_reaction_applied = true
		NpcDialogueService.close_for(body)
		NpcSocialService.apply_reaction(body, actor, memory.reaction)
		if memory.reaction == NpcMemory.Reaction.TALK:
			body.show_message("Я запомнил твоё обещание. Больше личных доставок тебе не доверю.")
		return true
	return false
#endregion
