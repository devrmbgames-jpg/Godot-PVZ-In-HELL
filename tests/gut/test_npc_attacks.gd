extends GutTest
## Регрессии выбора и исполнения атак NPC: реальный DamageRequest, method-track, снаряды и очистка целей.

var _world: World = null
var _npc: E_NpcCharacter = null
var _target: E_RigidBodyCharacter = null
var _state: C_NpcCombat = null
var _health: C_Health = null


#region Физическое тестовое окружение
## Создаёт World с реальными observers урона/боя и замороженными физическими участниками; синхронизирует лучи.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HealthLifecycle.new())
	_world.add_observer(O_CombatLifecycle.new())
	_npc = _body(true) as E_NpcCharacter
	_target = _body(false)
	(_target as Node as Node3D).global_position = Vector3(0, 0, -1.2)
	_state = _npc.get_component(C_NpcCombat) as C_NpcCombat
	_health = _target.get_component(C_Health) as C_Health
	assert_true(CombatService.bind_target(_npc, _target))
	await get_tree().physics_frame
	await get_tree().physics_frame


## Очищает World и ссылки участников после проверки, чтобы следующий случай не наследовал бой.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_npc = null
	_target = null
	_state = null
	_health = null


func _body(npc: bool) -> E_RigidBodyCharacter:
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.collision_layer = 2 if npc else 4
	body.set_script(load("res://content/entities/characters/e_npc_character.gd" if npc else "res://content/entities/characters/e_rigid_body_character.gd"))
	var entity: E_RigidBodyCharacter = body as Node as E_RigidBodyCharacter
	var health: C_Health = C_Health.new()
	health.current = 100.0
	health.value = 100.0
	entity.component_resources = [health, C_Living.new(), C_Controller.new(), C_NpcIntent.new()]
	if npc:
		var combat: C_NpcCombat = C_NpcCombat.new()
		combat.melee_attacks = [load("res://content/definitions/gameplay/combat/def_npc_punch.tres") as DEF_NpcAttack]
		combat.ranged_attacks = [load("res://content/definitions/gameplay/combat/def_npc_shot.tres") as DEF_NpcAttack]
		entity.component_resources.append(combat)

	var head: Marker3D = Marker3D.new()
	head.position.y = 1.5
	body.add_child(head)
	entity.head_axis_x = head
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	body.add_child(collision)
	_world.add_entity(entity)
	return entity


#endregion

#region Выбор и таймеры
## Замах, однократный удар и cooldown проходят общий DamageRequest; повтор эффекта не наносит урон.
func test_melee_windup_one_effect_and_shared_damage_pipeline() -> void:
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	NpcAttackService.tick(_npc, 0.3)
	assert_eq(_health.current, 100.0)
	NpcAttackService.tick(_npc, 0.16)
	assert_eq(_health.current, 88.0)
	assert_false(NpcAttackService.commit_effect(_npc))
	NpcAttackService.tick(_npc, 0.1)
	assert_eq(_health.current, 88.0)
	assert_false(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	NpcAttackService.tick(_npc, 0.5)
	assert_eq(_state.phase, C_NpcCombat.Phase.READY)
	assert_gt(_state.cooldown_remaining, 0.0)
	assert_false(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	NpcAttackService.tick(_npc, 0.8)
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))


## Явный выбор допускает индексы 0–2 обоих типов атак даже при ошибочно более длинном массиве.
func test_explicit_variant_request_supports_three_of_each_and_rejects_fourth() -> void:
	var attack: DEF_NpcAttack = _state.melee_attacks[0]
	_state.melee_attacks = [attack, attack, attack, attack]
	_state.ranged_attacks = [attack, attack, attack, attack]
	assert_true(NpcAttackService.can_start(_npc, C_NpcCombat.Kind.MELEE, 2))
	assert_true(NpcAttackService.can_start(_npc, C_NpcCombat.Kind.RANGED, 2))
	assert_false(NpcAttackService.can_start(_npc, C_NpcCombat.Kind.MELEE, 3))
	assert_false(NpcAttackService.can_start(_npc, C_NpcCombat.Kind.RANGED, 3))
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 2))
	assert_eq(_state.variant, 2)


