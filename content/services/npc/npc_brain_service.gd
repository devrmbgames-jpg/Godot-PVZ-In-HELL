extends RefCounted
## Bounded sensory/decision cadence using native LimboAI instances per persistent person.
class_name NpcBrainService

const TREE_PATH: String = "res://content/ai/trees/bt_district_npc.tres"

#region Brain lifecycle
## Creates derived sensors and one manually scheduled BTPlayer.
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
		combat.automatic_attack_selection = false
	if actor.get_node_or_null("Brain") != null:
		return
	var runner: BTPlayer = BTPlayer.new()
	runner.name = "Brain"
	runner.update_mode = BTPlayer.MANUAL
	runner.set_scene_root_hint(ECS.world.get_parent())
	runner.behavior_tree = load(TREE_PATH) as BehaviorTree
	actor.add_child(runner)

## Updates one coherent perception batch and then each native tree.
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
		var runner: BTPlayer = actor.get_node_or_null("Brain") as BTPlayer
		decision.intent_owner = C_NpcDecision.Owner.NONE
		if runner != null:
			runner.update(decision.update_elapsed)
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		NpcRouteService.tick(actor, DistrictPopulationService.person_for(identity.npc_id), decision.update_elapsed)
		decision.update_elapsed = 0.0
	for noise: NpcNoise in district.noises.duplicate():
		noise.remaining -= maxf(0.0, delta)
		if noise.remaining <= 0.0:
			district.noises.erase(noise)
#endregion
