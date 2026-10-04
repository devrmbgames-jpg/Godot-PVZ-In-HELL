extends "res://tests/gut/test_district_service.gd"
## Интеграционные сценарии занятий, социальных контрмер, обслуживания и опасных маршрутов района.

#region Тестовое окружение
func _stage(index: int, point: Vector3 = Vector3.ZERO) -> E_DistrictNpc:
	var person: NpcRecord = _district.people[index]
	person.profile = person.profile.duplicate() as DEF_NpcProfile
	person.profile.rules = []
	person.profile.dark_vision_fraction = 1.0
	person.phase_complete = true
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	body.place_at(point)
	body.freeze = true
	return body

func _player(point: Vector3 = Vector3(0, 0, -3)) -> E_DistrictNpc:
	var physical: RigidBody3D = RigidBody3D.new()
	physical.set_script(load("res://content/entities/npc/e_district_npc.gd"))
	var player: E_DistrictNpc = physical as Node as E_DistrictNpc
	player.component_resources = [C_Health.new(), C_PlayerInputController.new(), C_NpcIntent.new()]
	player.freeze = true
	player.collision_layer = 2
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	collision.shape = shape
	collision.position = Vector3.UP * 0.85
	player.add_child(collision)
	_world.add_entity(player)
	player.global_position = point
	return player

func _service(body: E_DistrictNpc, suffix: String) -> CustomerVisit:
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
	var visit: CustomerVisit = _case(person, suffix)
	visit.definition = visit.definition.duplicate() as DEF_Customer
	NpcServiceRole.begin(body, person, visit, 1)
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	return visit

func _light_zone() -> NpcLightZone:
	var zone: NpcLightZone = (load("res://content/scenes/npc_light_zone.tscn") as PackedScene).instantiate() as NpcLightZone
	(zone.get_node("CollisionShape3D") as CollisionShape3D).shape = BoxShape3D.new()
	((zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size = Vector3(20, 6, 20)
	zone.position = Vector3(0, 2, -1)
	_root.add_child(zone)
	return zone
#endregion

#region Уход через проходы
## Расписание завершает уход рядом с краем navmesh, учитывая горизонтальный радиус прохода.
func test_schedule_exit_accepts_ground_radius_without_exact_marker_contact() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.schedule = person.profile.schedule.duplicate() as DEF_NpcSchedule
	person.profile.schedule.day = DEF_NpcSchedule.Location.OUTSIDE
	DistrictPopulationService.plan_phase(person, 1, C_DayCycle.Phase.DAY)
	var destination: Vector3 = DistrictPopulationService.position_for(person.goal_id)
	body.place_at(destination + Vector3(0.8, 2.0, 0.0))
	assert_true(NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2))
	assert_true(person.phase_complete)
	assert_eq(person.placement, NpcRecord.Placement.OUTSIDE)
	assert_false(body.enabled)
	assert_eq(body.collision_layer, 0)
	assert_null(CombatService.target_for(body))

## Бегство использует тот же наземный радиус, а удалённая точка не завершает уход преждевременно.
func test_flee_exit_stops_only_within_portal_radius() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	var destination: Vector3 = DistrictPopulationService.position_for(person.portal_id)
	body.place_at(destination + Vector3(2.0, 2.0, 0.0))
	awareness.last_seen_position = body.global_position
	awareness.fleeing = true
	assert_true(NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.EMERGENCY, 0.2))
	assert_eq(person.placement, NpcRecord.Placement.STREET)
	var intent: C_NpcIntent = body.get_component(C_NpcIntent) as C_NpcIntent
	assert_eq(intent.arrival_distance, _district.definition.portal_arrival_distance)
	body.place_at(intent.move_position + Vector3(0.8, 2.0, 0.0))
	assert_true(NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.EMERGENCY, 0.2))
	assert_eq(person.placement, NpcRecord.Placement.OUTSIDE)
	assert_false(awareness.fleeing)
	assert_false(body.enabled)