## Выбор читает приоритет/скорость урона без запуска атаки; равный результат сохраняет первый вариант.
func test_selector_reads_priority_then_damage_rate_without_starting_attack() -> void:
	var slow: DEF_NpcAttack = _state.melee_attacks[0].duplicate(true) as DEF_NpcAttack
	var fast: DEF_NpcAttack = slow.duplicate(true) as DEF_NpcAttack
	fast.cooldown_seconds = 0.0
	_state.melee_attacks = [slow, fast, fast]
	var ranged: DEF_NpcAttack = _state.ranged_attacks[0].duplicate(true) as DEF_NpcAttack
	ranged.minimum_range = 0.0
	ranged.selection_priority = 10.0
	_state.ranged_attacks = [ranged]

	var choice: NpcAttackChoice = NpcAttackService.choose(_npc)
	assert_not_null(choice)
	assert_eq(choice.kind, C_NpcCombat.Kind.RANGED)
	assert_eq(choice.variant, 0)
	assert_eq(_state.phase, C_NpcCombat.Phase.READY)
	assert_eq(_health.current, 100.0)
	ranged.selection_priority = 0.0
	choice = NpcAttackService.choose(_npc)
	assert_eq(choice.kind, C_NpcCombat.Kind.MELEE)
	assert_eq(choice.variant, 1, "Same score keeps the first matching variant")
	assert_gt(choice.damage_rate, slow.damage / (slow.windup_seconds + slow.active_seconds + slow.recovery_seconds + slow.cooldown_seconds))
	assert_true(NpcAttackService.choose_and_start(_npc))
	assert_eq(_state.variant, 1)
	assert_eq(_state.kind, C_NpcCombat.Kind.MELEE)


## Перемещение цели и препятствие требуют повторной проверки решения; отклонённый запрос не меняет HP/фазу.
func test_selector_rejects_unavailable_or_stale_decision_without_side_effect() -> void:
	_state.cooldown_remaining = 0.5
	assert_null(NpcAttackService.choose(_npc))
	_state.cooldown_remaining = 0.0
	var choice: NpcAttackChoice = NpcAttackService.choose(_npc)
	assert_not_null(choice)
	(_target as Node as Node3D).position.z = -4.0
	assert_false(NpcAttackService.start(_npc, choice.kind, choice.variant), "Decision is revalidated after the target moved")
	choice = NpcAttackService.choose(_npc)
	assert_eq(choice.kind, C_NpcCombat.Kind.RANGED)

	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = Vector3(0, 1.5, -2)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	_world.add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_null(NpcAttackService.choose(_npc), "No ability can shoot through the wall")
	assert_false(NpcAttackService.choose_and_start(_npc))
	assert_eq(_state.phase, C_NpcCombat.Phase.READY)
	assert_eq(_health.current, 100.0)


## Отключённый автоматический выбор сохраняет исполнение явной атаки/cooldown; включение возвращает выбор.
func test_selector_external_control_keeps_execution_and_cooldown_then_restores_default() -> void:
	_state.automatic_attack_selection = false
	_world.add_system(S_NpcCombat.new())
	_world.process(0.1)
	assert_eq(_state.phase, C_NpcCombat.Phase.READY)
	var choice: NpcAttackChoice = NpcAttackService.choose(_npc)
	assert_true(NpcAttackService.start(_npc, choice.kind, choice.variant))
	_world.process(0.46)
	assert_eq(_health.current, 88.0, "The external decision still uses the real damage runner")
	_world.process(1.0)
	assert_eq(_state.phase, C_NpcCombat.Phase.READY)
	assert_gt(_state.cooldown_remaining, 0.0)
	_world.process(2.0)
	assert_eq(_state.phase, C_NpcCombat.Phase.READY, "Disabled selection cannot restart after cooldown")
	assert_eq(_state.cooldown_remaining, 0.0)
	_state.automatic_attack_selection = true
	_world.process(0.0)
	assert_eq(_state.phase, C_NpcCombat.Phase.WINDUP)


#endregion

