extends "res://tests/gut/test_district_plan_acceptance.gd"
## Регрессии прерывания нативных деревьев и освобождения живых резервов постоянного NPC.

#region Отключение участия
## Уход обслуживаемого NPC прерывает дерево и освобождает стойку и разговор.
func test_disabled_service_aborts_tree_and_releases_bindings() -> void:
	DayPhaseService.current().phase = C_DayCycle.Phase.DAY
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	var visit: CustomerVisit = _service(body, "disabled_counter")
	NpcServiceRole.claim_counter(body)
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var context: CustomerDialogueContext = CustomerDialogueContext.new(player, body)
	assert_true(context.begin())
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	var root_task: BTTask = runner.get_bt_instance().get_root_task()
	assert_eq(root_task.get_status(), BTTask.RUNNING)

	DistrictPopulationService.set_placement(_district.people[0], body, NpcRecord.Placement.HOME)
	assert_false(runner.active)
	assert_eq(root_task.get_status(), BTTask.FRESH)
	assert_false(body.has_component(C_CustomerAgent))
	assert_null(NpcDialogueService.participant(body))
	assert_eq(body.get_relationships(Relationship.new(R_NpcServiceAt.new(), CustomerFlowService.counter())).size(), 0)
	assert_eq(body.get_relationships(Relationship.new(R_NpcWaitingAt.new(), CustomerFlowService.counter())).size(), 0)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(visit.next_followup_day, DayPhaseService.current().day_index + 1)
	assert_false(context.can_continue())

## Уход с домашней встречи снимает резерв двери без выдуманной выдачи или срыва обещания.
func test_disabled_home_meeting_releases_door_without_false_delivery() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	var visit: CustomerVisit = _service(body, "disabled_home")
	NpcServiceRole.release(body, visit.visit_id)
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	var job: NpcHomeDelivery = NpcHomeDelivery.new()
	job.job_id = &"home/test/disabled"
	job.npc_id = _district.people[0].npc_id
	job.visit_id = visit.visit_id
	job.address_id = _district.people[0].home_id
	_district.home_deliveries.append(job)
	var door: Entity = null
	for candidate: Entity in _world.query.with_all([C_NpcAddress]).execute():
		if (candidate.get_component(C_NpcAddress) as C_NpcAddress).address_id == job.address_id:
			door = candidate
	assert_true(NpcHomeDeliveryService.knock(player, door))
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	DistrictPopulationService.set_placement(_district.people[0], body, NpcRecord.Placement.OUTSIDE)
	assert_null(NpcHomeDeliveryService.meeting_for(body))
	assert_null(NpcHomeDeliveryService.door_for(body))
	assert_false(body.has_component(C_CustomerAgent))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)

