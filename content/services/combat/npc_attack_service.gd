extends RefCounted
## Separate NPC attack runner; explicit kind/index API is the future AI boundary.
class_name NpcAttackService

const MELEE_HALF_ANGLE_DEGREES: float = 70.0
const MINIMUM_ESTIMATED_CYCLE_SECONDS: float = 0.001


static func variant_for(state: C_NpcCombat, kind: C_NpcCombat.Kind, index: int) -> DEF_NpcAttack:
	var variants: Array[DEF_NpcAttack] = state.melee_attacks if kind == C_NpcCombat.Kind.MELEE else state.ranged_attacks
	return variants[index] if index >= 0 and index < mini(variants.size(), C_NpcCombat.MAX_VARIANTS) else null


static func can_start(actor: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	return can_start_against(actor, CombatService.target_for(actor), kind, index)


static func can_start_against(actor: Entity, target: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	if not GrabService.holder_available(actor) or kind not in [C_NpcCombat.Kind.MELEE, C_NpcCombat.Kind.RANGED]:
		return false
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null or state.phase != C_NpcCombat.Phase.READY or state.cooldown_remaining > 0.0:
		return false
	var attack: DEF_NpcAttack = variant_for(state, kind, index)
	return _valid_attack(attack, kind) and _valid_pair(actor, target) and in_range(actor, target, attack) and CombatGeometry.clear_line(actor, target, attack.collision_mask)


## Failed explicit requests leave the current opponent/intent/cooldown untouched.
static func start_against(actor: Entity, target: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	return can_start_against(actor, target, kind, index) and CombatService.bind_target(actor, target) and start(actor, kind, index)


static func start(actor: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	if not can_start(actor, kind, index):
		return false
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	state.attack = variant_for(state, kind, index)
	state.kind = kind
	state.variant = index
	state.phase = C_NpcCombat.Phase.WINDUP
	state.elapsed = 0.0
	state.effect_committed = false
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	state.animation_driven = npc != null and npc.animation_player != null and state.attack.animation != &"" and npc.animation_player.has_animation(state.attack.animation)
	if state.animation_driven:
		npc.animation_player.play(state.attack.animation, E_NpcCharacter.ANIMATION_BLEND_SECONDS)
	_set_movement(actor, false)
	return true


## Read-only decision seam for generic behavior adapters. No live target cache is returned.
static func choose(actor: Entity) -> NpcAttackChoice:
	if not GrabService.holder_available(actor):
		return null
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null:
		return null
	var choice: NpcAttackChoice = null
	for kind: C_NpcCombat.Kind in [C_NpcCombat.Kind.MELEE, C_NpcCombat.Kind.RANGED]:
		for index: int in C_NpcCombat.MAX_VARIANTS:
			if not can_start(actor, kind, index):
				continue
			var attack: DEF_NpcAttack = variant_for(state, kind, index)
			if not is_finite(attack.selection_priority):
				continue
			var duration: float = maxf(MINIMUM_ESTIMATED_CYCLE_SECONDS, attack.windup_seconds + attack.active_seconds + attack.recovery_seconds + attack.cooldown_seconds)
			var rate: float = attack.damage / duration
			if choice != null and (attack.selection_priority < choice.priority or (attack.selection_priority == choice.priority and rate <= choice.damage_rate)):
				continue
			choice = NpcAttackChoice.new()
			choice.kind = kind
			choice.variant = index
			choice.priority = attack.selection_priority
			choice.damage_rate = rate
	return choice


static func choose_and_start(actor: Entity) -> bool:
	var choice: NpcAttackChoice = choose(actor)
	# Availability may change between decision and execution; the runner revalidates it.
	return choice != null and start(actor, choice.kind, choice.variant)


static func tick(actor: Entity, delta: float) -> void:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null:
		return
	state.cooldown_remaining = maxf(0.0, state.cooldown_remaining - maxf(0.0, delta))
	var target: Entity = CombatService.target_for(actor)
	if target == null and state.phase == C_NpcCombat.Phase.READY:
		return
	if not _valid_pair(actor, target):
		CombatService.end_combat(actor)
		return
	if state.phase == C_NpcCombat.Phase.READY:
		_set_movement(actor, true)
		return
	state.elapsed += maxf(0.0, delta)
	var attack: DEF_NpcAttack = state.attack
	if state.animation_driven:
		var npc: E_NpcCharacter = actor as E_NpcCharacter
		if npc == null or npc.animation_player == null or npc.animation_player.current_animation != attack.animation or not npc.animation_player.is_playing():
			finish(actor)
		elif state.elapsed >= npc.animation_player.get_animation(attack.animation).length + attack.recovery_seconds:
			# A looping/misconfigured clip must not lock the actor in one attack forever.
			finish(actor)
		return
	if state.elapsed >= attack.windup_seconds and not state.effect_committed:
		commit_effect(actor)
	var active_end: float = attack.windup_seconds + attack.active_seconds
	if state.elapsed >= active_end + attack.recovery_seconds:
		finish(actor)
	elif state.elapsed >= active_end:
		state.phase = C_NpcCombat.Phase.RECOVERY
	elif state.elapsed >= attack.windup_seconds:
		state.phase = C_NpcCombat.Phase.ACTIVE


## Animation method-track hook or timed fallback. One attempt per strike, even on a miss.
static func commit_effect(actor: Entity) -> bool:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null or state.attack == null or state.phase not in [C_NpcCombat.Phase.WINDUP, C_NpcCombat.Phase.ACTIVE] or state.effect_committed:
		return false
	var target: Entity = CombatService.target_for(actor)
	if not _valid_pair(actor, target):
		cancel(actor)
		return false
	state.effect_committed = true
	state.phase = C_NpcCombat.Phase.ACTIVE
	var district: C_District = DistrictPopulationService.current()
	if district != null:
		NpcPerceptionService.action_noise(actor, district.definition.strike_noise_radius)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null and not awareness.target_visible:
		return false
	var attack: DEF_NpcAttack = state.attack
	if not in_range(actor, target, attack) or not CombatGeometry.clear_line(actor, target, attack.collision_mask):
		return false
	if state.kind == C_NpcCombat.Kind.RANGED:
		return ProjectileService.launch(actor, target, attack)
	if not CombatGeometry.in_cone(actor, target, attack.maximum_range, MELEE_HALF_ANGLE_DEGREES):
		return false
	return CombatService.hit(actor, actor, target, attack.damage)


static func finish(actor: Entity) -> void:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null or state.attack == null:
		return
	state.cooldown_remaining = maxf(state.cooldown_remaining, state.attack.cooldown_seconds)
	_clear_execution(actor, state)


static func cancel(actor: Entity) -> void:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state != null:
		_clear_execution(actor, state)
		state.cooldown_remaining = 0.0


static func in_range(actor: Entity, target: Entity, attack: DEF_NpcAttack) -> bool:
	var actor_node: Node3D = actor as Node as Node3D
	var target_node: Node3D = target as Node as Node3D
	if actor_node == null or target_node == null:
		return false
	var distance: float = actor_node.global_position.distance_to(target_node.global_position)
	return distance >= attack.minimum_range and distance <= attack.maximum_range


static func _valid_pair(actor: Entity, target: Entity) -> bool:
	return GrabService.holder_available(actor) and GrabService.holder_available(target) and actor != target


static func _valid_attack(attack: DEF_NpcAttack, kind: C_NpcCombat.Kind) -> bool:
	if attack == null:
		return false
	for value: float in [attack.damage, attack.minimum_range, attack.maximum_range, attack.windup_seconds, attack.active_seconds, attack.recovery_seconds, attack.cooldown_seconds]:
		if not is_finite(value) or value < 0.0:
			return false
	if attack.damage <= 0.0 or attack.maximum_range <= attack.minimum_range or attack.active_seconds <= 0.0:
		return false
	return kind != C_NpcCombat.Kind.RANGED or (is_finite(attack.projectile_speed) and attack.projectile_speed > 0.0 and is_finite(attack.projectile_lifetime) and attack.projectile_lifetime > 0.0)


static func _set_movement(actor: Entity, allowed: bool) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent != null:
		intent.speed_fraction = 1.0 if allowed else 0.0


static func _clear_execution(actor: Entity, state: C_NpcCombat) -> void:
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	if state.animation_driven and npc != null and npc.animation_player != null and state.attack != null and npc.animation_player.current_animation == state.attack.animation:
		npc.animation_player.stop()
	state.phase = C_NpcCombat.Phase.READY
	state.variant = -1
	state.attack = null
	state.elapsed = 0.0
	state.effect_committed = false
	state.animation_driven = false
	_set_movement(actor, true)