#region Анимация и прерывание
## Реальные method-track управляют ударом вместо таймера; повторный ключ не дублирует урон.
func test_actual_animation_method_tracks_commit_once_and_finish_with_cooldown() -> void:
	var player: AnimationPlayer = AnimationPlayer.new()
	(_npc as Node).add_child(player)
	_npc.animation_player = player
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	var library: AnimationLibrary = AnimationLibrary.new()
	var animation: Animation = Animation.new()
	animation.length = 0.8

	var track: int = animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track, NodePath("."))
	animation.track_insert_key(track, 0.3, {"method": &"npc_attack_hit", "args": []})
	animation.track_insert_key(track, 0.4, {"method": &"npc_attack_hit", "args": []})
	animation.track_insert_key(track, 0.7, {"method": &"npc_attack_finished", "args": []})
	library.add_animation(&"Strike", animation)
	player.add_animation_library(&"", library)
	_state.melee_attacks[0] = _state.melee_attacks[0].duplicate(true) as DEF_NpcAttack
	_state.melee_attacks[0].animation = &"Strike"
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	assert_true(_state.animation_driven)
	NpcAttackService.tick(_npc, 0.5)
	assert_eq(_health.current, 100.0, "Timer must not commit an animation-owned hit")
	player.advance(0.35)
	assert_eq(_health.current, 88.0)
	player.advance(0.15)
	assert_eq(_health.current, 88.0)
	player.advance(0.25)
	assert_eq(_state.phase, C_NpcCombat.Phase.READY)
	assert_gt(_state.cooldown_remaining, 0.0)


## Отсутствующая авторская анимация оставляет доступным исполнение удара по таймеру.
func test_unassigned_or_missing_animation_keeps_timed_prototype_playable() -> void:
	_state.melee_attacks[0] = _state.melee_attacks[0].duplicate(true) as DEF_NpcAttack
	_state.melee_attacks[0].animation = &"NotAuthoredYet"
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	assert_false(_state.animation_driven)
	NpcAttackService.tick(_npc, 0.5)
	assert_eq(_health.current, 88.0)


## Удаление живой цели отменяет атаку и намерения; поздний callback уже не применяет эффект.
func test_removed_target_cancels_pending_animation_hook_and_navigation() -> void:
	NpcIntentService.follow(_npc, _target, 1.0)
	NpcIntentService.watch(_npc, _target)
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	_world.remove_entity(_target)
	_target = null
	assert_eq(_state.phase, C_NpcCombat.Phase.READY)
	assert_null(CombatService.target_for(_npc))
	assert_false(NpcAttackService.commit_effect(_npc))
	assert_false((_npc.get_component(C_NpcIntent) as C_NpcIntent).movement_active)


## Смертельный DamageRequest атакующему освобождает противника и предотвращает ещё не исполненный удар.
func test_death_cancels_strike_before_effect_and_clears_opponent() -> void:
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	var request: DamageRequest = DamageRequest.new()
	request.source = _target
	request.instigator = _target
	request.target = _npc
	request.amount = 200.0
	DamageRequestService.submit(request)
	assert_true(_npc.has_component(C_Death))
	assert_null(CombatService.target_for(_npc))
	assert_false(NpcAttackService.commit_effect(_npc))
	assert_eq(_health.current, 100.0)


#endregion

#region Снаряды и атрибуция
## Однократный дальний эффект создаёт один снаряд, поражающий реальный коллайдер и затем удаляемый.
func test_ranged_effect_launches_once_and_projectile_hits_real_collider() -> void:
	(_target as Node as Node3D).global_position.z = -4.0
	await get_tree().physics_frame
	assert_false(NpcAttackService.can_start(_npc, C_NpcCombat.Kind.MELEE, 0))
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.RANGED, 0))
	NpcAttackService.tick(_npc, 0.71)
	var projectiles: Array[Entity] = _world.query.with_all([C_CombatProjectile]).execute()
	assert_eq(projectiles.size(), 1)
	assert_false(NpcAttackService.commit_effect(_npc))
	ProjectileService.tick(projectiles[0], 0.8)
	assert_eq(_health.current, 92.0)
	assert_true(_world.query.with_all([C_CombatProjectile]).execute().is_empty())


