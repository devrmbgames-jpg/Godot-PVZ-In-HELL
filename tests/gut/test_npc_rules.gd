extends "res://tests/gut/test_district_population.gd"
## Регрессии реального иммунитета, одноразовых реакций характера и риска маршрута.

#region Характер и врождённые особенности
## Фактический огненный урон и прогноз риска совпадают для обычного/иммунного получателя.
func test_fire_immunity_matches_real_damage_and_route_risk() -> void:
	_world.add_observer(O_Damage.new())
	var immune: E_DistrictNpc = DistrictPopulationService.body_for(_district.people[1].npc_id)
	var normal: E_DistrictNpc = DistrictPopulationService.body_for(_district.people[0].npc_id)
	var fire: Entity = (load("res://content/entities/hazards/npc_fire_aura.tscn") as PackedScene).instantiate() as Entity
	var config: DEF_ToxicArea = load("res://content/definitions/gameplay/hazards/def_npc_fire_aura.tres") as DEF_ToxicArea
	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = config
	_world.add_entity(fire, [hazard])
	(fire as Node as Node3D).global_position = Vector3(50, 1, 8)

	var path: PackedVector3Array = PackedVector3Array([Vector3(45, 0, 8), Vector3(55, 0, 8)])
	assert_eq(NpcRouteService.expected_damage(immune, path), 0.0)
	assert_gt(NpcRouteService.expected_damage(normal, path), 0.0)
	for receiver: Entity in [immune, normal]:
		var hit: DamageRequest = DamageRequest.new()
		hit.target = receiver
		hit.source = fire
		hit.amount = 10.0
		hit.damage_type = DamageRequest.Type.FIRE
		DamageRequestService.submit(hit)

	var immune_health: C_Health = immune.get_component(C_Health) as C_Health
	var normal_health: C_Health = normal.get_component(C_Health) as C_Health
	assert_eq(immune_health.current, immune_health.value)
	assert_eq(normal_health.current, normal_health.value - 10.0)

## Повтор того же инцидента сохраняет реакцию через фазу/диалог; новый инцидент учитывается отдельно.
func test_reaction_is_cached_and_new_incident_is_distinct() -> void:
	var person: NpcRecord = _district.people[2]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var player: Entity = Entity.new()
	player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_world.add_entity(player)
	var reaction: NpcMemory.Reaction = NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"test/threat")
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"test/threat"), reaction)
	assert_eq(person.memories.size(), 1)
	NpcSocialService.react(body, player, NpcMemory.Kind.JOKE, &"test/joke")
	assert_eq(person.memories.size(), 2)

## Недостаточный запас HP запрещает рискованный путь преследования.
func test_pursuit_risk_requires_health_reserve() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var target: E_DistrictNpc = DistrictPopulationService.body_for(_district.people[3].npc_id)
	CombatService.bind_target(body, target)
	var health: C_Health = body.get_component(C_Health) as C_Health
	assert_true(NpcRouteService.acceptable(body, person, 20.0))
	health.current = health.value * person.profile.pursuit_health_reserve
	assert_false(NpcRouteService.acceptable(body, person, 1.0))
#endregion
