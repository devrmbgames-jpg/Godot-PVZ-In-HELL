extends RefCounted
## Captures detached roster/Profile construction inputs without consulting or mutating ECS.world.
class_name NpcConstructionService

#region Explicit instance inputs
## Adds the existing roster identity and Profile to a fresh compiler context, without live writes.
static func configure_context(context: EntitySpawnContext, person: NpcRecord,
		district_definition: DEF_District) -> void:
	context.definitions[&"npc_profile"] = person.profile
	context.definitions[&"district_definition"] = district_definition
	context.initial_fields[C_NpcIdentity as Script] = {&"npc_id": person.npc_id}
	context.initial_fields[C_PersistentIdentity as Script] = {&"key": String(person.npc_id)}


## Supplies the stable authored home key before the common address compiler runs.
static func configure_address(context: EntitySpawnContext, place: DEF_DistrictPlace) -> void:
	context.initial_fields[C_NpcAddress as Script] = {&"address_id": place.key}


## Rebuilds the address label from immutable authored data before native publication.
static func present_address(actor: Entity, place: DEF_DistrictPlace) -> void:
	(actor.get_node("Address") as Label3D).text = place.display_name


## Prepares the authored district and its placed merchant from fresh or validated saved authority.
## Returned issues abort the whole placed set before native registration and roster mutation.
static func configure_placed(contexts: Array[EntitySpawnContext],
		saved_district: C_District = null,
		saved_identities: Dictionary[String, StringName] = {}) -> PackedStringArray:
	var district_context: EntitySpawnContext = null
	var district_recipe: C_District = null
	for context: EntitySpawnContext in contexts:
		for recipe: Component in context.actor.component_resources:
			if recipe is C_District:
				if district_context != null:
					return PackedStringArray(["Placed construction requires a single district owner"])
				district_context = context
				district_recipe = recipe as C_District
	if district_recipe == null:
		return PackedStringArray()

	# These records are transient inputs. The common compiler isolates the committed aggregate.
	var people: Array[NpcRecord] = saved_district.people if saved_district != null \
		else NpcPopulationRules.initial_records(district_recipe.definition,
			district_recipe.next_person)
	var next_person: int = saved_district.next_person if saved_district != null \
		else district_recipe.next_person + people.size()
	district_context.initial_fields[C_District as Script] = {
		&"people": people, &"next_person": next_person,
	}
	for context: EntitySpawnContext in contexts:
		if not context.actor is E_DistrictNpc:
			continue
		var authored: C_AuthoredIdentity = PlacedIdentityRules.component_for(context.actor)
		var saved_id: StringName = saved_identities.get(authored.actor_key(), &"") \
			if authored != null else &""
		var matched: NpcRecord = null
		for person: NpcRecord in people:
			if (not saved_id.is_empty() and person.npc_id == saved_id) \
					or (saved_id.is_empty() and person.profile.merchant):
				matched = person
				break
		if matched == null:
			return PackedStringArray(["Placed NPC has no matching district roster identity"])
		var definition: DEF_District = saved_district.definition if saved_district != null \
			else district_recipe.definition
		configure_context(context, matched, definition)
	return PackedStringArray()
#endregion