## Таймаут не подменяет настоящий выход завершённой фазой; расписание возобновляет запрос маршрута.
func test_stalled_schedule_exit_keeps_unfinished_departure() -> void:
	var body: E_DistrictNpc = _stage(0, Vector3(-8, 0, 0))
	var person: NpcRecord = _district.people[0]
	person.profile.schedule = person.profile.schedule.duplicate() as DEF_NpcSchedule
	person.profile.schedule.day = DEF_NpcSchedule.Location.OUTSIDE
	DistrictPopulationService.plan_phase(person, 1, C_DayCycle.Phase.DAY)
	var native: Dictionary[StringName, RID] = await _flat_map()
	body.navigation_agent.set_navigation_map(native[&"map"])
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	NpcRouteService.tick(body, person, 0.2)
	NpcRouteService.process_pending(_district)
	NpcRouteService.tick(body, person, _district.definition.route_timeout + 0.1)
	assert_false(person.phase_complete)
	assert_eq(person.placement, NpcRecord.Placement.STREET)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	NpcRouteService.tick(body, person, 0.2)
	assert_true((body.get_component(C_NpcRoute) as C_NpcRoute).pending)
	assert_true((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	NavigationServer3D.free_rid(native[&"region"])
	NavigationServer3D.free_rid(native[&"map"])
#endregion

#region Свободные занятия
## Обычные шаги остаются слышимыми, но не заменяют свободное занятие движением к каждому прохожему.
func test_footsteps_do_not_pull_idle_npc_into_a_crowd() -> void:
	var body: E_DistrictNpc = _stage(0)
	var source: E_DistrictNpc = _stage(3, Vector3(0, 0, -3))
	var person: NpcRecord = _district.people[0]
	await get_tree().physics_frame
	await get_tree().physics_frame
	source.linear_velocity = Vector3.RIGHT
	NpcPerceptionService.footsteps(source, _district.definition.footstep_interval)
	assert_false(_district.noises.is_empty())
	var noise: NpcNoise = _district.noises.back()
	assert_false(noise.investigate)
	assert_true(NpcPerceptionService.hear(body, person.profile, noise))
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_eq(awareness.heard_position, noise.position)
	assert_gt(awareness.heard_remaining, 0.0)
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.IDLE, 0.2)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	NpcPerceptionService.emit_noise(source, noise.position, noise.radius)
	assert_true(NpcPerceptionService.hear(body, person.profile, _district.noises.back()))
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.IDLE, 0.2)
	assert_true((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)

## Шаги игрока сохраняют интерес слушателя к месту звука без раскрытия личности и назначения противника.
func test_player_footsteps_still_prompt_anonymous_investigation() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	var person: NpcRecord = _district.people[0]
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.linear_velocity = Vector3.RIGHT
	NpcPerceptionService.footsteps(player, _district.definition.footstep_interval)
	assert_false(_district.noises.is_empty())
	var noise: NpcNoise = _district.noises.back()
	assert_true(noise.investigate)
	assert_true(NpcPerceptionService.hear(body, person.profile, noise))
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.IDLE, 0.2)
	assert_true((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert_null(CombatService.target_for(body))
	assert_true(person.memories.is_empty())

## Наблюдатель выбирает воспринимаемого соседа и теряет фокус за реальным укрытием.
func test_observation_watches_visible_neighbour_and_loses_hidden_focus() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.goal_id = &"activity_1"
	var neighbour: E_DistrictNpc = _stage(3, Vector3(0, 0, -3))
	await get_tree().physics_frame
	await get_tree().physics_frame
	NpcActivityService.observe(body, person, false)
	assert_eq(body.get_relationships(Relationship.new(R_NpcLookTarget.new(), neighbour)).size(), 1)

	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.position = Vector3(0, 1.5, -1.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	NpcActivityService.observe(body, person, false)
	assert_true(body.get_relationships(Relationship.new(R_NpcLookTarget.new(), neighbour)).is_empty())

## Свободная активность однократно выбирает точку окна и запрашивает движение, сохраняя физическое положение.
func test_window_activity_moves_then_observes_an_authored_focus() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.preferred_activities = [DEF_DistrictPlace.Activity.WATCH_WINDOW]
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.idle_elapsed = _district.definition.activity_seconds
	var old_position: Vector3 = body.global_position
	assert_true(NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.IDLE, 0.2))
	assert_eq(person.goal_id, &"activity_0")
	assert_eq(body.global_position, old_position)

	var intent: C_NpcIntent = body.get_component(C_NpcIntent) as C_NpcIntent
	assert_eq(intent.move_position, NpcActivityService.destination(_district.definition.place_for(person.goal_id)))
	var sequence: int = person.activity_sequence
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.IDLE, 0.2)
	assert_eq(person.activity_sequence, sequence)

	var markers: Node3D = Node3D.new()
	markers.name = "DebugMarkers"
	_root.add_child(markers)
	var focus: Marker3D = Marker3D.new()
	focus.name = "RoomClient"
	markers.add_child(focus)
	focus.position = Vector3(8, 2, -4)
	NpcActivityService.observe(body, person, false)
	assert_false(intent.look_uses_entity)
	assert_eq(intent.look_position, focus.global_position)

## Прогулка к магазину требует присутствующего живого торговца и свободной точки остановки.
func test_shop_visit_uses_a_clear_standing_point_and_requires_a_merchant() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.preferred_activities = [DEF_DistrictPlace.Activity.VISIT_SHOP]
	var shopkeeper: E_DistrictNpc = _stage(7, Vector3(30, 0, 0))
	assert_same(NpcActivityService.merchant(), shopkeeper)
	var place: DEF_DistrictPlace = NpcActivityService.choose(body, person)
	assert_not_null(place)
	assert_eq(place.key, &"shop")
	assert_gt(NpcActivityService.destination(place).distance_to(DistrictPopulationService.position_for(place.key)), 1.0)
	DistrictPopulationService.mark_dead(_district.people[7], shopkeeper, 1)
	assert_null(NpcActivityService.choose(body, person))

## Авторский пул имеет совместимые правила и требуемые виды занятий; личные темы разговора необязательны.
func test_authored_profiles_and_activity_types_are_complete() -> void:
	for person: NpcRecord in _district.people:
		assert_true(person.profile.valid_rules(), person.display_name)
	var activities: Array[int] = []
	for place: DEF_DistrictPlace in _district.definition.places:
		if place.kind in [DEF_DistrictPlace.Kind.ACTIVITY, DEF_DistrictPlace.Kind.SHOP]:
			activities.append(place.activity)
	for kind: int in DEF_DistrictPlace.Activity.values():
		assert_true(activities.has(kind))
#endregion

#region Наблюдаемое социальное поведение
## Раненый NPC отступает, освобождает бой и перестаёт блокировать сон преследованием.
func test_wounded_pursuer_releases_combat_and_allows_sleep() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	var player: E_DistrictNpc = _player()
	CombatService.bind_target(body, player)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = health.value * person.profile.pursuit_health_reserve * 0.5
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.target_visible = true
	awareness.has_last_seen = true
	awareness.last_seen_position = player.global_position
	(body.get_component(C_NpcCombat) as C_NpcCombat).phase = C_NpcCombat.Phase.WINDUP
	assert_false(NpcSleepService.blockers().is_empty())
	assert_true(NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.EMERGENCY, 0.2))
	assert_true(awareness.fleeing)
	assert_null(CombatService.target_for(body))
	assert_eq((body.get_component(C_NpcCombat) as C_NpcCombat).phase, C_NpcCombat.Phase.READY)
	assert_true(NpcSleepService.blockers().is_empty())

