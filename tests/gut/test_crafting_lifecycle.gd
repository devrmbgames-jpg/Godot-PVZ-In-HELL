extends "res://tests/gut/test_buyback_lifecycle.gd"
## Реальные материалы/контейнер/кошелёк и native scheduled выдача с кампанийной историей.

const WORKSHOP: PackedScene = preload(
	"res://content/domains/commerce/entities/crafting_shy_container.tscn"
)
const RAW_CHAIN: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_raw_chain_prototype.tres"
)
const BLOOD_FLASK: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_blood_flask.tres"
)
var _workshop: E_CraftingContainer
var _craft_state: C_Crafting


#region Native fixture
func before_each() -> void:
	await super.before_each()
	_world.add_observer(O_Crafting.new())
	var owner: S_Crafting = S_Crafting.new()
	owner.group = "TestCrafting"
	_world.add_system(owner)
	_workshop = WORKSHOP.instantiate() as E_CraftingContainer
	(_workshop as Node as Node3D).position = Vector3(36, 0, 0)
	EntityCompositionFixture.register(_world, _workshop)
	_craft_state = _workshop.get_component(C_Crafting) as C_Crafting
	_world.flush_command_buffers()
	await get_tree().physics_frame


func _material(
	definition: DEF_InventoryItem = BONES,
	offset: Vector3 = Vector3.ZERO,
	quantity: int = 1,
) -> Entity:
	var item: Entity = (load(definition.world_pickup_scene) as PackedScene).instantiate() as Entity
	EntityCompositionFixture.register(_world, item)
	(item.get_component(C_InventoryItem) as C_InventoryItem).quantity = quantity
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(36, 1.2, 0) + offset
	return item


func _batch() -> CraftingBatch:
	var batches: Array[CraftingBatch] = CommerceService.current().crafting_batches
	return batches[-1] if not batches.is_empty() else null


func _tick_crafting() -> void:
	_world.process(2.0, "TestCrafting")
	_world.flush_command_buffers()
	for frame: int in 2:
		await get_tree().physics_frame


func _accept() -> CraftingQuote:
	await _physics_settled()
	var offer: CraftingQuote = CraftingService.quote(_seller, _workshop)
	assert_true(offer.reason.is_empty(), offer.reason)
	assert_eq(CraftingService.confirm(_seller, offer), CraftingService.Status.COMMITTED)
	_world.flush_command_buffers()
	return offer


func _take_outputs(batch: CraftingBatch) -> void:
	for output: CraftingOutput in batch.outputs:
		var item: Entity = _world.entity_id_registry.get(output.entity_id) as Entity
		if item != null:
			(item as Node as Node3D).global_position.x = 45
	await _tick_crafting()
#endregion


#region Полный набор, подарок и календарная выдача
func test_success_consumes_all_including_gifts_without_spending_first_failure() -> void:
	var bones: Entity = _material(BONES, Vector3(-0.7, 0, 0), 2)
	var gift: Entity = _material(BUYBACK_ITEM, Vector3(0.7, 0, 0))
	await _physics_settled()
	assert_eq(_money.balance, 0)
	assert_true(CommerceService.current().crafting_batches.is_empty())
	var offer: CraftingQuote = await _accept()
	var batch: CraftingBatch = _batch()
	assert_eq(batch.recipes.size(), 2)
	assert_eq(batch.gifts.size(), 1)
	assert_eq(batch.gifts[0].definition, BUYBACK_ITEM)
	assert_false(batch.first_failure)
	assert_false(CraftingQueries.grace_used(_craft_state.profile))
	assert_false(_world.entity_to_archetype.has(bones))
	assert_false(_world.entity_to_archetype.has(gift))
	assert_eq(_money.balance, 0)
	assert_true(_money.operations.is_empty())
	assert_eq(CraftingService.confirm(_seller, offer), CraftingService.Status.DUPLICATE)
	await _tick_crafting()
	assert_false(batch.outputs[0].emitted, "Same-day processing cannot issue the promise")
	_morning(2)
	await _tick_crafting()
	for output: CraftingOutput in batch.outputs:
		assert_true(output.emitted)
		var item: Entity = _world.entity_id_registry.get(output.entity_id) as Entity
		assert_not_null(item)
		assert_true(_workshop.contains(item))
	assert_false(batch.completed)
	assert_false(CraftingService.quote(_seller, _workshop).reason.is_empty())
	await _take_outputs(batch)
	assert_true(batch.completed)
	assert_true(CraftingQueries.available_reason(_workshop, _seller).is_empty())
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 2), _root))


