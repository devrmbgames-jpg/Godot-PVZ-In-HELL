extends GutTest
## Авторский пилот через production construction, closed snapshot и retained/fresh disk restore.

const PILOT_PATH: String = (
	"res://content/domains/npc/definitions/def_district_authored_pilot.tres"
)
const SAVE_PATH: String = "user://gut_npc_authored_population.pvzh"
const ENTITY_SCRIPT: Script = preload("res://addons/gecs/ecs/entity.gd")

var _root: Node3D
var _world: World
var _district: C_District


#region Real district fixture
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	NpcCustomerComposition.install(_world)
	_world.add_observer(O_WalletDay.new())
	_world.add_observer(O_DistrictLifecycle.new())
	_world.add_observer(O_CustomerPlanning.new())
	var owner_node: Node = Node.new()
	owner_node.set_script(ENTITY_SCRIPT)
	var owner: Entity = owner_node as Entity
	var recipe: C_District = C_District.new()
	recipe.definition = load(PILOT_PATH)
	owner.component_resources = [recipe, C_DayCycle.new()]
	_world.add_entity(owner)
	_district = owner.get_component(C_District) as C_District
	assert_true(DistrictPopulationService.initialize())


func after_each() -> void:
	for actor: Entity in _world.entities.duplicate():
		if is_instance_valid(actor):
			_world.remove_entity(actor)
	_world.purge(false)
	ECS.world = null
	_root.free()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
#endregion


#region Identity and supported snapshots
func test_live_roster_uses_explicit_cards_and_reserves_the_next_free_id() -> void:
	assert_eq(_district.people.size(), 3)
	assert_eq(_district.next_person, 10)
	for person: NpcRecord in _district.people:
		var card: DEF_NpcPerson = _district.definition.person_for(person.npc_id)
		assert_not_null(card)
		assert_true(NpcAuthoredPersonRules.matches(card, person))
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		assert_not_null(body)
		assert_eq(body.scene_file_path, card.npc_scene_path)
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 1), _root))


func test_world_seed_and_definition_order_do_not_change_authored_identity() -> void:
	var original: Variant = SaveDataCodec.encode(_district.people)
	var definition: DEF_District = _district.definition.duplicate() as DEF_District
	definition.authored_people = definition.authored_people.duplicate()
	definition.authored_people.reverse()
	definition.profiles = definition.profiles.duplicate()
	definition.profiles.reverse()
	definition.places = definition.places.duplicate()
	definition.places.reverse()
	var expected: Array[NpcRecord] = NpcPopulationRules.initial_records(
		_district.definition,
		1,
		42518,
		1,
	)
	for world_seed: int in [1, 99999]:
		var people: Array[NpcRecord] = NpcPopulationRules.initial_records(
			definition,
			42,
			world_seed,
			7,
		)
		assert_eq(SaveDataCodec.encode(people), SaveDataCodec.encode(expected))
		assert_eq(NpcPopulationRules.next_person_after(people, 1), 10)
		assert_eq(NpcPopulationRules.next_person_after(people, 42), 42)
	assert_eq(SaveDataCodec.encode(_district.people), original)


func test_authored_death_keeps_identity_and_address_without_selecting_a_successor() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var home_id: StringName = person.home_id
	(body.get_component(C_Health) as C_Health).current = 0.0
	body.add_component(C_Death.new())
	DistrictPopulationService.mark_dead(person, body, 1)
	DistrictPopulationService.replace_vacancies(_district, 3)
	assert_eq(_district.people.size(), 3)
	assert_eq(_district.next_person, 10)
	assert_eq(_district.replacement_morning, 0)
	assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
	assert_eq(person.home_id, home_id)
	assert_true(
		NpcAuthoredPersonRules.matches(_district.definition.person_for(person.npc_id), person)
	)