## Новое утро очищает временное восприятие/страх, сохраняя ID, ранения и личную память.
func test_new_morning_resets_transient_fear_without_resetting_person() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = 31.0
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.fleeing = true
	awareness.heard_remaining = 50.0
	NpcPerceptionService.emit_noise(body, Vector3(5, 0, 0), 20.0)

	var memory: NpcMemory = NpcMemory.new()
	memory.incident_id = &"test/persistent_help"
	person.memories.append(memory)
	DistrictPopulationService.prepare_morning(2)
	assert_same(DistrictPopulationService.body_for(person.npc_id), body)
	assert_eq(health.current, 31.0)
	assert_eq(person.memories.size(), 1)
	var refreshed: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_false(refreshed.fleeing)
	assert_eq(refreshed.heard_remaining, 0.0)
	assert_true(_district.noises.is_empty())

	var brain: Node = body.get_node("Brain")
	DistrictPopulationService.prepare_morning(2)
	assert_same(body.get_node("Brain"), brain)

## Уход означает подчинение лишь при видимом столкновении и учитывается один раз на инцидент.
func test_retreat_requires_visible_confrontation_and_does_not_restart_attack() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.personality = DEF_NpcProfile.Personality.BRAZEN
	person.profile.high_attack_probability = 1.0
	var player: E_DistrictNpc = _player()
	player.linear_velocity = Vector3(0, 0, -3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	NpcPerceptionService.sense(body, person, player, 0.2)

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_true(awareness.player_visible)
	NpcTraitService.tick(body, person, player, 1.0)
	assert_true(person.memories.is_empty())
	CombatService.bind_target(body, player)
	var combat: C_NpcCombat = body.get_component(C_NpcCombat) as C_NpcCombat
	combat.phase = C_NpcCombat.Phase.WINDUP
	NpcTraitService.tick(body, person, player, person.profile.retreat_seconds)
	assert_eq(person.memories.size(), 1)
	assert_eq(person.memories[0].kind, NpcMemory.Kind.SUBMISSION)
	assert_eq(combat.phase, C_NpcCombat.Phase.WINDUP)
	NpcTraitService.tick(body, person, player, 5.0)
	assert_eq(person.memories.size(), 1)
	awareness.player_visible = false
	NpcTraitService.tick(body, person, player, 5.0)
	assert_eq(awareness.retreat_elapsed, 0.0)
	assert_eq(person.memories.size(), 1)

## Короткий взгляд допустим; прекращение взгляда после предупреждения останавливает эскалацию.
func test_gaze_warning_has_a_working_countermeasure() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	person.profile.rules = [rule]
	var player: E_DistrictNpc = _player()
	var camera: Camera3D = Camera3D.new()
	player.add_child(camera)
	camera.position.y = NpcPerceptionService.EYE_HEIGHT
	camera.rotation.y = PI
	camera.current = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	NpcPerceptionService.sense(body, person, player, 0.2)

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	NpcTraitService.tick(body, person, player, rule.warning_seconds * 0.5)
	assert_true(awareness.warned_rules.is_empty())
	NpcTraitService.tick(body, person, player, rule.warning_seconds)
	assert_true(awareness.warned_rules.has(rule.kind))
	camera.rotation.y = 0.0
	NpcTraitService.tick(body, person, player, rule.reaction_seconds + 1.0)
	assert_true(person.memories.is_empty())
	assert_eq(awareness.rule_exposure[rule.kind], 0.0)

## Выключение света снимает светобоязнь, включение останавливает повод хищника темноты.
func test_light_and_darkness_countermeasures_reset_exposure() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	var player: E_DistrictNpc = _player()
	var zone: NpcLightZone = _light_zone()
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	person.profile.rules = [rule]
	await get_tree().physics_frame
	await get_tree().physics_frame
	NpcPerceptionService.sense(body, person, player, 0.2)

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	NpcTraitService.tick(body, person, player, rule.warning_seconds)
	assert_true(awareness.light_distress)
	assert_true(awareness.warned_rules.has(rule.kind))
	zone.enabled = false
	NpcTraitService.tick(body, person, player, rule.reaction_seconds + 1.0)
	assert_false(awareness.light_distress)
	assert_eq(awareness.rule_exposure[rule.kind], 0.0)
	assert_true(person.memories.is_empty())

	rule = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.DARK_PREDATOR
	person.profile.rules = [rule]
	NpcTraitService.tick(body, person, player, rule.warning_seconds)
	assert_true(awareness.warned_rules.has(rule.kind))
	zone.enabled = true
	NpcTraitService.tick(body, person, player, rule.reaction_seconds + 1.0)
	assert_eq(awareness.rule_exposure[rule.kind], 0.0)
	assert_true(person.memories.is_empty())
#endregion

#region Интеграция обслуживания
## Проверка силы использует последнее наблюдаемое уважение/подчинение без скрытых характеристик игрока.
func test_strength_test_uses_latest_observed_response() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.personality = DEF_NpcProfile.Personality.BRAZEN
	person.profile.high_attack_probability = 1.0
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.STRENGTH_TEST
	person.profile.rules = [rule]

	var player: E_DistrictNpc = _player()
	await get_tree().physics_frame
	await get_tree().physics_frame
	NpcPerceptionService.sense(body, person, player, 0.2)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_true(awareness.player_visible)
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"test/respect"), NpcMemory.Reaction.RESPECT)
	NpcTraitService.tick(body, person, player, rule.warning_seconds)
	assert_eq(awareness.rule_exposure[rule.kind], 0.0)
	NpcSocialService.react(body, player, NpcMemory.Kind.SUBMISSION, &"test/later_submission")
	NpcTraitService.tick(body, person, player, rule.warning_seconds)
	assert_gt(awareness.rule_exposure[rule.kind], 0.0)
	assert_true(awareness.warned_rules.has(rule.kind))

