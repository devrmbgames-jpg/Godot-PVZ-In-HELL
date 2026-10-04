extends GutTest
## Проверяет старую напольную опасность по реальному контакту опоры и освобождение её эффекта.

var _world: World = null
var _actor: E_RigidBodyCharacter = null
var _subject: Entity = null
var _state: C_Challenge = null
var _motion: C_Motion = null
var _health: C_Health = null
var _visit: CustomerVisit = null


#region Окружение старого напольного испытания
## Создаёт системы старого напольного испытания и короткие изолированные часы.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_FloorChallengeSpawn.new())
	_world.add_observer(O_ChallengeLifecycle.new())
	_world.add_observer(O_Damage.new())
	_world.add_system(S_ChallengeFloorSetup.new())
	_world.add_system(S_FloorHazard.new())
	_world.add_system(S_ChallengeRuntime.new())
	_world.add_system(S_CustomerChallengeOutcome.new())

	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_CustomerFlow.new()]
	_world.add_entity(session)
	(session.get_component(C_DayCycle) as C_DayCycle).phase = C_DayCycle.Phase.DAY
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/entities/characters/e_rigid_body_character.gd"))
	_actor = body as Node as E_RigidBodyCharacter
	_motion = C_Motion.new()
	_motion.is_on_floor = true
	_motion.floor_body_rid = body.get_rid()
	_health = C_Health.new()
	_health.current = 100.0
	_health.value = 100.0
	_actor.component_resources = [_motion, _health]
	_world.add_entity(_actor)
	_motion = _actor.get_component(C_Motion) as C_Motion
	_health = _actor.get_component(C_Health) as C_Health
	_motion.is_on_floor = true
	_motion.floor_body_rid = body.get_rid()
	_subject = Entity.new()
	_state = C_Challenge.new()
	_state.definition = (load("res://content/definitions/gameplay/challenges/def_challenge_floor.tres") as DEF_Challenge).duplicate(true) as DEF_Challenge
	# Короткие изолированные часы отделяют механику теста от авторского темпа приёмки.
	_state.definition.timeout_seconds = 15.0
	_state.definition.preparation_seconds = 3.0
	_state.definition.violation_grace_seconds = 2.0
	(_state.definition.condition as DEF_FloorChallengeCondition).world_position = Vector3.ZERO

	var agent: C_CustomerAgent = C_CustomerAgent.new()
	agent.visit_id = &"floor-test"
	_subject.component_resources = [_state, C_FloorChallenge.new(), agent]
	_world.add_entity(_subject)
	_state = _subject.get_component(C_Challenge) as C_Challenge
	_visit = CustomerVisit.new()
	_visit.visit_id = agent.visit_id
	_visit.definition = DEF_Customer.new()
	_visit.started = true
	_visit.visit_count = 1
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(_visit)


## Удаляет эффект вместе с World и очищает сохранённые ссылки.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_actor = null
	_subject = null
	_state = null
	_motion = null
	_health = null
	_visit = null


func _start() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	assert_true(ChallengeService.activate(_subject))
	_world.process(_state.definition.preparation_seconds)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 1)
	var effect: Entity = _world.query.with_all([C_FloorHazard]).execute_one()
	var hazard: C_Hazard = effect.get_component(C_Hazard) as C_Hazard
	hazard.definition = hazard.definition.duplicate(true) as DEF_FloorHazard
	(hazard.definition as DEF_FloorHazard).tick_seconds = 0.5


#endregion

#region Контакт опоры и урон
## Условие требует реальный RID опоры, подходящую высоту контакта и авторские границы.
func test_support_contact_needs_real_support_height_and_authored_bounds() -> void:
	var profile: DEF_FloorHazard = DEF_FloorHazard.new()
	assert_true(FloorChallengeService.touches_surface(_motion, Transform3D.IDENTITY, profile))
	_motion.floor_contact_position.y = 0.4
	assert_false(FloorChallengeService.touches_surface(_motion, Transform3D.IDENTITY, profile), "Box top above the floor must remain safe")
	_motion.floor_contact_position = Vector3(3.0, 0.0, 0.0)
	assert_false(FloorChallengeService.touches_surface(_motion, Transform3D.IDENTITY, profile))
	_motion.floor_contact_position = Vector3.ZERO
	_motion.is_on_floor = false
	assert_false(FloorChallengeService.touches_surface(_motion, Transform3D.IDENTITY, profile), "Airborne projection is not a floor hit")
	_motion.is_on_floor = true
	_motion.floor_body_rid = RID()
	assert_false(FloorChallengeService.touches_surface(_motion, Transform3D.IDENTITY, profile))