## Обратное включение исполняет свежую ветку тем же BTPlayer и тем же телом.
func test_return_resumes_the_same_tree_without_old_movement() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.phase_complete = false
	person.goal_id = person.exit_id
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	assert_true((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	assert_same(body.get_node("Brain"), runner)
	assert_true(runner.active)
	assert_eq(runner.get_bt_instance().get_root_task().get_status(), BTTask.FRESH)
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	assert_eq((body.get_component(C_NpcDecision) as C_NpcDecision).intent_owner, C_NpcDecision.Owner.SCHEDULE)
#endregion

#region Прерывание и продолжение действий
## Встроенное ожидание после отмены расписания не оставляет движение прежнего листа.
func test_native_wait_after_cancelled_schedule_stops_old_movement() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.phase_complete = false
	person.goal_id = person.exit_id
	var runner: BTPlayer = _movement_then_wait(body)
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	decision.intent_owner = C_NpcDecision.Owner.NONE
	assert_true(NpcBrainService.update_tree(body, 0.2))
	assert_true((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	person.phase_complete = true
	decision.intent_owner = C_NpcDecision.Owner.NONE
	assert_false(NpcBrainService.update_tree(body, 0.2))
	assert_eq(runner.get_bt_instance().get_root_task().get_status(), BTTask.RUNNING)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert_eq(decision.active_task_id, 0)

## Поздний _exit прежнего движения не останавливает движение новой аварийной ветки.
func test_emergency_preemption_keeps_new_movement() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.phase_complete = false
	person.goal_id = person.exit_id
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var previous_task: int = decision.active_task_id
	(body.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing = true
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	assert_eq(decision.intent_owner, C_NpcDecision.Owner.EMERGENCY)
	assert_ne(decision.active_task_id, previous_task)
	assert_true((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)

## Поиск использует последний контакт, а истечение срока снимает скрытую цель.
func test_lost_target_search_uses_last_contact_and_finishes() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player(Vector3(0, 0, -40))
	assert_true(CombatService.bind_target(body, player))
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.target_visible = false
	awareness.has_last_seen = true
	awareness.last_seen_position = Vector3(2, 0, -3)
	assert_true(_run_branch(body, C_NpcDecision.Owner.COMBAT, 0.2))
	assert_eq((body.get_component(C_NpcIntent) as C_NpcIntent).move_position, awareness.last_seen_position)
	player.place_at(Vector3(-40, 0, 40))
	assert_true(_run_branch(body, C_NpcDecision.Owner.COMBAT, 0.2))
	assert_eq((body.get_component(C_NpcIntent) as C_NpcIntent).move_position, awareness.last_seen_position)
	awareness.search_elapsed = _district.people[0].profile.search_seconds
	assert_true(_run_branch(body, C_NpcDecision.Owner.COMBAT, 0.2))
	assert_null(CombatService.target_for(body))
	assert_false(awareness.has_last_seen)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)

## Повторные такты сохраняют замах; смерть цели прекращает атаку и освобождает связь.
func test_running_attack_keeps_elapsed_across_tree_updates() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player(Vector3(0, 0, -1.2))
	var combat: C_NpcCombat = body.get_component(C_NpcCombat) as C_NpcCombat
	combat.melee_attacks = [load("res://content/definitions/gameplay/combat/def_npc_punch.tres") as DEF_NpcAttack]
	assert_true(CombatService.bind_target(body, player))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(NpcAttackService.start(body, C_NpcCombat.Kind.MELEE, 0))
	NpcAttackService.tick(body, 0.1)
	var attack: DEF_NpcAttack = combat.attack
	var elapsed: float = combat.elapsed
	(body.get_component(C_NpcAwareness) as C_NpcAwareness).target_visible = true
	for step: int in 3:
		assert_true(_run_branch(body, C_NpcDecision.Owner.COMBAT, 0.2))
		assert_same(combat.attack, attack)
		assert_eq(combat.elapsed, elapsed)
		assert_eq(combat.phase, C_NpcCombat.Phase.WINDUP)
	player.add_component(C_Death.new())
	assert_true(_run_branch(body, C_NpcDecision.Owner.COMBAT, 0.2))
	assert_null(CombatService.target_for(body))
	assert_eq(combat.phase, C_NpcCombat.Phase.READY)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)

## Смерть собеседника исключает разговор и снимает его живую связь при выходе листа.
func test_dead_listener_closes_conversation_on_tree_exit() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	body.add_relationship(Relationship.new(R_NpcConversation.new(), player))
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	player.add_component(C_Death.new())
	assert_null(NpcDialogueService.participant(body))
	assert_true(_run_tree(body, NpcBrainService.TREE_PATH, 0.2))
	assert_eq(body.get_relationships(Relationship.new(R_NpcConversation.new(), player)).size(), 0)

## Уход из собственной ветки расписания завершает такт до abort, без повторного исполнения.
func test_schedule_departure_aborts_after_its_own_tick() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.DAY
	person.profile.schedule = person.profile.schedule.duplicate() as DEF_NpcSchedule
	person.profile.schedule.day = DEF_NpcSchedule.Location.OUTSIDE
	assert_true(DistrictPopulationService.request_phase(body, cycle.day_index, cycle.phase).succeeded)
	body.place_at(DistrictPopulationService.position_for(person.goal_id) + Vector3(0.4, 0, 0))
	NpcBrainService.tick(_district, 0.3)
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	assert_eq(person.placement, NpcRecord.Placement.OUTSIDE)
	assert_false(runner.active)
	assert_eq(runner.get_bt_instance().get_root_task().get_status(), BTTask.FRESH)
	assert_false(decision.tree_updating)
	assert_eq(decision.active_task_id, 0)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
#endregion

#region Нативная композиция для проверки прерывания
func _movement_then_wait(body: E_DistrictNpc) -> BTPlayer:
	var condition: BTCondition = BTCondition.new()
	condition.set_script(load("res://content/ai/tasks/bt_npc_has_schedule.gd") as Script)
	var movement: BTAction = BTAction.new()
	movement.set_script(load("res://content/ai/tasks/bt_npc_move_schedule.gd") as Script)
	movement.set("intent_owner", C_NpcDecision.Owner.SCHEDULE)
	var branch: BTDynamicSequence = BTDynamicSequence.new()
	var branch_children: Array[BTTask] = [condition, movement]
	branch.set("children", branch_children)
	var selector: BTDynamicSelector = BTDynamicSelector.new()
	var priorities: Array[BTTask] = [branch, BTWait.new()]
	selector.set("children", priorities)
	var tree: BehaviorTree = BehaviorTree.new()
	tree.set("root_task", selector)
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	runner.behavior_tree = tree
	return runner
#endregion