## Ожидающий получатель удерживает уличный разговор, сохраняя роль обслуживания без движения к стойке.
func test_queued_street_conversation_holds_the_service_role() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	_service(body, "queued_talk")
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.QUEUED
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(player, body)
	assert_true(context.begin())
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.SERVICE, 0.2)
	assert_eq(agent.phase, C_CustomerAgent.Phase.QUEUED)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert_true(context.can_continue())
	context.end()

## Событие посылки не назначает загадку личности без её собственной особенности.
func test_legacy_order_does_not_override_personality() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	var visit: CustomerVisit = _service(body, "legacy_riddle")
	visit.definition.dialogue_mode = DEF_Customer.DialogueMode.RIDDLE
	visit.definition.introduction = DEF_Customer.Introduction.ANNOUNCE_ORDER
	var context: CustomerDialogueContext = CustomerDialogueContext.new(player, body)
	assert_eq(context.dialogue_cue(), "direct")
	assert_true(CustomerPresentation.uses_quick_visit(visit))

	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.RIDDLE
	_district.people[0].profile.rules = [rule]
	assert_eq(context.dialogue_cue(), "riddle")
	assert_false(CustomerPresentation.uses_quick_visit(visit))
	assert_true(context.answer_riddle_correct())
	assert_eq(context.requested_package_id(), visit.package_id)

