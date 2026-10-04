extends GutTest

const SAVE_PATH: String = "user://gut_r21_world_snapshot.pvzh"
var _root: Node = null
var _world: World = null
var _session: Entity = null
var _actor: Entity = null
var _item: Entity = null

class LifecycleEntity extends Entity:
	var _enable_calls: int = 0
	var _disable_calls: int = 0

	func on_enable() -> void:
		_enable_calls += 1

	func on_disable() -> void:
		_disable_calls += 1

	func enable_calls() -> int:
		return _enable_calls

	func disable_calls() -> int:
		return _disable_calls


func before_each() -> void:
	_root = Node.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_world.add_observer(O_InventoryLifecycle.new())
	_session = _authored("Session", [C_DayCycle.new(), C_Wallet.new(), C_PackageLedger.new(), C_CustomerFlow.new(), C_Commerce.new(), C_QuestSession.new(), C_Autosave.new()])
	(_session.get_component(C_Autosave) as C_Autosave).path = SAVE_PATH
	_actor = _authored("Actor", [C_Inventory.new(), C_Hunger.new(), C_Health.new()])

	var stack: C_InventoryItem = C_InventoryItem.new()
	stack.definition = (load("res://content/definitions/gameplay/inventory/def_item_food.tres") as DEF_InventoryItem)
	stack.quantity = 4
	_item = Entity.new()
	_item.component_resources = [stack]
	_world.add_entity(_item)
	_item.add_relationship(Relationship.new(R_OwnedBy.new(), _actor))