func test_first_failed_batch_teaches_once_then_later_failure_creates_native_trash() -> void:
	var empty: CraftingQuote = CraftingService.quote(_seller, _workshop)
	assert_false(empty.reason.is_empty())
	assert_eq(CraftingService.confirm(_seller, empty), CraftingService.Status.UNAVAILABLE)
	assert_false(CraftingQueries.grace_used(_craft_state.profile))
	_material(BUYBACK_ITEM)
	await _accept()
	var first: CraftingBatch = _batch()
	assert_true(first.first_failure)
	assert_true(first.outputs.is_empty())
	assert_true(CraftingQueries.grace_used(_craft_state.profile))
	assert_true((_workshop.get_node("HintWall/Text") as Label3D).text.is_empty())
	_morning(2)
	await _tick_crafting()
	assert_true(first.completed)
	var hint: String = (_workshop.get_node("HintWall/Text") as Label3D).text
	assert_true(hint.contains("Спасибо за подарок"))
	assert_true(hint.contains("Кости ×1"))
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_true(CraftingQueries.grace_used(_craft_state.profile))
	_kill(NpcPopulationQueries.person_for(&"npc/3"))
	_material(BUYBACK_ITEM)
	await _accept()
	var second: CraftingBatch = _batch()
	assert_false(second.first_failure)
	assert_eq(second.outputs.size(), 1)
	assert_eq(second.outputs[0].definition, _craft_state.profile.trash)
	_morning(3)
	await _tick_crafting()
	assert_true(second.outputs[0].emitted)
	assert_not_null(_world.entity_id_registry.get(second.outputs[0].entity_id))
	assert_eq((_workshop.get_node("HintWall/Text") as Label3D).text, hint)
	_morning(4)
	assert_eq(NpcPopulationQueries.person_for(&"npc/3").death_day, 0)
	assert_true(CraftingQueries.grace_used(_craft_state.profile))
	assert_eq((_workshop.get_node("HintWall/Text") as Label3D).text, hint)
	assert_true(_money.operations.is_empty())


func test_actual_full_blood_and_raw_chain_produce_chain_clothes_before_simple_recipe() -> void:
	_material(BONES, Vector3(-0.7, 0, 0), 2)
	_material(RAW_CHAIN)
	var blood: Entity = _material(BLOOD_FLASK, Vector3(0.7, 0, 0))
	assert_true(CraftingQueries.input_for(blood).full_blood)
	await _accept()
	var batch: CraftingBatch = _batch()
	assert_eq(batch.recipes.size(), 2)
	assert_eq(batch.recipes[0], _craft_state.profile.recipes[0])
	assert_eq(batch.recipes[1], _craft_state.profile.recipes[1])
	assert_true(batch.gifts.is_empty())
	assert_eq(batch.outputs[0].definition.key, &"chain_clothes")
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 1), _root))