## Ресурс обслуживания содержит провокации; подчинение кешируется без ложного исхода заказа.
func test_provocateur_service_keeps_order_and_records_submission_once() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.high_attack_probability = 0.0
	person.profile.low_flee_probability = 0.0
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.PROVOCATEUR
	person.profile.rules = [rule]

	var player: E_DistrictNpc = _player()
	var visit: CustomerVisit = _service(body, "provocateur")
	var context: CustomerDialogueContext = CustomerDialogueContext.new(player, body)
	assert_eq(context.dialogue_cue(), "provocation")
	assert_false(CustomerPresentation.uses_quick_visit(visit))
	assert_true(context.begin())
	assert_same(NpcDialogueService.participant(body), player)
	var resource: DialogueResource = load(CustomerDialogueService.DIALOGUE_PATH) as DialogueResource
	var line: DialogueLine = await resource.get_next_dialogue_line(context.dialogue_cue(), [{"ctx": context}])
	assert_eq(line.responses.size(), 4)
	assert_true((line.responses[1] as DialogueResponse).has_tag("sub"))
	assert_true(context.apply_response_tags(PackedStringArray(["sub"])))
	assert_true(context.apply_response_tags(PackedStringArray(["sub"])))
	assert_eq(person.memories.size(), 1)
	assert_eq(person.memories[0].kind, NpcMemory.Kind.SUBMISSION)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(context.requested_package_id(), visit.package_id)
	context.end()
	assert_null(NpcDialogueService.participant(body))
	DialogueResourceLifecycle.release_runtime_references(resource)

