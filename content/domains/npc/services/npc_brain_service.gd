extends RefCounted
## Binds and advances one native LimboAI runtime over already constructed ECS capability state.
class_name NpcBrainService

## Authored native decision tree installed by the runtime adapter.
const TREE_PATH: String = "res://content/domains/npc/ai/trees/bt_npc_native.tres"


#region Жизненный цикл AI
## Binds one passive manual BTPlayer; required ECS data was already compiled before registration.
static func bind_engine(actor: E_DistrictNpc) -> void:
	assert(
		actor.has_component(C_NpcAwareness) and actor.has_component(C_NpcDecision)
		and actor.has_component(C_NpcRoute),
		"Native brain binding requires compiled sensor/decision capability",
	)
	if actor.get_node_or_null("Brain") != null:
		return

	var runner: BTPlayer = BTPlayer.new()
	runner.name = "Brain"
	runner.update_mode = BTPlayer.MANUAL
	runner.set_scene_root_hint(ECS.world.get_parent())
	runner.behavior_tree = actor.decision_tree(load(TREE_PATH) as BehaviorTree)
	actor.add_child(runner)


## Включает дерево либо прерывает его листья; из выполняющегося такта abort завершается после
## update.
static func set_participating(actor: E_DistrictNpc, participating: bool) -> void:
	if not participating:
		NpcVeilService.reset(actor)
		var traffic: C_NpcTraffic = actor.get_component(C_NpcTraffic) as C_NpcTraffic
		if traffic != null:
			traffic.reset_transient_state()
		for encounter: Relationship in actor.relationships.duplicate():
			if encounter.relation is R_NpcBlocking:
				actor.remove_relationship(encounter)
		var stalking: C_NpcStalking = actor.get_component(C_NpcStalking) as C_NpcStalking
		if stalking != null:
			NpcStalkingService.cancel(actor)
			stalking.reset_transient_state()
	var runner: BTPlayer = actor.get_node_or_null("Brain") as BTPlayer
	if runner == null:
		return
	runner.active = participating
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if not participating and (decision == null or not decision.tree_updating):
		_abort_tree(actor, runner)


## S_NpcDecision явно передаёт один due GamePlay delta; операция вызывает manual BTPlayer.update.
## True означает захваченный intent_owner, не успешный эффект leaf или выполнение обязательства.
## После синхронных callbacks повторно проверяет World, Component и native runner.
static func update_tree(actor: E_DistrictNpc, delta: float) -> bool:
	var runner: BTPlayer = actor.get_node_or_null("Brain") as BTPlayer
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if runner == null or decision == null or not runner.active:
		return false
	var world: World = ECS.world
	decision.tree_updating = true
	runner.update(delta)
	# Native leaves publish facts whose observers may synchronously remove this runtime.
	if (
		not is_instance_valid(actor) or not is_instance_valid(world)
		or ECS.world != world or not world.entity_to_archetype.has(actor)
		or actor.get_component(C_NpcDecision) != decision
	):
		return false
	if not is_instance_valid(runner) or actor.get_node_or_null("Brain") != runner:
		return false
	# Urgent wakes invalidate queued cadence work, but do not replace this native runtime.
	decision.tree_updating = false
	var claimed: bool = decision.intent_owner != C_NpcDecision.Owner.NONE
	if not runner.active:
		_abort_tree(actor, runner)
	return claimed


static func _abort_tree(actor: E_DistrictNpc, runner: BTPlayer) -> void:
	NpcScheduleActionService.cancel_schedule(actor, &"participation_stopped")
	var instance: BTInstance = runner.get_bt_instance()
	if instance != null:
		instance.get_root_task().abort()
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision != null:
		decision.active_task_id = 0
		decision.intent_owner = C_NpcDecision.Owner.NONE
		decision.active_behavior = ""

#endregion
