extends "res://tests/gut/test_district_population.gd"
## Регрессии участия сообщества, сохранности имущества, уличных диалогов и воспринимаемых конфликтов.

#region Контракты сообщества
## Отключение вне карты сохраняет предметы владельца; возвращение не выдаёт ещё одну стопку.
func test_absence_preserves_owned_inventory() -> void:
	_world.add_observer(O_InventoryLifecycle.new())
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var food: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_npc_meat.tres") as DEF_InventoryItem
	assert_true(InventoryService.grant(body, food, 2))
	var item: Entity = InventoryService.items(body)[0]
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	assert_same(InventoryService.owner_for(item), body)
	assert_true(_world.entity_to_archetype.has(item))
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	assert_eq(InventoryService.items(body).size(), 1)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)

## Торговец сохраняет каталог; замена получает отдельное имя и адресный alias будущих заказов.
func test_replacement_is_new_person_with_existing_address_alias() -> void:
	var first: NpcRecord = _district.people[0]
	var merchant: NpcRecord = _district.people[7]
	var original_name: String = merchant.display_name
	var original_alias: StringName = merchant.recipient_key
	DistrictPopulationService.mark_dead(first, DistrictPopulationService.body_for(first.npc_id), 1)
	DistrictPopulationService.mark_dead(merchant, DistrictPopulationService.body_for(merchant.npc_id), 1)
	DistrictPopulationService.prepare_morning(3)

	var replacement: NpcRecord = _district.people.back()
	assert_true(replacement.profile.merchant)
	assert_ne(replacement.display_name, original_name)
	assert_eq(replacement.recipient_key, original_alias)
	var body: E_DistrictNpc = DistrictPopulationService.body_for(replacement.npc_id)
	assert_not_null(body.get_component(C_Trader) as C_Trader)
	assert_not_null((body.get_component(C_Trader) as C_Trader).profile)
	assert_eq(replacement.memories.size(), 0)

## NPC однократно расходует реальный мясной предмет через обычное использование инвентаря.
func test_npc_consumes_real_meat_once() -> void:
	var body: E_DistrictNpc = DistrictPopulationService.body_for(_district.people[0].npc_id)
	var food: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_npc_meat.tres") as DEF_InventoryItem
	assert_true(InventoryService.grant(body, food, 1))
	var hunger: C_Hunger = body.get_component(C_Hunger) as C_Hunger
	hunger.value = 50.0
	var item: Entity = InventoryService.items(body)[0]
	assert_true(InventoryService.use(body, item))
	assert_lt(hunger.value, 50.0)
	assert_eq(InventoryService.items(body).size(), 0)
	assert_false(InventoryService.use(body, item))

## Авторские уличные ветви доступны через закреплённый Dialogue Manager и явные entry cues.
func test_street_dialogue_resource_has_explicit_entry_cues() -> void:
	var resource: DialogueResource = load("res://content/dialogue/npc_street.dialogue") as DialogueResource
	assert_not_null(resource)
	if resource != null:
		assert_true(resource.cues.has("street"))
		assert_true(resource.cues.has("provocation"))

## Самостоятельный конфликт расходует бюджет фазы; защита жертвы остаётся доступной.
func test_phase_budget_does_not_block_self_defense() -> void:
	var attacker: E_DistrictNpc = _stage_person(1, Vector3.ZERO)
	var victim: E_DistrictNpc = _stage_person(3, Vector3(0, 0, -2))
	var second: E_DistrictNpc = _stage_person(2, Vector3(1, 0, 0))
	_district.people[1].profile.initiates_conflicts = true
	_district.people[2].profile.initiates_conflicts = true
	(attacker.get_component(C_Hunger) as C_Hunger).value = 100.0
	(second.get_component(C_Hunger) as C_Hunger).value = 100.0

	var victim_profile: DEF_NpcProfile = _district.people[3].profile
	victim_profile.personality = DEF_NpcProfile.Personality.AGGRESSIVE
	victim_profile.high_attack_probability = 1.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(NpcCommunityService.begin_conflict(attacker, _district.people[1], victim))
	assert_eq(_district.ambient_conflicts, 1)
	assert_false(NpcCommunityService.begin_conflict(second, _district.people[2], victim))
	assert_eq(NpcSocialService.react(victim, attacker, NpcMemory.Kind.ATTACK, &"test/defense"), NpcMemory.Reaction.ATTACK)
	assert_same(CombatService.target_for(victim), attacker)
	assert_eq(_district.ambient_conflicts, 1)

## Свидетель запоминает видимого виновника смерти; стена препятствует атрибуции.
func test_killing_witness_requires_visible_actor_and_victim() -> void:
	var witness: E_DistrictNpc = _stage_person(0, Vector3.ZERO)
	var attacker: E_DistrictNpc = _stage_person(3, Vector3(-0.6, 0, -3))
	var victim: E_DistrictNpc = _stage_person(4, Vector3(0.6, 0, -3))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(NpcPerceptionService.can_see(witness, attacker, _district.people[0].profile))
	victim.add_component(C_Death.new())
	DistrictPopulationService.mark_dead(_district.people[4], victim, 1)

	var result: DamageResult = DamageResult.new()
	result.request = DamageRequest.new()
	result.request.instigator = attacker
	result.request.target = victim
	result.request.combat_context = CombatContext.new()
	result.request.incident_id = &"test/witnessed_killing"
	result.outcome = DamageResult.Outcome.HEALTH_DEPLETED
	result.applied_amount = 100.0
	result.world_pose = victim.global_transform
	NpcSocialService.observe_damage(result)
	assert_eq(_district.people[0].memories.size(), 1)
	assert_eq(_district.people[0].memories[0].kind, NpcMemory.Kind.KILLING)
	assert_eq(_district.people[0].memories[0].actor_id, _district.people[3].npc_id)

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
	result.request.incident_id = &"test/hidden_killing"
	NpcSocialService.observe_damage(result)
	assert_eq(_district.people[0].memories.size(), 1)

## Предмет резервируется одним участником; приоритетное прерывание сразу освобождает резервирование.
func test_loot_claim_is_exclusive_until_interrupted() -> void:
	var first: E_DistrictNpc = _stage_person(0, Vector3.ZERO)
	var second: E_DistrictNpc = _stage_person(3, Vector3(2, 0, 0))
	var pickup: Entity = (load("res://content/entities/inventory/npc_meat_pickup.tscn") as PackedScene).instantiate() as Entity
	_world.add_entity(pickup)
	(pickup as Node as Node3D).global_position = Vector3(0, 0, -2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(NpcCommunityService.idle(first, _district.people[0]))
	assert_eq(first.get_relationships(Relationship.new(R_NpcLootTarget.new(), pickup)).size(), 1)
	assert_false(NpcCommunityService.idle(second, _district.people[3]))
	NpcCommunityService.cancel_activity(first)
	assert_true(NpcCommunityService.idle(second, _district.people[3]))
	assert_eq(second.get_relationships(Relationship.new(R_NpcLootTarget.new(), pickup)).size(), 1)

func _stage_person(index: int, point: Vector3) -> E_DistrictNpc:
	var person: NpcRecord = _district.people[index]
	person.profile = person.profile.duplicate() as DEF_NpcProfile
	person.profile.rules = []
	person.profile.dark_vision_fraction = 1.0
	person.profile.vision_angle = 360.0
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	body.place_at(point)
	body.freeze = true
	return body
#endregion