func test_spent_real_blood_is_a_gift_and_changed_native_contents_need_new_confirmation() -> void:
	_material(BONES, Vector3(-0.7, 0, 0))
	_material(RAW_CHAIN)
	var blood: Entity = _material(BLOOD_FLASK, Vector3(0.7, 0, 0))
	var emitter: C_HazardEmitter = blood.get_component(C_HazardEmitter) as C_HazardEmitter
	emitter.fired = true
	emitter.sequence = 1
	assert_false(CraftingQueries.input_for(blood).full_blood)
	await _physics_settled()
	var offer: CraftingQuote = CraftingService.quote(_seller, _workshop)
	var extra: Entity = _material(BUYBACK_ITEM, Vector3(0, 0, 0.7))
	await _physics_settled()
	assert_eq(CraftingService.confirm(_seller, offer), CraftingService.Status.CHANGED)
	assert_true(CommerceService.current().crafting_batches.is_empty())
	assert_true(_world.entity_to_archetype.has(extra))
	await _accept()
	assert_eq(_batch().recipes.size(), 1)
	assert_eq(_batch().recipes[0], _craft_state.profile.recipes[1])
	assert_eq(_batch().gifts.size(), 3)


func test_blocked_output_keeps_debt_and_actual_death_does_not_cancel_ready_result() -> void:
	_material()
	await _accept()
	var batch: CraftingBatch = _batch()
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4, 6, 3)
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = Vector3(36, 3, 0)
	_root.add_child(blocker)
	_kill(NpcPopulationQueries.person_for(&"npc/3"))
	_morning(2)
	await _physics_settled()
	await _tick_crafting()
	assert_false(batch.outputs[0].emitted)
	assert_false(batch.completed)
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 2), _root))
	blocker.free()
	await _physics_settled()
	await _tick_crafting()
	assert_true(batch.outputs[0].emitted)
	var identity: String = batch.outputs[0].entity_id
	var instance: Entity = _world.entity_id_registry.get(identity) as Entity
	await _tick_crafting()
	assert_eq(_world.entity_id_registry.get(identity), instance)
	assert_eq(NpcPopulationQueries.person_for(&"npc/3").death_day, 1)


func test_partial_output_disk_restore_keeps_ids_and_does_not_reissue_missing_emitted_body() -> void:
	_material(BONES, Vector3.ZERO, 10)
	await _accept()
	var batch: CraftingBatch = _batch()
	_morning(2)
	await _tick_crafting()
	var issued: int = 0
	for output: CraftingOutput in batch.outputs:
		if output.emitted:
			issued += 1
	assert_eq(issued, _craft_state.profile.placement.retry_budget)
	assert_lt(issued, batch.outputs.size())
	var first_id: String = batch.outputs[0].entity_id
	_world.remove_entity(_world.entity_id_registry.get(first_id) as Entity)
	_world.flush_command_buffers()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	await _tick_crafting()
	assert_false(_world.entity_id_registry.has(first_id), "Issued item never materializes twice")
	batch = _batch()
	assert_true(batch.outputs[0].taken)
	var unique: PackedStringArray = []
	for output: CraftingOutput in batch.outputs:
		assert_false(output.entity_id in unique)
		unique.append(output.entity_id)
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 2), _root))


func test_local_native_action_cancel_and_changed_confirm_preserve_materials() -> void:
	var bones: Entity = _material()
	await _physics_settled()
	var actions: C_InteractionActionSet = _workshop.get_component(C_InteractionActionSet)
	var action: DEF_CraftingAction = actions.actions[0] as DEF_CraftingAction
	assert_true(action.is_available(_seller, _workshop, _workshop))
	action.execute(_seller, _workshop, _workshop)
	_world.flush_command_buffers()
	var panel: CraftingPanel = _seller.find_child("CraftingPanel", false, false) as CraftingPanel
	assert_not_null(panel)
	if panel == null:
		return
	(panel.get_node("Confirmation") as ConfirmationDialog).canceled.emit()
	assert_true(_world.entity_to_archetype.has(bones))
	assert_true(CommerceService.current().crafting_batches.is_empty())
	await get_tree().process_frame
	panel = CraftingPanelFactory.open(_seller, _workshop)
	assert_not_null(panel)
	if panel == null:
		return
	var dialog: ConfirmationDialog = panel.get_node("Confirmation") as ConfirmationDialog
	_material(BUYBACK_ITEM, Vector3(0.7, 0, 0))
	await _physics_settled()
	dialog.confirmed.emit()
	assert_true(CommerceService.current().crafting_batches.is_empty())
	assert_true(
		(panel.get_node("Confirmation/Contents/Summary") as Label).text.contains("изменился")
	)
	await get_tree().process_frame
	dialog.confirmed.emit()
	assert_eq(CommerceService.current().crafting_batches.size(), 1)
	assert_true(panel.is_queued_for_deletion())
	assert_lt(InteractionControlFocus.current(_seller), InteractionControlFocus.Priority.MODAL)
	await get_tree().process_frame


