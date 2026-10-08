extends RefCounted
## Installs and advances one native LimboAI runtime; scheduling belongs to explicit AI Systems.
class_name NpcBrainService

## Authored native decision tree installed by the runtime adapter.
const TREE_PATH: String = "res://content/domains/npc/ai/trees/bt_npc_native.tres"

#region Жизненный цикл AI
## Создаёт производные сенсоры и единственный BTPlayer с ручным обновлением.
static func install(actor: E_DistrictNpc) -> void:
	var profile_identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(profile_identity.npc_id)
	if person != null:
		NpcTraitService.install(actor, person.profile)
	if not actor.has_component(C_NpcAwareness):
		actor.add_component(C_NpcAwareness.new())
	if not actor.has_component(C_NpcDecision):
		var decision: C_NpcDecision = C_NpcDecision.new()
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		var district: C_District = NpcPopulationQueries.current()
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
	runner.behavior_tree = actor.decision_tree(load(TREE_PATH) as BehaviorTree)
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

#endregion
