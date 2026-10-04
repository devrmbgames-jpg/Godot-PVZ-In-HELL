extends GutTest
## Проверяет время роста голода, пороги, еду и обратимые эффективные модификаторы.

var _world: World = null
var _actor: Entity = null
var _state: C_Hunger = null
var _cycle: C_DayCycle = null


#region Окружение живого игрока
## Создаёт живого игрока с авторской политикой голода в дневном World.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_Hunger.new())
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new()]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_actor = Entity.new()

	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = load("res://content/definitions/gameplay/hunger/def_hunger_default.tres") as DEF_HungerPolicy
	_actor.component_resources = [hunger, C_PlayerInputController.new(), C_Living.new()]
	_world.add_entity(_actor)
	_state = _actor.get_component(C_Hunger) as C_Hunger


## Возвращает неприостановленное дерево и удаляет World.
func after_each() -> void:
	get_tree().paused = false
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_actor = null
	_state = null
	_cycle = null


#endregion

#region Время, еда и эффективные параметры
## Пороги включают граничные значения; рост ограничивает голод максимумом.
func test_thresholds_are_inclusive_and_value_is_bounded() -> void:
	_state.value = 39.999
	assert_eq(HungerService.tier(_state), C_Hunger.Tier.NORMAL)
	_state.value = 40.0
	assert_eq(HungerService.tier(_state), C_Hunger.Tier.HUNGRY)
	_state.value = 74.999
	assert_eq(HungerService.tier(_state), C_Hunger.Tier.HUNGRY)
	_state.value = 75.0
	assert_eq(HungerService.tier(_state), C_Hunger.Tier.STARVING)
	_world.process(1000.0)
	assert_eq(_state.value, 100.0)
	assert_eq(_state.active_seconds, 1000.0)


## Голод растёт только в активное неночное время живого участника без паузы.
func test_growth_uses_active_non_night_unpaused_living_time() -> void:
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		_cycle.phase = phase
		_world.process(10.0)
	assert_eq(_state.value, 1.5)
	assert_eq(_state.active_seconds, 30.0)
	_cycle.phase = C_DayCycle.Phase.NIGHT
	_world.process(100.0)
	assert_eq(_state.value, 1.5)
	_cycle.phase = C_DayCycle.Phase.DAY
	get_tree().paused = true
	_world.process(100.0)
	get_tree().paused = false
	assert_eq(_state.value, 1.5)
	_actor.add_component(C_Death.new())
	_world.process(100.0)
	assert_eq(_state.value, 1.5)
	assert_eq(_state.active_seconds, 30.0)


## Недопустимые интервалы не меняют значение и активные часы.
func test_invalid_or_negative_elapsed_time_does_not_change_state() -> void:
	for delta: float in [-1.0, NAN, INF, 0.0]:
		HungerService.advance(_state, delta, C_DayCycle.Phase.DAY, false, true)
	assert_eq(_state.value, 0.0)
	assert_eq(_state.active_seconds, 0.0)


## Еда действует через типизированный эффект; нулевой голод и смерть отклоняют применение.
func test_food_is_public_typed_effect_and_never_consumes_at_zero_or_on_dead_actor() -> void:
	var food: DEF_FoodEffect = load("res://content/definitions/gameplay/hunger/def_food_bread.tres") as DEF_FoodEffect
	assert_false(HungerService.apply_food(_actor, food))
	_state.value = 80.0
	assert_true(HungerService.apply_food(_actor, food))
	assert_eq(_state.value, 45.0)
	assert_eq(HungerService.tier(_state), C_Hunger.Tier.HUNGRY)
	assert_true(HungerService.apply_food(_actor, food))
	assert_eq(_state.value, 10.0)
	assert_true(HungerService.apply_food(_actor, food))
	assert_eq(_state.value, 0.0)
	_state.value = 80.0
	_actor.add_component(C_Death.new())
	assert_false(HungerService.apply_food(_actor, food))
	assert_eq(_state.value, 80.0)


## Эффективная скорость сочетает груз и голод без накопленного изменения авторской базы.
func test_effective_speed_combines_carry_and_hunger_without_baseline_drift() -> void:
	var motion: C_Motion = C_Motion.new()
	var carry: C_CarryLoad = C_CarryLoad.new()
	var strength: C_Strength = C_Strength.new()
	strength.value = 1.0
	carry.active = true
	carry.mass_kg = 80.0
	var baseline: float = motion.max_speed
	var carry_speed: float = CharacterMotionSolver.effective_speed(motion, carry, strength)
	for iteration: int in 32:
		_state.value = 75.0
		assert_almost_eq(CharacterMotionSolver.effective_speed(motion, carry, strength, _state), carry_speed * 1.35, 0.00001)
		_state.value = 0.0
		assert_almost_eq(CharacterMotionSolver.effective_speed(motion, carry, strength, _state), carry_speed, 0.00001)
	assert_eq(motion.max_speed, baseline)
	carry.active = false
	_state.value = 40.0
	assert_almost_eq(CharacterMotionSolver.effective_speed(motion, carry, strength, _state), baseline * 1.15, 0.00001)


## Еда снимает боевой модификатор голода, сохраняя авторский урон атаки.
func test_food_reverses_attack_multiplier_and_authored_attack_is_unchanged() -> void:
	_world.add_observer(O_Damage.new())
	var target: Entity = Entity.new()
	var health: C_Health = C_Health.new()
	health.current = 100.0
	health.value = 100.0
	target.component_resources = [health]
	_world.add_entity(target)
	health = target.get_component(C_Health) as C_Health

	var attack: DEF_MeleeAttack = load("res://content/definitions/gameplay/combat/def_blade_attack.tres") as DEF_MeleeAttack
	_state.value = 75.0
	assert_eq(attack.damage * HungerService.damage_multiplier(_state), 60.0)
	assert_true(CombatService.hit(_actor, _actor, target, attack.damage))
	assert_eq(health.current, 40.0, "The actual damage producer must use the effective hunger multiplier")
	var food: DEF_FoodEffect = DEF_FoodEffect.new()
	food.hunger_relief = 100.0
	assert_true(HungerService.apply_food(_actor, food))
	assert_eq(attack.damage * HungerService.damage_multiplier(_state), 40.0)
	assert_true(CombatService.hit(_actor, _actor, target, attack.damage))
	assert_eq(health.current, 0.0)
	assert_eq(attack.damage, 40.0)


## Диагностика сообщает условия роста, пороги, часы и эффективные модификаторы.
func test_debug_exposes_growth_condition_threshold_clock_and_effective_modifiers() -> void:
	var text: String = HungerPresentation.debug_text(_actor)
	assert_true(text.contains("Normal") and text.contains("Рост активен"))
	assert_true(text.contains("Пороги") and text.contains("до следующего"))
	assert_true(text.contains("Задача:") and text.contains("Скорость") and text.contains("атака"))
	_cycle.phase = C_DayCycle.Phase.NIGHT
	assert_true(HungerPresentation.debug_text(_actor).contains("Рост пауза"))

#endregion
