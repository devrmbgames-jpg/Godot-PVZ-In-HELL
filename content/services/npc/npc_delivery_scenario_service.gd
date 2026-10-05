extends RefCounted
## Исполняет одну авторскую домашнюю засаду; условия и выбор боя принадлежат LimboAI.
class_name NpcDeliveryScenarioService

#region Авторский сценарий
## Читает определение назначенного сценария, не раскрывая его терминалу.
static func definition_for(job: NpcHomeDelivery) -> DEF_NpcDeliveryScenario:
	var district: C_District = DistrictPopulationService.current()
	if job == null or district == null or job.scenario_id.is_empty():
		return null
	var scenario: DEF_NpcDeliveryScenario = district.definition.personal_delivery_scenario
	return scenario if scenario != null and scenario.key == job.scenario_id else null

## Наблюдает только живую домашнюю встречу с ещё не сработавшим сценарием.
static func armed_for(body: E_DistrictNpc) -> NpcHomeDelivery:
	var job: NpcHomeDelivery = NpcHomeDeliveryService.meeting_for(body) if body != null else null
	return job if job != null and job.source == NpcHomeDelivery.Source.PERSONAL and definition_for(job) != null else null
#endregion

#region Запрос боя
## По решению дерева связывает видимого противника и закрывает обязательство без выдачи/штрафа.
static func start_ambush(body: E_DistrictNpc) -> bool:
	var job: NpcHomeDelivery = armed_for(body)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness if body != null else null
	if job == null or awareness == null or not awareness.player_visible or NpcDialogueService.participant(body) != null:
		return false

	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if not GrabService.holder_available(player):
		return false
	if not CombatService.bind_target(body, player):
		return false

	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	var scenario: DEF_NpcDeliveryScenario = definition_for(job)
	job.status = NpcHomeDelivery.Status.AMBUSHED
	awareness.last_seen_position = (player as Node as Node3D).global_position
	awareness.has_last_seen = true
	awareness.search_elapsed = 0.0

	ChallengeService.cancel(body)
	NpcHomeDeliveryService.release_meeting(body)
	NpcServiceRole.release(body, job.visit_id)
	if visit != null:
		visit.started = false
		visit.finished = false
		visit.finished_day = 0
		visit.arrival_day = job.deadline_day
		visit.next_followup_day = 0
		visit.followup_committed = false

	body.show_message(scenario.ambush_message)
	return true
#endregion