## Разговор не останавливает терпение; уход из обслуживания освобождает связь участника.
func test_service_conversation_keeps_patience_and_releases_on_departure() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	var visit: CustomerVisit = _service(body, "patience")
	visit.definition.patience_seconds = 0.5
	var context: CustomerDialogueContext = CustomerDialogueContext.new(player, body)
	assert_true(context.begin())
	assert_true(context.can_continue())
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.SERVICE, 0.2)
	assert_almost_eq((body.get_component(C_CustomerAgent) as C_CustomerAgent).elapsed, 0.2, 0.001)
	NpcDecisionService.execute_branch(body, C_NpcDecision.Owner.SERVICE, 0.4)
	assert_false(context.can_continue())
	assert_null(NpcDialogueService.participant(body))

## Уход, смерть и прерывание роли закрывают разговор с тем же живым участником.
func test_service_dialogue_closes_when_participant_leaves_or_dies() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	var visit: CustomerVisit = _service(body, "interrupted")
	var context: CustomerDialogueContext = CustomerDialogueContext.new(player, body)
	assert_true(context.begin())
	player.global_position = Vector3(0, 0, -20)
	assert_false(context.can_continue())
	context.end()
	assert_null(NpcDialogueService.participant(body))
	player.global_position = Vector3(0, 0, -3)
	assert_true(context.begin())
	player.add_component(C_Death.new())
	assert_false(context.can_continue())
	NpcServiceRole.release(body, visit.visit_id)
	assert_null(NpcDialogueService.participant(body))
#endregion

#region Физическое движение и опасности
func _flat_map() -> Dictionary[StringName, RID]:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.cell_height = 0.1
	mesh.vertices = PackedVector3Array([Vector3(-100, 0, -100), Vector3(-100, 0, 100), Vector3(100, 0, 100), Vector3(100, 0, -100)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var map: RID = NavigationServer3D.map_create()
	var region: RID = NavigationServer3D.region_create()
	NavigationServer3D.map_set_cell_height(map, mesh.cell_height)
	NavigationServer3D.map_set_active(map, true)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, mesh)
	for frame_index: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO) == region:
			break
	return {&"map": map, &"region": region}

## Физическое зависание прекращает формально достижимую задачу и освобождает зарезервированный предмет.
func test_stalled_reachable_route_releases_pickup() -> void:
	var body: E_DistrictNpc = _stage(0, Vector3(-8, 0, 0))
	var person: NpcRecord = _district.people[0]
	var native: Dictionary[StringName, RID] = await _flat_map()
	body.navigation_agent.set_navigation_map(native[&"map"])
	var loot: Entity = Entity.new()
	_world.add_entity(loot)
	body.add_relationship(Relationship.new(R_NpcLootTarget.new(), loot))
	NpcIntentArbiter.acquire(body, C_NpcDecision.Owner.IDLE, "Test pickup")
	NpcIntentArbiter.move_to(body, Vector3(8, 0, 0), 0.3, C_NpcDecision.Owner.IDLE)
	NpcRouteService.tick(body, person, 0.2)
	NpcRouteService.process_pending(_district)
	assert_true((body.get_component(C_NpcRoute) as C_NpcRoute).reachable)
	NpcRouteService.tick(body, person, _district.definition.route_timeout + 0.1)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert_true(body.get_relationships(Relationship.new(R_NpcLootTarget.new(), loot)).is_empty())
	NavigationServer3D.free_rid(native[&"region"])
	NavigationServer3D.free_rid(native[&"map"])

## Зависший подход к дому освобождает дверь, сохраняя невыполненное обещание доставки.
func test_stalled_home_route_releases_meeting_without_false_delivery() -> void:
	var body: E_DistrictNpc = _stage(0, Vector3(-8, 0, 0))
	var person: NpcRecord = _district.people[0]
	var player: E_DistrictNpc = _player()
	var visit: CustomerVisit = _service(body, "stalled_home")
	NpcServiceRole.release(body, visit.visit_id)
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	var job: NpcHomeDelivery = NpcHomeDelivery.new()
	job.job_id = &"home/test/stalled"
	job.npc_id = person.npc_id
	job.visit_id = visit.visit_id
	job.address_id = person.home_id
	_district.home_deliveries.append(job)

	var door: Entity = null
	for candidate: Entity in _world.query.with_all([C_NpcAddress]).execute():
		if (candidate.get_component(C_NpcAddress) as C_NpcAddress).address_id == person.home_id:
			door = candidate
	assert_true(NpcHomeDeliveryService.knock(player, door))
	var native: Dictionary[StringName, RID] = await _flat_map()
	body.navigation_agent.set_navigation_map(native[&"map"])
	NpcRouteService.tick(body, person, 0.2)
	NpcRouteService.process_pending(_district)
	assert_true((body.get_component(C_NpcRoute) as C_NpcRoute).reachable)
	NpcRouteService.tick(body, person, _district.definition.route_timeout + 0.1)
	assert_null(NpcHomeDeliveryService.meeting_for(body))
	assert_false(body.has_component(C_CustomerAgent))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_true(NpcHomeDeliveryService.knock(player, door))
	NavigationServer3D.free_rid(native[&"region"])
	NavigationServer3D.free_rid(native[&"map"])