func test_reserve_rejects_other_consumers_and_incomplete_or_forged_snapshot_rejects() -> void:
	var item: Entity = _material()
	_material(BUYBACK_ITEM, Vector3(0.7, 0, 0))
	await _physics_settled()
	var offer: CraftingQuote = CraftingService.quote(_seller, _workshop)
	var before: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(InventoryService.can_transfer(item, _seller))
	var callbacks: Array[int] = [0]
	item.relationship_added.connect(
		func(_entity: Entity, link: Relationship) -> void:
			if link.relation is R_CraftingReserved:
				callbacks[0] += 1
				assert_false(InventoryService.can_transfer(item, _seller))
				assert_true(WorldSnapshotService.capture(_root, 1).is_empty())
				assert_false(WorldSnapshotService.can_restore(before, _root))
				assert_eq(
					CraftingService.confirm(_seller, offer),
					CraftingService.Status.UNAVAILABLE,
				),
	)
	assert_eq(CraftingService.confirm(_seller, offer), CraftingService.Status.COMMITTED)
	assert_eq(callbacks[0], 1)
	_world.flush_command_buffers()
	var valid: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(valid, _root))
	for defect: String in ["missing", "unconsumed", "retained", "early", "gift", "grace", "day"]:
		var invalid: Dictionary = valid.duplicate(true)
		var commerce: Dictionary = _saved_fields(invalid, C_Commerce)
		var fields: Dictionary = commerce.crafting_batches[0].fields as Dictionary
		match defect:
			"missing":
				fields.erase("signature")
			"unconsumed":
				fields.consumed = false
			"retained":
				fields.inputs[0].fields.removed = false
			"early":
				fields.outputs[0].fields.emitted = true
			"gift":
				fields.gifts[0].fields.quantity += 1
			"grace":
				fields.first_failure = true
			"day":
				fields.ready_day += 1
		assert_false(WorldSnapshotService.can_restore(invalid, _root), defect)
		assert_false(WorldSnapshotService.restore(invalid, _root), defect)
		assert_eq(CommerceService.current().crafting_batches.size(), 1)
		assert_true(_money.operations.is_empty())
#endregion


#region Restore tickets and provenance
func test_in_place_restore_invalidates_queued_retry_and_reissues_one_fresh_request() -> void:
	_material()
	await _accept()
	_morning(2)
	var owner: S_Crafting = null
	for candidate: System in _world.systems:
		if candidate is S_Crafting:
			owner = candidate as S_Crafting
	assert_not_null(owner)
	if owner == null:
		return
	_world.flush_command_buffers()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.process(2.0, "TestCrafting")
	assert_true(_craft_state.retry_queued)
	assert_true(
		WorldSnapshotService.capture(_root, 2).is_empty(),
		"Pending commands reject capture",
	)
	var revision: int = _craft_state.retry_revision
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_false(_craft_state.retry_queued)
	assert_gt(_craft_state.retry_revision, revision)
	_world.process(2.0, "TestCrafting")
	assert_true(_craft_state.retry_queued)
	_world.flush_command_buffers()
	assert_false(_craft_state.retry_queued)
	var batch: CraftingBatch = _batch()
	assert_true(batch.outputs[0].emitted)
	assert_not_null(_world.entity_id_registry.get(batch.outputs[0].entity_id))
	assert_eq(batch.outputs.size(), 1)
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 2), _root))