func test_disk_restore_keeps_retained_body_then_recreates_one_missing_body() -> void:
	var person: NpcRecord = _district.people[0]
	var npc_id: StringName = person.npc_id
	var card: DEF_NpcPerson = _district.definition.person_for(npc_id)
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = 41.0
	NpcDialogueMemoryService.set_tag(person, &"visited")
	NpcDialogueMemoryService.set_val(person, &"quest_stage", 2)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	var disk: Dictionary = AutosaveStore.read(SAVE_PATH)
	assert_true(WorldSnapshotService.restore(disk, _root))
	assert_same(NpcPopulationQueries.body_for(npc_id), body)
	_assert_restored_person(card)
	_world.remove_entity(body)
	await get_tree().process_frame
	assert_true(WorldSnapshotService.restore(disk, _root))
	_assert_restored_person(card)
	var restored_body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	assert_not_null(restored_body)
	assert_eq(restored_body.scene_file_path, card.npc_scene_path)
	assert_eq((restored_body.get_component(C_Health) as C_Health).current, 41.0)
	assert_eq(_district.people.size(), 3)


func _assert_restored_person(card: DEF_NpcPerson) -> void:
	var restored: NpcRecord = NpcPopulationQueries.person_for(card.key)
	assert_true(NpcAuthoredPersonRules.matches(card, restored))
	assert_true(restored.dialogue_tags[&"visited"])
	assert_eq(restored.dialogue_values[&"quest_stage"], 2)
#endregion


#region Preflight and old schema
func test_dynamic_body_scene_must_match_the_authored_card_before_prefab_construction() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	var card: DEF_NpcPerson = _district.definition.person_for(person.npc_id)
	# Даже совместимый alias той же сцены не заменяет её канонический авторский путь.
	var alias_path: String = card.npc_scene_path.replace("/entities/", "/entities/./")
	var alternative: PackedScene = load(alias_path)
	var candidate: Node = alternative.instantiate()
	assert_true(candidate is E_DistrictNpc)
	candidate.free()
	for replacement_path: String in [
		alias_path,
		"res://content/domains/npc/entities/npc_character.tscn",
	]:
		var malformed: Dictionary = snapshot.duplicate(true)
		for record: Dictionary in malformed.entities:
			if String(record.key) == String(person.npc_id):
				assert_eq(String(record.authored_id), "")
				record.scene = replacement_path
		assert_false(WorldSnapshotService.valid(malformed, _root), replacement_path)
		assert_false(WorldSnapshotService.restore(malformed, _root), replacement_path)
		assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
		assert_same(NpcPopulationQueries.body_for(person.npc_id), body)


func test_tampered_identity_or_missing_person_rejects_before_live_mutation() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for invalid: String in ["name", "seed", "home", "recipient", "missing", "replacement"]:
		var malformed: Dictionary = snapshot.duplicate(true)
		for record: Dictionary in malformed.entities:
			for data: Dictionary in record.components:
				if String(data.type) != C_District.resource_path:
					continue
				var people: Array = data.fields.people as Array
				var fields: Dictionary = people[0].fields as Dictionary
				match invalid:
					"name":
						fields.variation.fields.display_name = "Другая личность"
					"seed":
						fields.variation.fields.seed = 123
					"home":
						fields.home_id = &"home_8"
					"recipient":
						fields.recipient_key = &"another_recipient"
					"missing":
						people.pop_back()
					"replacement":
						data.fields.replacement_morning = 3
		assert_false(WorldSnapshotService.restore(malformed, _root), invalid)
		assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
		assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
	assert_true(
		NpcAuthoredPersonRules.matches(_district.definition.person_for(person.npc_id), person)
	)


func test_previous_schema_rejects_without_replacing_file_or_world() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	snapshot.version = AutosaveStore.SCHEMA_VERSION - 1
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	var person: NpcRecord = _district.people[0]
	var state: C_Autosave = C_Autosave.new()
	state.path = SAVE_PATH
	assert_false(NightSaveService.restore_startup(_root, state))
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), original)
	assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
#endregion
