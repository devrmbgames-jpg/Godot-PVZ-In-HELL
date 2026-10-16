extends "res://tests/smoke/npc_life_cycle_smoke.gd"
## Buffered death-drop, настоящий диск и новый процесс; возврат не создаёт стеки повторно.

const BELONGINGS_SAVE_PATH: String = "user://npc_return_belongings_smoke.pvzh"
const MED_PATH: String = "res://content/domains/inventory/definitions/def_item_med.tres"


#region Buffered inventory and isolated slot
func _save_path() -> String:
	return BELONGINGS_SAVE_PATH


func _completion_prefix() -> String:
	return "NPC belongings smoke"


func _create_world(world_seed: int) -> void:
	super._create_world(world_seed)
	var inventory: O_InventoryLifecycle = O_InventoryLifecycle.new()
	inventory.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(inventory)


func _drops() -> Array[Entity]:
	var found: Array[Entity] = []
	for item: Entity in _world.query.with_all([C_InventoryItem]).execute():
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		if (
			state.definition.resource_path == MED_PATH and state.quantity == 2
			and InventoryService.owner_for(item) == null
		):
			found.append(item)
	return found


func _kill(person: NpcRecord) -> void:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var first_death: bool = person.deaths.is_empty()
	if first_death:
		_check(
			DistrictPopulationService.set_placement(
				person,
				body,
				NpcRecord.Placement.STREET,
				&"smoke_carried_item",
				false,
				NpcPopulationQueries.position_for(person.home_id, true)
				+ Vector3(0.0, 0.0, STREET_DEATH_DISTANCE),
			),
			"activate inventory owner",
		)
		_check(
			InventoryService.grant(body, load(MED_PATH) as DEF_InventoryItem, 2),
			"grant real carried stack",
		)
	super._kill(person)
	_world.flush_command_buffers()
	var dropped: Array[Entity] = _drops()
	_check(dropped.size() == 1, "one carried physical stack after buffered death")
	if dropped.size() != 1:
		return
	if first_death:
		NpcDialogueMemoryService.set_val(person, &"belongings_pickup_id", dropped[0].id)
	else:
		_check(
			dropped[0].id == person.dialogue_values.get(&"belongings_pickup_id"),
			"same physical item ID after cold restore and second death",
		)


func _restore() -> void:
	super._restore()
	var person: NpcRecord = NpcPopulationQueries.person_for(_person_id())
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var owned: Array[Entity] = _world.query.with_all([C_InventoryItem]).with_relationship([
		Relationship.new(R_OwnedBy.new(), body),
	]).execute()
	_check(owned.is_empty(), "returned body did not recreate carried items")
	_check(_drops().size() == 1, "physical quantity survived the complete two-life scenario")
#endregion
