extends RefCounted
## Распределяет восприятие и решения между постоянными NPC с нативными деревьями LimboAI.
class_name NpcBrainService

const TREE_PATH: String = "res://content/ai/trees/bt_district_npc.tres"

#region Жизненный цикл AI
## Создаёт производные сенсоры и единственный BTPlayer с ручным обновлением.
static func install(actor: E_DistrictNpc) -> void:
	var profile_identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = DistrictPopulationService.person_for(profile_identity.npc_id)
	if person != null:
		NpcTraitService.install(actor, person.profile)
	if not actor.has_component(C_NpcAwareness):
		actor.add_component(C_NpcAwareness.new())
	if not actor.has_component(C_NpcDecision):
		var decision: C_NpcDecision = C_NpcDecision.new()
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		var district: C_District = DistrictPopulationService.current()
		decision.update_elapsed = float(abs(hash(identity.npc_id)) % 10) / 10.0 * district.definition.decision_interval
		actor.add_component(decision)

	var combat: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if combat != null:
		if person != null:
			combat.melee_attacks.assign(person.profile.melee_attacks)
			combat.ranged_attacks.assign(person.profile.ranged_attacks)
		combat.automatic_attack_selection = false
	if actor.get_node_or_null("Brain") != null:
		return

	var runner: BTPlayer = BTPlayer.new()
	runner.name = "Brain"
	runner.update_mode = BTPlayer.MANUAL
	runner.set_scene_root_hint(ECS.world.get_parent())
	runner.behavior_tree = load(TREE_PATH) as BehaviorTree
	actor.add_child(runner)

## Включает дерево либо прерывает его листья; из выполняющегося такта abort завершается после update.
static func set_participating(actor: E_DistrictNpc, participating: bool) -> void:
	var runner: BTPlayer = actor.get_node_or_null("Brain") as BTPlayer
	if runner == null:
		return
	runner.active = participating
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if not participating and (decision == null or not decision.tree_updating):
		_abort_tree(actor, runner)

## Исполняет один такт BT и безопасно завершает отключение; возвращает факт выбранного действия.
static func update_tree(actor: E_DistrictNpc, delta: float) -> bool:
	var runner: BTPlayer = actor.get_node_or_null("Brain") as BTPlayer
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if runner == null or decision == null or not runner.active:
		return false
	decision.tree_updating = true
	runner.update(delta)
	decision.tree_updating = false
	var claimed: bool = decision.intent_owner != C_NpcDecision.Owner.NONE
	if not runner.active:
		_abort_tree(actor, runner)
	return claimed

static func _abort_tree(actor: E_DistrictNpc, runner: BTPlayer) -> void:
	var instance: BTInstance = runner.get_bt_instance()
	if instance != null:
		instance.get_root_task().abort()
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision != null:
		decision.active_task_id = 0
		decision.intent_owner = C_NpcDecision.Owner.NONE
		decision.active_behavior = ""

## Обновляет согласованное восприятие, затем каждое нативное дерево решений.
static func tick(district: C_District, delta: float) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return

	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if player != null:
		NpcPerceptionService.footsteps(player, delta)
	var due: Array[E_DistrictNpc] = []
	for person: NpcRecord in district.people:
		if person.death_day != 0 or person.placement != NpcRecord.Placement.STREET:
			continue

		var actor: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if actor == null:
			continue
		if not actor.has_component(C_NpcDecision) or not actor.has_component(C_NpcAwareness) or actor.get_node_or_null("Brain") == null:
			install(actor)
		var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
		decision.update_elapsed += maxf(0.0, delta)
		if decision.update_elapsed < district.definition.decision_interval:
			continue

		NpcPerceptionService.footsteps(actor, decision.update_elapsed)
		NpcPerceptionService.sense(actor, person, player, decision.update_elapsed)
		NpcTraitService.tick(actor, person, player, decision.update_elapsed)
		due.append(actor)
	for actor: E_DistrictNpc in due:
		var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
		var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
		var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
		if decision.intent_owner == C_NpcDecision.Owner.IDLE and not (intent.movement_active and not intent.arrived):
			awareness.idle_elapsed += decision.update_elapsed
		# Perception has committed; role clocks consume this exact due-step delta before BT.
		ECS.world.emit_event(NpcDecisionReady.EVENT, actor, NpcDecisionReady.new(decision.update_elapsed))
		decision.intent_owner = C_NpcDecision.Owner.NONE
		update_tree(actor, decision.update_elapsed)
		if not actor.enabled:
			decision.update_elapsed = 0.0
			continue
		if decision.intent_owner != C_NpcDecision.Owner.IDLE:
			NpcCommunityService.cancel_activity(actor)
		if decision.intent_owner in [C_NpcDecision.Owner.EMERGENCY, C_NpcDecision.Owner.COMBAT]:
			NpcDialogueService.end(actor)
			NpcServiceRole.suspend(actor)
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		NpcRouteService.tick(actor, DistrictPopulationService.person_for(identity.npc_id), decision.update_elapsed)
		decision.update_elapsed = 0.0
	NpcRouteService.process_pending(district)
	for noise: NpcNoise in district.noises.duplicate():
		noise.remaining -= maxf(0.0, delta)
		if noise.remaining <= 0.0:
			district.noises.erase(noise)
#endregion
