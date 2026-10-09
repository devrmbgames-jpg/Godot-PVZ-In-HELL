extends "res://tests/gut/test_district_population.gd"
## On-disk participation roundtrip and fresh reconstruction use the existing save boundary.

const SAVE_PATH: String = "user://gut_npc_participation_modes.pvzh"
const ITEM_PATH: String = "res://content/domains/inventory/definitions/def_item_npc_meat.tres"


#region Retained actor persistence
## Both modes retain body, HP, owned item, pose and calendar metadata through repeated reloads.
func test_active_and_dormant_disk_roundtrip_preserves_durable_state() -> void:
	_world.add_observer(O_InventoryLifecycle.new())
	var expected: Dictionary[StringName, Dictionary] = { }
	for index: int in 2:
		var person: NpcRecord = _district.people[index]
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		assert_true(
			DistrictPopulationService.set_placement(
				person,
				body,
				NpcRecord.Placement.STREET,
				&"test_setup",
				false,
				Vector3(-20.0 - index * 4.0, 0.0, 0.0),
			)
		)
		var health: C_Health = body.get_component(C_Health) as C_Health
		health.current = 41.0 + index
		assert_true(InventoryService.grant(body, load(ITEM_PATH) as DEF_InventoryItem, 3 + index))
		var item: Entity = InventoryService.items(body)[0]
		if index == 1:
			DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.HOME)
		expected[person.npc_id] = {
			"body": body,
			"entity_id": body.id,
			"pose": body.global_transform,
			"placement": person.placement,
			"health": health.current,
			"item_id": item.id,
			"quantity": 3 + index,
			"goal": person.goal_id,
			"day": person.planned_day,
			"phase": person.planned_phase,
			"complete": person.phase_complete,
			"cadence": person.cadence_elapsed_ticks,
		}
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	var loaded: Dictionary = AutosaveStore.read(SAVE_PATH)
	assert_true(WorldSnapshotService.valid(loaded, _root))
	for reload_index: int in 2:
		for body: E_DistrictNpc in [
			expected[_district.people[0].npc_id]["body"],
			expected[_district.people[1].npc_id]["body"],
		]:
			(body.get_component(C_Health) as C_Health).current = 90.0
		assert_true(WorldSnapshotService.restore(loaded, _root))
		for npc_id: StringName in expected:
			_assert_saved_actor(npc_id, expected[npc_id])
		assert_eq(_world.query.with_all([C_NpcIdentity]).execute().size(), 12)
		assert_eq(DayPhaseQueries.current().day_index, 1)
		assert_eq(DayPhaseQueries.current().phase, C_DayCycle.Phase.MORNING)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _assert_saved_actor(npc_id: StringName, expected: Dictionary) -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(npc_id)
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	assert_same(body, expected["body"])
	assert_eq(body.id, expected["entity_id"])
	assert_eq(body.global_transform, expected["pose"])
	assert_eq(person.placement, expected["placement"])
	assert_eq((body.get_component(C_Health) as C_Health).current, expected["health"])
	assert_eq(person.goal_id, expected["goal"])
	assert_eq(person.planned_day, expected["day"])
	assert_eq(person.planned_phase, expected["phase"])
	assert_eq(person.phase_complete, expected["complete"])
	assert_eq(person.cadence_elapsed_ticks, expected["cadence"])
	var item: Entity = _world.entity_id_registry.get(expected["item_id"]) as Entity
	assert_not_null(item)
	assert_same(InventoryService.owner_for(item), body)
	assert_eq(
		(item.get_component(C_InventoryItem) as C_InventoryItem).quantity,
		expected["quantity"],
	)
	var active: bool = person.placement == NpcRecord.Placement.STREET
	assert_eq(body.enabled, active)
	assert_eq(body.freeze, not active)
	assert_eq(body.animation_player.can_process(), active)
	assert_eq((body.get_node("Brain") as BTPlayer).active, active)
#endregion


#region Fresh dormant reconstruction
## An absent saved dormant body is reconstructed once, remains dormant and reuses its stable ID.
func test_missing_dormant_body_restores_identity_and_dormancy() -> void:
	var person: NpcRecord = _district.people[0]
	var npc_id: StringName = person.npc_id
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	var stable_id: String = body.id
	(body.get_component(C_Health) as C_Health).current = 37.0
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	_world.remove_entity(body)
	await get_tree().process_frame
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	var restored: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	assert_not_null(restored)
	assert_eq(restored.id, stable_id)
	assert_eq((restored.get_component(C_Health) as C_Health).current, 37.0)
	assert_false(restored.enabled)
	assert_true(restored.freeze)
	assert_eq(restored.collision_layer, 0)
	assert_false(restored.animation_player.can_process())
	assert_false((restored.get_node("Brain") as BTPlayer).active)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_same(NpcPopulationQueries.body_for(npc_id), restored)
	assert_eq(_world.query.with_all([C_NpcIdentity]).execute().size(), 12)
#endregion
