extends RefCounted
## Selects, starts and commits NPC attack effects; S_NpcCombat owns progression and execution cleanup is explicit.
class_name NpcAttackService

const MELEE_HALF_ANGLE_DEGREES: float = 70.0
const MINIMUM_ESTIMATED_CYCLE_SECONDS: float = 0.001


#region Доступность и начало атаки
## Читает атаку по виду/индексу в пределах MAX_VARIANTS.
static func variant_for(state: C_NpcCombat, kind: C_NpcCombat.Kind, index: int) -> DEF_NpcAttack:
	var variants: Array[DEF_NpcAttack] = state.melee_attacks if kind == C_NpcCombat.Kind.MELEE else state.ranged_attacks
	return variants[index] if index >= 0 and index < mini(variants.size(), C_NpcCombat.MAX_VARIANTS) else null


## Проверяет возможность атаки против текущего R_CombatTarget без изменения состояния.
static func can_start(actor: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	return can_start_against(actor, CombatQueries.target_for(actor), kind, index)


## Проверяет готовность, cooldown, геометрию и луч конкретного противника.
static func can_start_against(actor: Entity, target: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	if not GrabQueries.holder_available(actor) or kind not in [C_NpcCombat.Kind.MELEE, C_NpcCombat.Kind.RANGED]:
		return false

	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null or state.phase != C_NpcCombat.Phase.READY or state.cooldown_remaining > 0.0:
		return false

	var attack: DEF_NpcAttack = variant_for(state, kind, index)
	return _valid_attack(attack, kind) and pair_available(actor, target) and in_range(actor, target, attack) and CombatGeometry.clear_line(actor, target, attack.collision_mask)


## Отклонённый запрос не меняет текущего противника, намерение и cooldown.
static func start_against(actor: Entity, target: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	return can_start_against(actor, target, kind, index) and CombatService.bind_target(actor, target) and start(actor, kind, index)


## Фиксирует доступную атаку и блокирует движение на исполнение без повторного старта.
static func start(actor: Entity, kind: C_NpcCombat.Kind, index: int) -> bool:
	if not can_start(actor, kind, index):
		return false

	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	state.execution_generation += 1
	state.attack = variant_for(state, kind, index)
	state.kind = kind
	state.variant = index
	state.phase = C_NpcCombat.Phase.WINDUP
	state.elapsed = 0.0
	state.effect_committed = false
	var npc: E_NpcCharacter = actor as E_NpcCharacter
	state.animation_driven = npc != null and npc.animation_player != null and state.attack.animation != &"" and npc.animation_player.has_animation(state.attack.animation)
	if state.animation_driven:
		_bind_animation_callbacks(npc, state)
		npc.animation_player.play(state.attack.animation, E_NpcCharacter.ANIMATION_BLEND_SECONDS)
	NpcAttackExecutionService.allow_movement(actor, false)
	return true


#endregion

#region Выбор доступного варианта
## Выбирает доступную атаку без изменения состояния и без выдачи кеша живой цели.
static func choose(actor: Entity) -> NpcAttackChoice:
	if not GrabQueries.holder_available(actor):
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


## Выбирает доступную атаку и повторно проверяет её перед стартом.
static func choose_and_start(actor: Entity) -> bool:
	var choice: NpcAttackChoice = choose(actor)
	# Доступность могла измениться после выбора; исполнение проверяет её снова.
	return choice != null and start(actor, choice.kind, choice.variant)


#endregion

#region Исполнение и завершение


## Hook анимации или таймера: одна попытка эффекта на атаку, включая промах и невидимую цель.
static func commit_effect(actor: Entity) -> bool:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state == null or state.attack == null or state.phase not in [C_NpcCombat.Phase.WINDUP, C_NpcCombat.Phase.ACTIVE] or state.effect_committed:
		return false

	var target: Entity = CombatQueries.target_for(actor)
	if not pair_available(actor, target):
		NpcAttackExecutionService.cancel(actor)
		return false

	state.effect_committed = true
	state.phase = C_NpcCombat.Phase.ACTIVE
	var district: C_District = NpcPopulationQueries.current()
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


#endregion

#region Геометрия и внутренние проверки
## Проверяет диапазон расстояния между мировыми позициями тел в метрах.
static func in_range(actor: Entity, target: Entity, attack: DEF_NpcAttack) -> bool:
	var actor_node: Node3D = actor as Node as Node3D
	var target_node: Node3D = target as Node as Node3D
	if actor_node == null or target_node == null:
		return false

	var distance: float = actor_node.global_position.distance_to(target_node.global_position)
	return distance >= attack.minimum_range and distance <= attack.maximum_range


## Tests optional live endpoints before a command or captured attack step.
static func pair_available(actor: Entity, target: Entity) -> bool:
	return GrabQueries.holder_available(actor) and GrabQueries.holder_available(target) and actor != target


static func _valid_attack(attack: DEF_NpcAttack, kind: C_NpcCombat.Kind) -> bool:
	if attack == null:
		return false

	for value: float in [attack.damage, attack.minimum_range, attack.maximum_range, attack.windup_seconds, attack.active_seconds, attack.recovery_seconds, attack.cooldown_seconds]:
		if not is_finite(value) or value < 0.0:
			return false
	if attack.damage <= 0.0 or attack.maximum_range <= attack.minimum_range or attack.active_seconds <= 0.0:
		return false
	return kind != C_NpcCombat.Kind.RANGED or (is_finite(attack.projectile_speed) and attack.projectile_speed > 0.0 and is_finite(attack.projectile_lifetime) and attack.projectile_lifetime > 0.0)


#endregion

#region Native animation execution bindings
static func _bind_animation_callbacks(npc: E_NpcCharacter, state: C_NpcCombat) -> void:
	# Weak witnesses avoid retaining the actor or a Component/Callable reference cycle.
	var actor_reference: WeakRef = weakref(npc)
	var state_reference: WeakRef = weakref(state)
	state.animation_hit_callback = _on_animation_hit.bind(actor_reference, state_reference, state.execution_generation)
	state.animation_finish_callback = _on_animation_finish.bind(actor_reference, state_reference, state.execution_generation)
	npc.attack_effect_requested.connect(state.animation_hit_callback)
	npc.attack_finish_requested.connect(state.animation_finish_callback)


static func _animation_actor(actor_reference: WeakRef, state_reference: WeakRef, generation: int) -> Entity:
	var actor: Entity = actor_reference.get_ref() as Entity
	var state: C_NpcCombat = state_reference.get_ref() as C_NpcCombat
	if not EntityAvailability.contains(actor, ECS.world) or state == null:
		return null
	if actor.get_component(C_NpcCombat) != state or state.execution_generation != generation:
		return null
	return actor


static func _on_animation_hit(actor_reference: WeakRef, state_reference: WeakRef, generation: int) -> void:
	var actor: Entity = _animation_actor(actor_reference, state_reference, generation)
	if actor != null:
		commit_effect(actor)


static func _on_animation_finish(actor_reference: WeakRef, state_reference: WeakRef, generation: int) -> void:
	var actor: Entity = _animation_actor(actor_reference, state_reference, generation)
	if actor != null:
		NpcAttackExecutionService.finish(actor)
#endregion
