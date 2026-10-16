extends "res://tests/gut/test_district_population.gd"
## Production district integration: all ten archetypes, native body construction and save restore.

const ARCHETYPE_NAMES: Array[String] = [
	"night_hunter",
	"fire_elemental",
	"shy",
	"creepy",
	"brute",
	"hag",
	"weeping_angel",
	"lost",
	"chain_devil",
	"vampire",
	"lost_visitor",
	"shy_visitor",
]
const LIVE_DISTRICT: String = ("res://content/domains/npc/definitions/def_district_default.tres")
const LEGACY_DISTRICT: String = (
	"res://content/domains/npc/definitions/" + "def_district_legacy_fixture.tres"
)


#region Production fixture boundary
func _district_definition_path() -> String:
	return LIVE_DISTRICT
#endregion


#region Authored participation and native publication
func test_live_roster_preserves_identity_roles_and_participation_contracts() -> void:
	var legacy: DEF_District = load(LEGACY_DISTRICT) as DEF_District
	var expected_people: Array[NpcRecord] = NpcPopulationRules.initial_records(
		legacy,
		1,
		DayPhaseQueries.current().clock.world_seed,
		1,
	)
	assert_eq(_district.people.size(), 12)
	assert_eq(_district.definition.resident_count, 8)
	assert_eq(_district.definition.visitor_count, 4)
	for slot: int in _district.people.size():
		var person: NpcRecord = _district.people[slot]
		var expected: NpcRecord = expected_people[slot]
		assert_eq(person.npc_id, expected.npc_id)
		assert_eq(person.home_id, expected.home_id)
		assert_eq(person.portal_id, expected.portal_id)
		assert_eq(person.exit_id, expected.exit_id)
		assert_eq(person.recipient_key, expected.recipient_key)
		assert_eq(person.profile.resident, slot < 8)
		assert_eq(person.profile.merchant, slot == 7)
		assert_eq(person.profile.key, StringName("archetype/" + ARCHETYPE_NAMES[slot]))
		assert_eq(
			person.profile.resource_path,
			"res://content/domains/npc/definitions/def_npc_archetype_%s.tres"
			% ARCHETYPE_NAMES[slot],
		)
		for day_index: int in range(1, 9):
			for phase: int in range(C_DayCycle.Phase.MORNING, C_DayCycle.Phase.NIGHT + 1):
				assert_eq(
					person.profile.schedule.location_for(day_index, phase),
					expected.profile.schedule.location_for(day_index, phase),
				)
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		assert_not_null(body)
		assert_eq((body.get_component(C_NpcIdentity) as C_NpcIdentity).npc_id, person.npc_id)
		assert_not_null(body.get_node_or_null("Brain") as BTPlayer)
		assert_not_null(body.get_node_or_null("VeilPresence") as Node3D)


func test_live_bodies_compile_selected_capabilities_and_dialogue_variation() -> void:
	for person: NpcRecord in _district.people:
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		assert_true(person.profile.name_variants.has(person.display_name))
		assert_eq(person.profile.dialogue_variants.size(), 2)
		assert_true(person.profile.dialogue_variants.has(person.variation.dialogue_path))
		assert_true(ResourceLoader.exists(person.variation.dialogue_path))
		assert_true(
			NpcVariationRules.valid_variation(
				person.profile,
				person.variation,
				DayPhaseQueries.current().clock.world_seed,
				person.npc_id,
			)
		)
		assert_eq(
			(body.get_component(C_ReceiverTraits) as C_ReceiverTraits).traits,
			person.profile.receiver_traits,
		)
		assert_eq(
			(body.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze).rule,
			NpcGazeQueries.selected_rule(person.rules_for()),
		)
		assert_eq(
			(body.get_component(C_NpcPride) as C_NpcPride).rule,
			NpcPrideRules.selected_rule(person.rules_for()),
		)
		assert_eq(
			(body.get_component(C_NpcStalking) as C_NpcStalking).rule,
			NpcStalkingRules.selected_rule(person.rules_for()),
		)
		var expected_damage: Dictionary[int, float] = person.profile.damage_multipliers.duplicate()
		if person.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null:
			expected_damage[DamageRequest.Type.FIRE] = 0.0
		assert_eq(
			(body.get_component(C_DamageResistance) as C_DamageResistance).multipliers,
			expected_damage,
		)