func test_real_foreign_extraction_and_late_shell_registration_keep_historical_unknown() -> void:
	var parcel: E_Package = _arrived_cargo("crafting/foreign/toy", false)
	var items: Array[Entity] = PackageContentsService.release(parcel, _seller)
	assert_eq(items.size(), 1)
	if items.size() != 1:
		return
	var body: RigidBody3D = items[0] as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.linear_velocity = Vector3.ZERO
	body.global_position = Vector3(36, 1.2, 0)
	var state_before: Dictionary = SaveDataCodec.component_data(
		parcel.get_component(C_PackageState)
	)
	await _accept()
	assert_eq(SaveDataCodec.component_data(parcel.get_component(C_PackageState)), state_before)
	assert_eq(_batch().inputs[0].source_package_id, "crafting/foreign/toy")
	assert_true(_batch().inputs[0].source_history_id.is_empty())
	var signature: String = _batch().signature
	assert_eq(
		PackageRegistrationService.register_package(parcel).outcome,
		PackageScanResult.Outcome.REGISTERED,
	)
	_world.flush_command_buffers()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(_batch().signature, signature)
	assert_true(_batch().inputs[0].source_history_id.is_empty())
	assert_true(_money.operations.is_empty())


func test_material_with_cargo_in_a_descendant_slot_cannot_be_given_as_hidden_payload() -> void:
	var outer: Entity = _material(RAW_CHAIN)
	var slot: Entity = Entity.new()
	(outer as Node).add_child(slot)
	_world.add_entity(slot, null, false)
	var cargo: Entity = _material(BUYBACK_ITEM, Vector3(8, 0, 0))
	cargo.add_relationship(Relationship.new(R_StoredIn.new(), slot))
	await _physics_settled()
	var offer: CraftingQuote = CraftingService.quote(_seller, _workshop)
	assert_true(offer.reason.contains("опорожните"))
	assert_eq(CraftingService.confirm(_seller, offer), CraftingService.Status.UNAVAILABLE)
	assert_true(_world.entity_to_archetype.has(outer))
	assert_true(_world.entity_to_archetype.has(cargo))
	assert_true(CommerceService.current().crafting_batches.is_empty())
#endregion


#region Permanent point identity
func test_missing_workshop_keeps_promise_and_a_new_id_cannot_reset_its_campaign() -> void:
	_material()
	await _accept()
	var point_id: String = _workshop.id
	var operation_id: StringName = _batch().operation_id
	_world.remove_entity(_workshop)
	await _physics_settled()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(_batch().operation_id, operation_id)
	var wrong: E_CraftingContainer = WORKSHOP.instantiate() as E_CraftingContainer
	(wrong as Node as Node3D).position = Vector3(36, 0, 0)
	EntityCompositionFixture.register(_world, wrong)
	assert_false(CraftingQueries.available_reason(wrong, _seller).is_empty())
	_world.remove_entity(wrong)
	await _physics_settled()
	_workshop = WORKSHOP.instantiate() as E_CraftingContainer
	_workshop.id = point_id
	(_workshop as Node as Node3D).position = Vector3(36, 0, 0)
	EntityCompositionFixture.register(_world, _workshop)
	_craft_state = _workshop.get_component(C_Crafting) as C_Crafting
	_morning(2)
	await _physics_settled()
	await _tick_crafting()
	assert_eq(CommerceService.current().crafting_batches.size(), 1)
	assert_eq(_batch().operation_id, operation_id)
	assert_true(_batch().outputs[0].emitted)
	assert_not_null(_world.entity_id_registry.get(_batch().outputs[0].entity_id))
	assert_true(_money.operations.is_empty())
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 2), _root))
#endregion
