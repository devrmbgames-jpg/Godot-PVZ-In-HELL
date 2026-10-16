extends GutTest
## Нативные авторские карточки R1: постоянство, атомарный отказ и отделение guest/variation.

const DEFINITION_ROOT: String = "res://content/domains/npc/definitions/"
const PILOT_KEYS: Array[String] = ["hag", "chain_devil", "shy"]

var _cards: Array[DEF_NpcPerson] = []
var _district: DEF_District


func before_all() -> void:
	_district = load(DEFINITION_ROOT + "def_district_default.tres")
	for pilot_key: String in PILOT_KEYS:
		var card: DEF_NpcPerson = load(
			DEFINITION_ROOT + "def_npc_person_%s_prototype.tres" % pilot_key,
		)
		_cards.append(card)


#region Authored identity
func test_native_pilot_has_explicit_distinct_identity_address_and_physical_scene() -> void:
	assert_true(NpcAuthoredPersonRules.valid_cards(_cards, _district))
	var expected_ids: Array[StringName] = [&"npc/6", &"npc/9", &"npc/3"]
	var expected_names: Array[String] = ["Морана", "Азгар", "Тихон"]
	var expected_homes: Array[StringName] = [&"home_6", &"home_2", &"home_3"]
	for index: int in _cards.size():
		var card: DEF_NpcPerson = _cards[index]
		assert_true(card.prototype, "Technical pilot does not claim final canon")
		assert_eq(card.key, expected_ids[index])
		assert_eq(card.variation.display_name, expected_names[index])
		assert_eq(card.home_id, expected_homes[index])
		var scene: PackedScene = load(card.npc_scene_path)
		var body: Node = scene.instantiate()
		assert_true(body is E_DistrictNpc)
		assert_true(body is CharacterBody3D)
		body.free()


func test_reorder_of_cards_profiles_and_places_keeps_complete_identity_and_order() -> void:
	var expected: Array[NpcRecord] = NpcAuthoredPersonRules.initial_records(_cards, _district)
	var reordered_cards: Array[DEF_NpcPerson] = _cards.duplicate()
	reordered_cards.reverse()
	var reordered_district: DEF_District = _district.duplicate() as DEF_District
	reordered_district.places = _district.places.duplicate()
	reordered_district.places.reverse()
	reordered_district.profiles = _district.profiles.duplicate()
	reordered_district.profiles.reverse()
	var actual: Array[NpcRecord] = NpcAuthoredPersonRules.initial_records(
		reordered_cards,
		reordered_district,
	)
	assert_eq(actual.size(), 3)
	assert_eq(SaveDataCodec.encode(actual), SaveDataCodec.encode(expected))
	assert_eq(actual[0].npc_id, &"npc/3")
	assert_eq(actual[1].npc_id, &"npc/6")
	assert_eq(actual[2].npc_id, &"npc/9")


func test_creation_is_detached_and_never_mutates_card_or_another_life_record() -> void:
	var first: Array[NpcRecord] = NpcAuthoredPersonRules.initial_records(_cards, _district)
	var second: Array[NpcRecord] = NpcAuthoredPersonRules.initial_records(_cards, _district)
	var card: DEF_NpcPerson = _cards[2]
	assert_ne(first[0], second[0])
	assert_ne(first[0].variation, card.variation)
	assert_ne(first[0].variation, second[0].variation)
	first[0].variation.display_name = "Изменённое имя"
	first[0].variation.optional_trait_keys.append(&"invalid_trait")
	first[0].dialogue_tags[&"visited"] = true
	assert_eq(card.variation.display_name, "Тихон")
	assert_true(card.variation.optional_trait_keys.is_empty())
	assert_eq(second[0].variation.display_name, "Тихон")
	assert_true(second[0].variation.optional_trait_keys.is_empty())
	assert_true(second[0].dialogue_tags.is_empty())


func test_matches_checks_all_fixed_fields_but_preserves_mutable_history() -> void:
	var card: DEF_NpcPerson = _cards[2]
	var person: NpcRecord = NpcAuthoredPersonRules.initial_records(_cards, _district)[0]
	person.dialogue_tags[&"visited"] = true
	person.dialogue_values[&"debt"] = -10
	person.death_day = 7
	person.placement = NpcRecord.Placement.DEAD
	assert_true(NpcAuthoredPersonRules.matches(card, person))
	var changes: Dictionary[String, Variant] = {
		"npc_id": &"npc/99",
		"profile": _cards[0].profile,
		"recipient_key": &"other",
		"home_id": &"home_8",
		"portal_id": &"portal_south",
		"exit_id": &"portal_south",
	}
	for field: String in changes:
		var original: Variant = person.get(field)
		person.set(field, changes[field])
		assert_false(NpcAuthoredPersonRules.matches(card, person), field)
		person.set(field, original)
	var variation_changes: Dictionary[String, Variant] = {
		"archetype_key": &"other",
		"seed": 1,
		"creation_day": 2,
		"display_name": "Другой",
		"dialogue_path": card.profile.dialogue_variants[1],
		"optional_trait_keys": [&"other"],
		"move_speed_multiplier": 1.01,
		"aggression_multiplier": 1.01,
	}
	for field: String in variation_changes:
		var original: Variant = person.variation.get(field)
		if field == "optional_trait_keys":
			person.variation.optional_trait_keys = [&"other"]
		else:
			person.variation.set(field, variation_changes[field])
		assert_false(NpcAuthoredPersonRules.matches(card, person), field)
		person.variation.set(field, original)
	assert_true(NpcAuthoredPersonRules.matches(card, person))
