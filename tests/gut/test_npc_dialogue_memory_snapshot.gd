extends "res://tests/gut/test_district_population.gd"
## Реальный районный snapshot, изолированный слот и отказ до изменения живого World.

const MEMORY_SAVE: String = "user://gut_npc_dialogue_memory.pvzh"


#region Disk restore и preflight
func test_malformed_author_memory_rejects_before_live_mutation() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for invalid: String in ["missing_field", "object_type", "typed_mismatch", "false_tag"]:
		var malformed: Dictionary = snapshot.duplicate(true)
		for record: Dictionary in malformed.entities:
			for data: Dictionary in record.components:
				if String(data.type) != C_District.resource_path:
					continue
				var fields: Dictionary = data.fields.people[0].fields as Dictionary
				match invalid:
					"missing_field":
						fields.erase("dialogue_values")
					"object_type":
						fields.dialogue_values = { "kind": TYPE_OBJECT, "value": null }
					"typed_mismatch":
						fields.dialogue_values = DialogueValueCodec.encode({ 1: 2 }, "bad", 16)
					"false_tag":
						var tags: Dictionary[StringName, bool] = { &"visited": false }
						fields.dialogue_tags = DialogueValueCodec.encode(tags, "bad", 16)
		assert_false(WorldSnapshotService.restore(malformed, _root), invalid)
		assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
		assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
		assert_true(person.dialogue_values.is_empty())


func test_disk_roundtrip_restores_retained_and_recreated_body_with_null_and_typed_values() -> void:
	var person: NpcRecord = _district.people[0]
	var npc_id: StringName = person.npc_id
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	var numbers: Array[int] = [1, 2, 3]
	NpcDialogueMemoryService.set_tag(person, &"visited")
	NpcDialogueMemoryService.set_tag(person, &"type")
	NpcDialogueMemoryService.set_tag(person, &"definition")
	NpcDialogueMemoryService.set_val(person, &"null", null)
	NpcDialogueMemoryService.set_val(person, &"typed", numbers)
	NpcDialogueMemoryService.set_val(
		person,
		&"reserved",
		{ "type": "x", "definition": "y", "invalid": true },
	)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, MEMORY_SAVE), OK)
	var disk: Dictionary = AutosaveStore.read(MEMORY_SAVE)
	NpcDialogueMemoryService.set_val(person, &"typed", "mutated")
	assert_true(WorldSnapshotService.restore(disk, _root))
	assert_same(NpcPopulationQueries.body_for(npc_id), body)
	_assert_restored_memory(npc_id)
	_world.remove_entity(body)
	await get_tree().process_frame
	assert_true(WorldSnapshotService.restore(disk, _root))
	assert_not_null(NpcPopulationQueries.body_for(npc_id))
	_assert_restored_memory(npc_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MEMORY_SAVE))


func _assert_restored_memory(npc_id: StringName) -> void:
	var restored: NpcRecord = NpcPopulationQueries.person_for(npc_id)
	assert_true(restored.dialogue_tags[&"visited"])
	assert_true(restored.dialogue_tags[&"type"])
	assert_true(restored.dialogue_tags[&"definition"])
	assert_true(restored.dialogue_values.has(&"null"))
	assert_null(restored.dialogue_values[&"null"])
	assert_false(restored.dialogue_values.has(&"missing"))
	var numbers: Array = restored.dialogue_values[&"typed"] as Array
	assert_eq(numbers.get_typed_builtin(), TYPE_INT)
	assert_eq(numbers, [1, 2, 3])
	assert_eq(
		restored.dialogue_values[&"reserved"],
		{ "type": "x", "definition": "y", "invalid": true },
	)


func test_unsupported_memory_fails_night_preflight_before_replacing_a_good_file() -> void:
	var person: NpcRecord = _district.people[0]
	var good: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_eq(AutosaveStore.write(good, MEMORY_SAVE), OK)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(MEMORY_SAVE)
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	var state: C_Autosave = C_Autosave.new()
	state.path = MEMORY_SAVE
	session.add_component(state)
	var node: Node = Node.new()
	person.dialogue_values[&"unsupported"] = { "nested": [node] }
	DayPhaseQueries.current().phase = C_DayCycle.Phase.NIGHT
	var system: S_NightSave = S_NightSave.new()
	_world.add_system(system)
	_world.process(0.1, "Storage")
	assert_eq(state.last_error, ERR_INVALID_DATA)
	assert_true(state.prepared_snapshot.is_empty())
	assert_eq(FileAccess.get_file_as_bytes(MEMORY_SAVE), original)
	person.dialogue_values.clear()
	node.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MEMORY_SAVE))


func test_previous_schema_is_rejected_without_replacing_file_or_live_person() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	snapshot.version = AutosaveStore.SCHEMA_VERSION - 1
	assert_eq(AutosaveStore.write(snapshot, MEMORY_SAVE), OK)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(MEMORY_SAVE)
	var person: NpcRecord = _district.people[0]
	var state: C_Autosave = C_Autosave.new()
	state.path = MEMORY_SAVE
	assert_false(NightSaveService.restore_startup(_root, state))
	assert_eq(state.rejected_path, MEMORY_SAVE)
	assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
	assert_eq(FileAccess.get_file_as_bytes(MEMORY_SAVE), original)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MEMORY_SAVE))
#endregion