## Снаряд сохраняет эффективный урон при запуске; последующая еда не меняет его или авторскую атаку.
func test_projectile_snapshots_hunger_damage_before_food_restores_shooter() -> void:
	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = load("res://content/definitions/gameplay/hunger/def_hunger_default.tres") as DEF_HungerPolicy
	hunger.value = 75.0
	_npc.add_component(hunger)
	hunger = _npc.get_component(C_Hunger) as C_Hunger
	(_target as Node as Node3D).global_position.z = -4.0
	await get_tree().physics_frame
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.RANGED, 0))
	assert_true(NpcAttackService.commit_effect(_npc))

	var projectile: Entity = _world.query.with_all([C_CombatProjectile]).execute_one()
	assert_eq((projectile.get_component(C_CombatProjectile) as C_CombatProjectile).damage, 12.0)
	var food: DEF_FoodEffect = DEF_FoodEffect.new()
	food.hunger_relief = 100.0
	assert_true(HungerService.apply_food(_npc, food))
	assert_eq(hunger.value, 0.0)
	ProjectileService.tick(projectile, 1.0)
	assert_eq(_health.current, 88.0, "Already launched projectiles retain their effective damage")
	assert_eq(_state.ranged_attacks[0].damage, 8.0)


## Луч пройденного отрезка не пропускает стену при большом шаге; выбор новой атаки также учитывает LOS.
func test_wall_blocks_projectile_even_for_long_frame() -> void:
	(_target as Node as Node3D).global_position.z = -4.0
	await get_tree().physics_frame
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.RANGED, 0))
	assert_true(NpcAttackService.commit_effect(_npc))
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	_world.add_child(wall)
	wall.position = Vector3(0, 1, -2)
	await get_tree().physics_frame

	var projectile: Entity = _world.query.with_all([C_CombatProjectile]).execute_one()
	ProjectileService.tick(projectile, 1.0)
	assert_eq(_health.current, 100.0)
	assert_true(_world.query.with_all([C_CombatProjectile]).execute().is_empty())
	NpcAttackService.finish(_npc)
	NpcAttackService.tick(_npc, 2.0)
	assert_false(NpcAttackService.can_start(_npc, C_NpcCombat.Kind.RANGED, 0), "AI must not shoot through the wall")


## Снаряд наследует C_NoDamage стрелка и не обходит запрет урона.
func test_no_damage_shooter_cannot_bypass_guard_with_projectile() -> void:
	(_target as Node as Node3D).global_position.z = -4.0
	await get_tree().physics_frame
	_npc.add_component(C_NoDamage.new())
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.RANGED, 0))
	assert_true(NpcAttackService.commit_effect(_npc))
	var projectile: Entity = _world.query.with_all([C_CombatProjectile]).execute_one()
	assert_true(projectile.has_component(C_NoDamage))
	ProjectileService.tick(projectile, 1.0)
	assert_eq(_health.current, 100.0)


## После удаления стрелка снаряд сохраняет стабильную атрибуцию и исполняет ранее запущенный урон.
func test_projectile_retains_generic_shooter_id_after_source_removal() -> void:
	(_target as Node as Node3D).global_position.z = -4.0
	await get_tree().physics_frame
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.RANGED, 0))
	assert_true(NpcAttackService.commit_effect(_npc))
	var projectile: Entity = _world.query.with_all([C_CombatProjectile]).execute_one()
	var state: C_CombatProjectile = projectile.get_component(C_CombatProjectile) as C_CombatProjectile
	assert_eq(state.instigator_id, _npc.id)
	assert_false(state.instigator_id.is_empty())
	_world.remove_entity(_npc)
	_npc = null
	ProjectileService.tick(projectile, 1.0)
	assert_eq(_health.current, 92.0)


#endregion

#region Промах и диагностика
## Промах вне дальности расходует единственную попытку эффекта; возвращение цели не разрешает поздний удар.
func test_out_of_range_at_hit_time_misses_without_late_duplicate() -> void:
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	(_target as Node as Node3D).global_position.z = -4.0
	assert_false(NpcAttackService.commit_effect(_npc))
	(_target as Node as Node3D).global_position.z = -1.2
	assert_false(NpcAttackService.commit_effect(_npc))
	assert_eq(_health.current, 100.0)


## Диагностика отражает текущий замах, дальность, условия и таймеры реального боя.
func test_debug_reports_task_range_phase_and_timers() -> void:
	assert_true(NpcAttackService.start(_npc, C_NpcCombat.Kind.MELEE, 0))
	var text: String = CombatPresentation.debug_text(_target)
	assert_true(text.contains("Задача:") and text.contains("замах"))
	assert_true(text.contains("cooldown") and text.contains("Таймер"))
	assert_true(text.contains("Дистанция") and text.contains("Условие"))

#endregion
