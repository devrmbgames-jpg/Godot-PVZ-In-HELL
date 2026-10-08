extends RefCounted
## Owns attack completion/cancellation and native animation binding cleanup; never selects or commits a hit.
class_name NpcAttackExecutionService

#region Explicit execution lifecycle
## Завершает текущую атаку с авторским cooldown и возвращает движение.
static func finish(actor: Entity) -> void:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null or state.attack == null:
		return

	state.cooldown_remaining = maxf(state.cooldown_remaining, state.attack.cooldown_seconds)
	_clear_execution(actor, state)

## Отменяет исполнение и обнуляет cooldown без эффекта атаки.
static func cancel(actor: Entity) -> void:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state != null:
		_clear_execution(actor, state)
		state.cooldown_remaining = 0.0

## Applies one explicit attack movement gate to an optional intent component.
static func allow_movement(actor: Entity, allowed: bool) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent != null:
		intent.speed_fraction = 1.0 if allowed else 0.0
#endregion

#region Native execution cleanup
static func _clear_execution(actor: Entity, state: C_NpcCombat) -> void:
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	if npc != null:
		_unbind_animation_callbacks(npc, state)
	if state.animation_driven and npc != null and npc.animation_player != null and state.attack != null and npc.animation_player.current_animation == state.attack.animation:
		npc.animation_player.stop()
	state.execution_generation += 1
	state.phase = C_NpcCombat.Phase.READY
	state.variant = -1
	state.attack = null
	state.elapsed = 0.0
	state.effect_committed = false
	state.animation_driven = false
	allow_movement(actor, true)

static func _unbind_animation_callbacks(npc: E_NpcCharacter, state: C_NpcCombat) -> void:
	if state.animation_hit_callback.is_valid() and npc.attack_effect_requested.is_connected(state.animation_hit_callback):
		npc.attack_effect_requested.disconnect(state.animation_hit_callback)
	if state.animation_finish_callback.is_valid() and npc.attack_finish_requested.is_connected(state.animation_finish_callback):
		npc.attack_finish_requested.disconnect(state.animation_finish_callback)
	state.animation_hit_callback = Callable()
	state.animation_finish_callback = Callable()
#endregion