## После подготовки урон проходит общей цепочкой; неудача и последствия применяются один раз.
func test_preparation_then_damage_uses_shared_pipeline_and_failure_is_once() -> void:
	_start()
	assert_eq(_health.current, 100.0)
	_world.process(0.4)
	assert_eq(_health.current, 100.0)
	_world.process(0.2)
	assert_eq(_health.current, 94.0)
	_world.process(1.4)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_eq(_health.current, 76.0)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
	_world.process(1.0)
	assert_eq(_health.current, 76.0)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 0)
	assert_eq(_visit.challenge_satisfaction_delta, -30)


## Высокая опора безопасна до конца срока; успех удаляет эффект и живую связь.
func test_elevated_box_support_survives_duration_and_retires_effect() -> void:
	_motion.floor_contact_position.y = 0.4
	_start()
	_world.process(20.0)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	assert_eq(_health.current, 100.0)
	assert_eq(_visit.challenge_satisfaction_delta, 10)
	_world.process(0.1)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 0)
	assert_eq(_subject.get_relationships(Relationship.new(R_ChallengeEffect.new())).size(), 0)


## Возврат на безопасную опору сбрасывает нарушение и интервал повреждения.
func test_returning_to_safe_support_resets_contact_and_damage_interval() -> void:
	_start()
	_world.process(0.4)
	_motion.floor_contact_position.y = 0.4
	_world.process(0.1)
	assert_eq(_state.violation_elapsed, 0.0)
	_motion.floor_contact_position.y = 0.0
	_world.process(0.4)
	assert_eq(_health.current, 100.0)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)


#endregion

#region Освобождение эффекта и границы срока
## Смерть участника отменяет испытание и удаляет принадлежащую ему опасность.
func test_player_death_cleans_owned_effects() -> void:
	_start()
	_actor.add_component(C_Death.new())
	_world.process(0.1)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 0)
	assert_eq(_visit.challenge_satisfaction_delta, 0)


## Смена фазы убирает опасность до следующего повреждения.
func test_phase_change_retires_effect_before_another_damage_tick() -> void:
	_start()
	_world.process(0.4)
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	_world.process(0.2)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_health.current, 100.0)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 0)


## Смена дня отменяет опасность до следующего повреждения.
func test_next_day_retires_effect_before_another_damage_tick() -> void:
	_start()
	_world.process(0.4)
	DayPhaseService.current().day_index += 1
	_world.process(0.2)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_health.current, 100.0)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 0)


## Удалённый эффект отменяет испытание и не создаётся повторно.
func test_removed_effect_cancels_active_challenge_without_respawning() -> void:
	_start()
	var effect: Entity = _world.query.with_all([C_FloorHazard]).execute_one()
	_world.remove_entity(effect)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	_world.process(0.1)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 0)


## Удаление источника сразу убирает связанный эффект.
func test_subject_removal_immediately_retires_its_effect() -> void:
	_start()
	_world.remove_entity(_subject)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_world.query.with_all([C_FloorHazard]).execute().size(), 0)


## Защита источника C_NoDamage блокирует реальный урон, сохраняя нарушение правила.
func test_no_damage_source_contract_is_preserved_by_floor_spawn() -> void:
	_subject.add_component(C_NoDamage.new())
	_start()
	_world.process(2.0)
	assert_eq(_health.current, 100.0)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)


## Пересечение конца срока ограничивает допустимое время нарушения текущего кадра.
func test_duration_end_caps_contact_budget_when_frame_crosses_timeout() -> void:
	_motion.floor_contact_position.y = 0.4
	_start()
	_world.process(11.9)
	_motion.floor_contact_position.y = 0.0
	_world.process(3.0)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	assert_eq(_health.current, 100.0)

#endregion