#endregion


#region Current schema and passive native reconstruction
func test_all_live_archetypes_restore_as_native_bodies_without_reroll_or_health_reset() -> void:
	var identities: Array[StringName] = []
	var saved_people: Dictionary[StringName, Dictionary] = { }
	for person: NpcRecord in _district.people:
		identities.append(person.npc_id)
		saved_people[person.npc_id] = SaveDataCodec.encode(person) as Dictionary
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		(body.get_component(C_Health) as C_Health).current = 37.0
		var strength: C_Strength = body.get_component(C_Strength) as C_Strength
		strength.base = 0.1
		strength.value = 0.1
		(body.get_component(C_NpcRoute) as C_NpcRoute).rejected_refuge_points.append(
			Vector3(999, 0, 999),
		)
		(body.get_component(C_NpcRoute) as C_NpcRoute).refuge_direction_offset = 7
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_eq(snapshot.version, AutosaveStore.SCHEMA_VERSION)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for npc_id: StringName in identities:
		_world.remove_entity(NpcPopulationQueries.body_for(npc_id))
	await get_tree().process_frame
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	for npc_id: StringName in identities:
		var restored: NpcRecord = NpcPopulationQueries.person_for(npc_id)
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
		assert_not_null(body)
		assert_eq(SaveDataCodec.encode(restored), saved_people[npc_id])
		assert_eq((body.get_component(C_Health) as C_Health).current, 37.0)
		assert_eq((body.get_component(C_Strength) as C_Strength).base, 0.1)
		assert_eq((body.get_component(C_Strength) as C_Strength).value, 0.1)
		assert_eq((body.get_component(C_NpcVeil) as C_NpcVeil).form, C_NpcVeil.Form.VISIBLE)
		assert_false((body.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze).observed)
		assert_true(
			(body.get_component(C_NpcRoute) as C_NpcRoute).rejected_refuge_points.is_empty(),
		)
		assert_not_null(body.get_node_or_null("Brain") as BTPlayer)
		assert_eq((body.get_component(C_NpcRoute) as C_NpcRoute).refuge_direction_offset, 0)
		(body.get_component(C_NpcRoute) as C_NpcRoute).rejected_refuge_points.append(
			Vector3(999, 0, 999),
		)
		(body.get_component(C_NpcRoute) as C_NpcRoute).refuge_direction_offset = 7
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_world.query.with_all([C_NpcIdentity]).execute().size(), 12)
	for npc_id: StringName in identities:
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
		assert_eq((body.get_component(C_Strength) as C_Strength).base, 0.1)
		assert_eq((body.get_component(C_Strength) as C_Strength).value, 0.1)
		assert_eq((body.get_component(C_NpcRoute) as C_NpcRoute).refuge_direction_offset, 0)
		assert_true(
			(body.get_component(C_NpcRoute) as C_NpcRoute).rejected_refuge_points.is_empty(),
		)


func test_previous_schema_rejects_before_live_roster_mutation() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	snapshot.version = AutosaveStore.SCHEMA_VERSION - 1
	# Schema21 NPCs predate the carry recipe and have no persisted Strength entry.
	for record: Dictionary in snapshot.entities:
		var components: Array = record.components as Array
		for index: int in range(components.size() - 1, -1, -1):
			if (components[index] as Dictionary).type == (C_Strength as Script).resource_path:
				components.remove_at(index)
	assert_false(WorldSnapshotService.can_restore(snapshot, _root))
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	var slot_path: String = "user://gut_npc_carry_previous_schema.pvzh"
	assert_eq(AutosaveStore.write(snapshot, slot_path), OK)
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(slot_path)
	var autosave: C_Autosave = C_Autosave.new()
	autosave.path = slot_path
	assert_false(NightSaveService.restore_startup(_root, autosave))
	assert_eq(autosave.rejected_path, slot_path)
	assert_eq(FileAccess.get_file_as_bytes(slot_path), original_bytes)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path)), OK)
	assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
#endregion