## Прогноз риска учитывает фактические множители голода и замедление тяжёлым грузом.
func test_route_risk_matches_actual_speed_modifiers() -> void:
	var body: E_DistrictNpc = _stage(0)
	var fire: Entity = (load("res://content/entities/hazards/npc_fire_aura.tscn") as PackedScene).instantiate() as Entity
	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = load("res://content/definitions/gameplay/hazards/def_npc_fire_aura.tres") as DEF_ToxicArea
	_world.add_entity(fire, [hazard])
	(fire as Node as Node3D).global_position = Vector3(0, 1, 0)
	var path: PackedVector3Array = PackedVector3Array([Vector3(-8, 0, 0), Vector3(8, 0, 0)])
	var hunger: C_Hunger = body.get_component(C_Hunger) as C_Hunger
	hunger.value = 0.0

	var ordinary: float = NpcRouteService.expected_damage(body, path)
	hunger.value = 100.0
	assert_lt(NpcRouteService.expected_damage(body, path), ordinary)
	hunger.value = 0.0
	if not body.has_component(C_Strength):
		body.add_component(C_Strength.new())
	var strength: C_Strength = body.get_component(C_Strength) as C_Strength
	if not body.has_component(C_CarryLoad):
		body.add_component(C_CarryLoad.new())

	var load_state: C_CarryLoad = body.get_component(C_CarryLoad) as C_CarryLoad
	load_state.active = true
	load_state.mass_kg = (CarryLoadPolicy.minimum_mass_kg(strength) + CarryLoadPolicy.maximum_mass_kg(strength)) * 0.5
	assert_gt(NpcRouteService.expected_damage(body, path), ordinary)

## Движущаяся опасная сфера вызывает локальный обход без подходящих узлов уличного графа.
func test_native_route_replans_around_moving_fire() -> void:
	var body: E_DistrictNpc = _stage(0, Vector3(-8, 0, 0))
	var person: NpcRecord = _district.people[0]
	var fire: Entity = (load("res://content/entities/hazards/npc_fire_aura.tscn") as PackedScene).instantiate() as Entity
	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = load("res://content/definitions/gameplay/hazards/def_npc_fire_aura.tres") as DEF_ToxicArea
	_world.add_entity(fire, [hazard])
	(fire as Node as Node3D).global_position = Vector3(0, 1, 0)

	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.cell_height = 0.1
	mesh.vertices = PackedVector3Array([Vector3(-20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(20, 0, -20)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var map: RID = NavigationServer3D.map_create()
	var region: RID = NavigationServer3D.region_create()
	NavigationServer3D.map_set_cell_height(map, mesh.cell_height)
	NavigationServer3D.map_set_active(map, true)
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, mesh)
	for frame_index: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO) == region:
			break

	assert_eq(NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO), region)
	var goal: Vector3 = Vector3(8, 0, 0)
	var path: PackedVector3Array = NpcRouteService.plan(body, person, body.global_position, goal, map)
	assert_false(path.is_empty())
	assert_eq(NpcRouteService.expected_damage(body, path), 0.0)
	assert_gt(path.size(), 2)
	(fire as Node as Node3D).global_position = Vector3(0, 1, 12)
	var revised: PackedVector3Array = NpcRouteService.plan(body, person, body.global_position, goal, map)
	assert_eq(revised.size(), 2)
	assert_eq(NpcRouteService.expected_damage(body, revised), 0.0)
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
#endregion