func _authored(label: String, components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.name = label
	entity.component_resources = components
	_root.add_child(entity)
	entity.owner = _root
	_world.add_entity(entity, null, false)
	return entity


func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_negative_wallet_and_owned_inventory_survive_snapshot_and_repeated_restore() -> void:
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	wallet.balance = -123
	var id: String = _item.id
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	_world.remove_entity(_item)
	wallet.balance = 0
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(wallet.balance, -123)
	assert_eq(DayPhaseService.current().day_index, 2)
	assert_eq(InventoryService.items(_actor).size(), 1)

	var restored: Entity = InventoryService.items(_actor)[0]
	assert_eq(restored.id, id)
	assert_eq((restored.get_component(C_InventoryItem) as C_InventoryItem).quantity, 4)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(InventoryService.items(_actor).size(), 1)
	assert_eq(InventoryService.items(_actor)[0].id, id)
	assert_eq(restored.relationships.size(), 1)


func test_failed_write_holds_night_and_retry_commits_the_same_morning_in_debt() -> void:
	var cycle: C_DayCycle = _session.get_component(C_DayCycle) as C_DayCycle
	var state: C_Autosave = _session.get_component(C_Autosave) as C_Autosave
	(_session.get_component(C_Wallet) as C_Wallet).balance = -300
	cycle.phase = C_DayCycle.Phase.NIGHT
	cycle.night_ready = false
	state.path = "user://r21_missing_directory/slot.pvzh"
	NightSaveService.process(_session, cycle, state, 0.1)
	assert_ne(state.last_error, OK)
	assert_false(cycle.night_ready)
	assert_eq(cycle.day_index, 1)
	assert_eq(state.started_night, 1)
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	NightSaveService.process(_session, cycle, state, 0.1)
	assert_eq(state.last_error, OK)
	assert_true(cycle.night_ready)
	assert_eq(state.last_saved_morning, 2)
	assert_eq(AutosaveStore.read(SAVE_PATH).morning_day, 2)
	NightSaveService.process(_session, cycle, state, 0.1)
	assert_eq(state.last_saved_morning, 2)
	assert_eq(cycle.day_index, 1)
	_world.add_system(S_DayPhase.new())
	_world.process(0.1)
	assert_eq(cycle.day_index, 2)
	assert_eq(cycle.phase, C_DayCycle.Phase.MORNING)
	_world.process(0.1)
	assert_eq(cycle.day_index, 2)


func test_invalid_snapshot_is_rejected_before_mutating_wallet_or_ownership() -> void:
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	wallet.balance = 70
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var records: Array = snapshot.entities as Array
	var duplicate: Dictionary = (records[0] as Dictionary).duplicate(true)
	records.append(duplicate)
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(wallet.balance, 70)
	assert_eq(DayPhaseService.current().day_index, 1)
	assert_eq(InventoryService.owner_for(_item), _actor)
	assert_eq(InventoryService.items(_actor).size(), 1)


func test_inventory_with_unknown_relationship_target_is_rejected_before_mutation() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	for record: Dictionary in snapshot.entities:
		if not (record.links as Array).is_empty():
			(record.links as Array)[0].target = "missing/owner"
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(InventoryService.owner_for(_item), _actor)
	assert_eq(DayPhaseService.current().day_index, 1)


func test_missing_scene_or_authored_path_is_rejected_before_mutation() -> void:
	for field: String in ["scene", "authored_path"]:
		var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
		var records: Array = snapshot.entities as Array
		(records[0] as Dictionary).erase(field)
		assert_false(WorldSnapshotService.restore(snapshot, _root))
		assert_eq(InventoryService.owner_for(_item), _actor)
		assert_eq(DayPhaseService.current().day_index, 1)


func test_restore_replaces_previous_inventory_owner_without_retiring_item() -> void:
	var other: Entity = _authored("Other", [C_Inventory.new()])
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(InventoryService.transfer(_item, other, _actor))
	assert_eq(InventoryService.owner_for(_item), other)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(InventoryService.owner_for(_item), _actor)
	assert_eq(InventoryService.items(_actor).size(), 1)
	assert_true(InventoryService.items(other).is_empty())
	assert_eq(_item.relationships.size(), 1)
	assert_false((_item.get_component(C_InventoryItem) as C_InventoryItem).transfer_in_progress)


func test_null_package_definition_is_rejected_before_mutation() -> void:
	var identity: C_Package = C_Package.new()
	identity.package_id = "late:equipment"
	identity.definition = (load("res://content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres") as DEF_Delivery).packages[0]
	_authored("Package", [identity, C_PackageState.new()])
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	for record: Dictionary in snapshot.entities:
		for component: Dictionary in record.components:
			if SaveDataCodec.component_script(String(component.type)) == C_Package:
				(component.fields as Dictionary).definition = null
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(DayPhaseService.current().day_index, 1)
	assert_eq(InventoryService.owner_for(_item), _actor)


func test_restore_disabled_entity_uses_world_lifecycle_and_reenables_existing_entity() -> void:
	var entity: LifecycleEntity = LifecycleEntity.new()
	entity.name = "Lifecycle"
	entity.component_resources = [C_Health.new()]
	_root.add_child(entity)
	entity.owner = _root
	_world.add_entity(entity, null, false)
	var enabled_snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.disable_entity(entity)

	var disabled_snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.enable_entity(entity)
	var disable_calls: int = entity.disable_calls()
	assert_true(WorldSnapshotService.restore(disabled_snapshot, _root))
	assert_false(entity.enabled)
	assert_false(entity.is_processing())
	assert_false(entity.is_physics_processing())
	assert_eq(entity.disable_calls(), disable_calls + 1)

	var enable_calls: int = entity.enable_calls()
	assert_true(WorldSnapshotService.restore(enabled_snapshot, _root))
	assert_true(entity.enabled)
	assert_true(entity.is_processing())
	assert_true(entity.is_physics_processing())
	assert_eq(entity.enable_calls(), enable_calls + 1)


func test_restore_swapped_slots_clears_all_old_occupancy_before_attaching() -> void:
	var slots: Array[E_PhysicalSlot] = []
	var boxes: Array[Entity] = []
	for index: int in 2:
		var slot: E_PhysicalSlot = (load("res://content/entities/props/physical_slot.tscn") as PackedScene).instantiate() as E_PhysicalSlot
		slot.name = "Slot%d" % index
		_root.add_child(slot)
		slot.owner = _root
		_world.add_entity(slot, null, false)
		slots.append(slot)
		var box: Entity = (load("res://content/entities/props/anchorable_test_box.tscn") as PackedScene).instantiate() as Entity
		box.name = "Box%d" % index
		_root.add_child(box)
		box.owner = _root
		_world.add_entity(box, null, false)
		boxes.append(box)
		var binding: Relationship = Relationship.new(R_StoredIn.new(), slot)
		box.add_relationship(binding)
		assert_true(PhysicalSlotService.attach(box, binding))

	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	for box: Entity in boxes:
		PhysicalSlotService.release(box)
	for index: int in 2:
		var binding: Relationship = Relationship.new(R_StoredIn.new(), slots[1 - index])
		boxes[index].add_relationship(binding)
		assert_true(PhysicalSlotService.attach(boxes[index], binding))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	for index: int in 2:
		assert_eq(PhysicalSlotService.occupant(slots[index]), boxes[index])
		var binding: Relationship = PhysicalSlotService.relationship(boxes[index])
		assert_true((binding.relation as R_StoredIn).applied)
		assert_false((boxes[index] as Node as RigidBody3D).is_physics_processing())
		assert_eq(slots[index].driver.get_node(slots[index].driver.remote_path), boxes[index])


func test_duplicate_owners_wrong_role_or_capacity_fail_before_any_mutation() -> void:
	for invalid: String in ["owners", "role", "capacity", "ids", "paths"]:
		var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
		var records: Array = snapshot.entities as Array
		for record: Dictionary in records:
			if String(record.key) == WorldSnapshotService.key_for(_item, _root):
				if invalid == "owners":
					(record.links as Array).append((record.links[0] as Dictionary).duplicate())
				elif invalid == "role":
					(record.links as Array)[0].target = WorldSnapshotService.key_for(_session, _root)
			if invalid == "capacity" and String(record.key) == WorldSnapshotService.key_for(_actor, _root):
				for component: Dictionary in record.components:
					if SaveDataCodec.component_script(String(component.type)) == C_Inventory:
						(component.fields as Dictionary).maximum_stacks = 0
		if invalid == "ids":
			(records[1] as Dictionary).entity_id = (records[0] as Dictionary).entity_id
		if invalid == "paths":
			(records[1] as Dictionary).authored_path = (records[0] as Dictionary).authored_path
		assert_false(WorldSnapshotService.restore(snapshot, _root), invalid)
		assert_eq(DayPhaseService.current().day_index, 1)
		assert_eq(InventoryService.owner_for(_item), _actor)


func test_authored_ids_restore_as_a_group_and_reindex_world_lookup() -> void:
	var session_id: String = _session.id
	var actor_id: String = _actor.id
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.entity_id_registry.erase(session_id)
	_world.entity_id_registry.erase(actor_id)
	_session.id = actor_id
	_actor.id = session_id
	_world.entity_id_registry[_actor.id] = _actor
	_world.entity_id_registry[_session.id] = _session
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_session.id, session_id)
	assert_eq(_actor.id, actor_id)
	assert_eq(_world.get_entity_by_id(session_id), _session)
	assert_eq(_world.get_entity_by_id(actor_id), _actor)


