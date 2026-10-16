extends RefCounted
## Чистая проверка и detached-сборка авторских личностей; C_District.people остаётся владельцем.
class_name NpcAuthoredPersonRules


#region Authored contract
## Проверяет карточку без создания тела, случайного выбора или изменения общих Resources.
static func valid_card(card: DEF_NpcPerson) -> bool:
	if (
		card == null or not _valid_identity(card.key) or card.profile == null
		or card.recipient_key.is_empty() or card.npc_scene_path.is_empty()
		or not card.npc_scene_path.begins_with("res://")
		or not card.npc_scene_path.ends_with(".tscn")
		or not ResourceLoader.exists(card.npc_scene_path, "PackedScene")
		or card.profile.resident == card.home_id.is_empty()
		or not NpcVariationRules.valid_selection(card.profile, card.variation)
	):
		return false
	# У авторской личности нет решения RNG и календаря рождения нового преемника.
	return card.variation.seed == 0 and card.variation.creation_day == 1


## Проверяет весь набор атомарно, включая уникальные личности/адреса и существующие проходы.
static func valid_cards(cards: Array[DEF_NpcPerson], district: DEF_District) -> bool:
	if district == null:
		return false
	var identities: Dictionary[StringName, bool] = { }
	var recipients: Dictionary[StringName, bool] = { }
	var homes: Dictionary[StringName, bool] = { }
	for card: DEF_NpcPerson in cards:
		if (
			not valid_card(card) or identities.has(card.key) or recipients.has(card.recipient_key)
			or not _place_is(district, card.portal_id, DEF_DistrictPlace.Kind.PORTAL)
			or not _place_is(district, card.exit_id, DEF_DistrictPlace.Kind.PORTAL)
		):
			return false
		if not card.home_id.is_empty():
			if (
				homes.has(card.home_id)
				or not _place_is(district, card.home_id, DEF_DistrictPlace.Kind.HOME)
			):
				return false
			homes[card.home_id] = true
		identities[card.key] = true
		recipients[card.recipient_key] = true
	return true


static func _valid_identity(identity: StringName) -> bool:
	var text: String = String(identity)
	if not text.begins_with("npc/"):
		return false
	var number_text: String = text.trim_prefix("npc/")
	return (
		number_text.is_valid_int() and number_text.to_int() > 0
		and str(number_text.to_int()) == number_text
	)


static func _place_is(
	district: DEF_District,
	place_id: StringName,
	kind: DEF_DistrictPlace.Kind,
) -> bool:
	var place: DEF_DistrictPlace = district.place_for(place_id)
	return place != null and place.kind == kind
#endregion


#region Detached records
## Возвращает весь проверенный состав или пустой массив; порядок карточек не задаёт личность.
static func initial_records(
	cards: Array[DEF_NpcPerson],
	district: DEF_District,
) -> Array[NpcRecord]:
	var people: Array[NpcRecord] = []
	if not valid_cards(cards, district):
		return people
	var ordered: Array[DEF_NpcPerson] = cards.duplicate()
	ordered.sort_custom(
		func(first: DEF_NpcPerson, second: DEF_NpcPerson) -> bool:
			return String(first.key).trim_prefix("npc/").to_int() < (
				String(second.key).trim_prefix("npc/").to_int()
			),
	)
	for card: DEF_NpcPerson in ordered:
		var person: NpcRecord = NpcRecord.new()
		person.npc_id = card.key
		person.profile = card.profile
		person.variation = card.variation.duplicate(true) as NpcVariation
		person.recipient_key = card.recipient_key
		person.home_id = card.home_id
		person.portal_id = card.portal_id
		person.exit_id = card.exit_id
		people.append(person)
	return people


## Проверяет неизменную часть записи; память, размещение и история принадлежат runtime.
static func matches(card: DEF_NpcPerson, person: NpcRecord) -> bool:
	if (
		not valid_card(card) or person == null or person.npc_id != card.key
		or person.profile != card.profile or person.recipient_key != card.recipient_key
		or person.home_id != card.home_id or person.portal_id != card.portal_id
		or person.exit_id != card.exit_id or person.variation == null
	):
		return false
	for field: String in NpcVariation.SAVE_FIELDS:
		if person.variation.get(field) != card.variation.get(field):
			return false
	return true
#endregion