#endregion


#region Rejection and guest compatibility
func test_invalid_card_or_duplicate_rejects_the_entire_roster_without_partial_publication() -> void:
	var changes: Dictionary[String, Variant] = {
		"key": &"npc/3",
		"recipient_key": _cards[2].recipient_key,
		"home_id": &"home_3",
		"portal_id": &"missing",
		"exit_id": &"home_1",
		"profile": null,
		"variation": null,
		"npc_scene_path": DEFINITION_ROOT + "missing.tscn",
	}
	for field: String in changes:
		var invalid: DEF_NpcPerson = _cards[0].duplicate() as DEF_NpcPerson
		invalid.set(field, changes[field])
		var cards: Array[DEF_NpcPerson] = [invalid, _cards[1], _cards[2]]
		assert_false(NpcAuthoredPersonRules.valid_cards(cards, _district), field)
		assert_true(NpcAuthoredPersonRules.initial_records(cards, _district).is_empty(), field)
	var null_cards: Array[DEF_NpcPerson] = [_cards[0], null]
	assert_true(NpcAuthoredPersonRules.initial_records(null_cards, _district).is_empty())
	assert_false(NpcAuthoredPersonRules.valid_cards(_cards, null))


func test_identity_is_a_canonical_positive_npc_number_without_aliases() -> void:
	var card: DEF_NpcPerson = _cards[0].duplicate() as DEF_NpcPerson
	for invalid: StringName in [
		&"",
		&"npc/0",
		&"npc/-1",
		&"npc/+1",
		&"npc/01",
		&"npc/1/extra",
		&"other/1",
	]:
		card.key = invalid
		assert_false(NpcAuthoredPersonRules.valid_card(card), String(invalid))
	card.key = &"npc/42"
	assert_true(NpcAuthoredPersonRules.valid_card(card))


func test_fixed_selection_allows_authored_name_but_rejects_random_or_incompatible_choices() -> void:
	var card: DEF_NpcPerson = _cards[0].duplicate() as DEF_NpcPerson
	card.variation = card.variation.duplicate(true) as NpcVariation
	card.variation.display_name = "Авторское имя вне пула"
	assert_true(NpcAuthoredPersonRules.valid_card(card))
	assert_false(NpcVariationRules.valid_variation(card.profile, card.variation, 42518, card.key))
	card.variation.optional_trait_keys = [&"missing"]
	assert_false(NpcAuthoredPersonRules.valid_card(card))
	card.variation.optional_trait_keys.clear()
	card.variation.move_speed_multiplier = NAN
	assert_false(NpcAuthoredPersonRules.valid_card(card))
	card.variation.move_speed_multiplier = 1.0
	card.variation.seed = 1
	assert_false(NpcAuthoredPersonRules.valid_card(card))
	card.variation.seed = 0
	card.variation.creation_day = 2
	assert_false(NpcAuthoredPersonRules.valid_card(card))


func test_returning_guest_has_no_home_and_keeps_existing_random_guest_api() -> void:
	var guest: DEF_NpcPerson = DEF_NpcPerson.new()
	guest.key = &"npc/20"
	guest.profile = load(DEFINITION_ROOT + "def_npc_archetype_lost_visitor.tres")
	guest.npc_scene_path = guest.profile.npc_scene_path
	guest.variation = NpcVariation.new()
	guest.variation.archetype_key = guest.profile.key
	guest.variation.display_name = "Лука"
	guest.variation.dialogue_path = guest.profile.dialogue_variants[0]
	guest.recipient_key = &"guest_lost"
	guest.portal_id = &"portal_east"
	guest.exit_id = &"portal_north"
	var cards: Array[DEF_NpcPerson] = [guest]
	assert_true(NpcAuthoredPersonRules.valid_cards(cards, _district))
	var people: Array[NpcRecord] = NpcAuthoredPersonRules.initial_records(cards, _district)
	assert_eq(people.size(), 1)
	if people.is_empty():
		return
	var person: NpcRecord = people[0]
	assert_true(person.home_id.is_empty())
	assert_false(person.profile.resident)
	guest.home_id = &"home_1"
	assert_false(NpcAuthoredPersonRules.valid_cards(cards, _district))
	for world_seed: int in [1, 999]:
		var generated: NpcVariation = NpcVariationRules.create(
			guest.profile,
			world_seed,
			&"npc/21",
			3,
		)
		assert_not_null(generated)
		assert_true(
			NpcVariationRules.valid_variation(guest.profile, generated, world_seed, &"npc/21")
		)
#endregion