func test_duplicate_slot_occupants_or_wrong_slot_entity_fail_before_mutation() -> void:
	var slot: E_PhysicalSlot = (load("res://content/entities/props/physical_slot.tscn") as PackedScene).instantiate() as E_PhysicalSlot
	slot.name = "ValidationSlot"
	_root.add_child(slot)
	slot.owner = _root
	_world.add_entity(slot, null, false)
	for index: int in 2:
		var box: Entity = (load("res://content/entities/props/anchorable_test_box.tscn") as PackedScene).instantiate() as Entity
		box.name = "ValidationBox%d" % index
		_root.add_child(box)
		box.owner = _root
		_world.add_entity(box, null, false)
		box.add_relationship(Relationship.new(R_StoredIn.new(), slot))

	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(DayPhaseService.current().day_index, 1)
	# Keep one occupant but target an Entity that is not a physical slot.
	var first: bool = true
	for record: Dictionary in snapshot.entities:
		if not (record.links as Array).is_empty() and String(record.links[0].kind) == WorldSnapshotService.STORED:
			if first:
				(record.links as Array)[0].target = WorldSnapshotService.key_for(_actor, _root)
				first = false
			else:
				(record.links as Array).clear()
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(DayPhaseService.current().day_index, 1)


func test_authored_path_alias_or_outside_root_is_rejected_before_registry_changes() -> void:
	var id: String = _actor.id
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var records: Array = snapshot.entities as Array
	for record: Dictionary in records:
		if String(record.key) == WorldSnapshotService.key_for(_actor, _root):
			var alias: Dictionary = record.duplicate(true)
			alias.key = "scene/AliasActor"
			alias.entity_id = "alias_actor"
			alias.authored_path = "./Actor"
			records.append(alias)
			break

	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_world.get_entity_by_id(id), _actor)
	assert_null(_world.get_entity_by_id("alias_actor"))
	assert_eq(DayPhaseService.current().day_index, 1)
	var outside: Entity = Entity.new()
	outside.name = "Outside"
	add_child(outside)
	snapshot = WorldSnapshotService.capture(_root, 2)
	for record: Dictionary in snapshot.entities:
		if String(record.key) == WorldSnapshotService.key_for(_actor, _root):
			record.authored_path = "../Outside"
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(InventoryService.owner_for(_item), _actor)
	outside.free()


func test_omitted_package_identity_is_rejected_before_instantiation_commit() -> void:
	var package: E_Package = (load("res://content/entities/packages/package.tscn") as PackedScene).instantiate() as E_Package
	package.package_id = "test/required_identity"
	package.package_definition = (load("res://content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres") as DEF_Delivery).packages[0]
	_world.add_entity(package)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.remove_entity(package)
	for record: Dictionary in snapshot.entities:
		if String(record.key) == "package/test/required_identity":
			var components: Array = record.components as Array
			for index: int in range(components.size() - 1, -1, -1):
				if SaveDataCodec.component_script(String(components[index].type)) == C_Package:
					components.remove_at(index)

	var count: int = _world.entities.size()
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_world.entities.size(), count)
	assert_eq(DayPhaseService.current().day_index, 1)
	assert_eq(InventoryService.owner_for(_item), _actor)


func test_pre_stamina_snapshot_clears_existing_sprint_session() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var stamina: C_Stamina = C_Stamina.new()
	stamina.current = 45.0
	stamina.initialized = true
	stamina.toggled = true
	stamina.running = true
	stamina.exhausted = true
	stamina.recovery_remaining = 2.0
	_actor.add_component(stamina)

	var motion: C_Motion = C_Motion.new()
	motion.sprint_multiplier = 1.5
	_actor.add_component(motion)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_false(stamina.toggled)
	assert_false(stamina.running)
	assert_false(stamina.exhausted)
	assert_eq(stamina.recovery_remaining, 0.0)
	assert_eq(motion.sprint_multiplier, 1.0)
