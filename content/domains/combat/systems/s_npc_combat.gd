extends System
## Owns NPC attack cooldown/windup/active/recovery and narrow native-animation watchdog.
class_name S_NpcCombat

#region Scheduling
## Declares combat ordering relative to input, decisions, challenges and physical intent.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_ChallengeRuntime, S_CustomerCombat, S_NpcRoutePlanning], Runs.Before: [S_NpcIntent]}


## Selects registered live state for this authoritative scheduled owner.
func query() -> QueryBuilder:
	return q.with_all([C_NpcCombat]).with_none([C_Death]).enabled()


## Captures state identity and execution generation at the command-buffer boundary.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for actor: Entity in entities:
		var captured: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
		cmd.add_custom(_advance.bind(weakref(actor), captured, captured.execution_generation, delta))
#endregion

#region Authoritative progression
func _advance(actor_reference: WeakRef, captured: C_NpcCombat, generation: int, delta: float) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var actor: Entity = actor_reference.get_ref() as Entity

	if not EntityAvailability.contains(actor, _world) or actor.get_component(C_NpcCombat) != captured:
		return
	if captured.execution_generation != generation:
		return
	_step(actor, delta)
	if EntityAvailability.contains(actor, _world) and actor.get_component(C_NpcCombat) == captured \
			and captured.automatic_attack_selection:
		NpcAttackService.choose_and_start(actor)


func _step(actor: Entity, delta: float) -> void:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null:
		return

	state.cooldown_remaining = maxf(0.0, state.cooldown_remaining - maxf(0.0, delta))
	var target: Entity = CombatQueries.target_for(actor)
	if target == null and state.phase == C_NpcCombat.Phase.READY:
		return
	if not NpcAttackService.pair_available(actor, target):
		CombatService.end_combat(actor)
		return
	if state.phase == C_NpcCombat.Phase.READY:
		NpcAttackExecutionService.allow_movement(actor, true)
		return

	var generation: int = state.execution_generation
	state.elapsed += maxf(0.0, delta)
	var attack: DEF_NpcAttack = state.attack
	if state.animation_driven:
		var npc: E_NpcCharacter = actor as E_NpcCharacter
		if npc == null or npc.animation_player == null or npc.animation_player.current_animation != attack.animation or not npc.animation_player.is_playing():
			NpcAttackExecutionService.finish(actor)
		elif state.elapsed >= npc.animation_player.get_animation(attack.animation).length + attack.recovery_seconds:
			# Зацикленный или неверный клип не должен удерживать участника в одной атаке бесконечно.
			NpcAttackExecutionService.finish(actor)
		return
	if state.elapsed >= attack.windup_seconds and not state.effect_committed:
		NpcAttackService.commit_effect(actor)

	# A synchronous effect consumer may cancel/replace the current execution.
	if not EntityAvailability.contains(actor, _world) or actor.get_component(C_NpcCombat) != state \
			or state.execution_generation != generation:
		return

	var active_end: float = attack.windup_seconds + attack.active_seconds
	if state.elapsed >= active_end + attack.recovery_seconds:
		NpcAttackExecutionService.finish(actor)
	elif state.elapsed >= active_end:
		state.phase = C_NpcCombat.Phase.RECOVERY
	elif state.elapsed >= attack.windup_seconds:
		state.phase = C_NpcCombat.Phase.ACTIVE
#endregion
