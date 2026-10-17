extends GutTest
## Реальный кузов, общий возврат, цена стека и сохраняемая граница удаления/выплаты.

var _cycle: C_DayCycle
var _wallet: C_Wallet
var _flow: C_CustomerFlow
var _session: Entity
var _root: Node3D
var _world: World
var _zone: E_ReceivingZone
var _state: C_Receiving

const RAW_SLOT: String = "user://gut_truck_cargo_raw_roundtrip.pvzh"


## Minimal owner with an actual Carry anchor; physics and grip lifecycle remain real.
class RawCarryHolder extends Entity:
	## Authored-equivalent anchor required by the live grip contract.
	var hold_anchor: Node3D


#region Окружение обратного груза
func before_each() -> void:
	var fixture: PackedScene = load("res://tests/fixtures/truck_cargo_raw.tscn") as PackedScene
	_root = fixture.instantiate() as Node3D
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_session = Entity.new()
	_session.component_resources = [C_DayCycle.new(), C_PackageLedger.new()]
	_world.add_entity(_session)
	_zone = (
		load("res://content/domains/packages/entities/receiving_zone.tscn") as PackedScene
	).instantiate() as E_ReceivingZone
	_zone.package_parent = _root
	var parking: Marker3D = Marker3D.new()
	_root.add_child(parking)
	_zone.truck_parking = parking
	_world.add_entity(_zone)
	_state = _zone.get_component(C_Receiving) as C_Receiving
	_session.add_component(C_Wallet.new())
	_session.add_component(C_CustomerFlow.new())
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle
	_wallet = _session.get_component(C_Wallet) as C_Wallet
	_flow = _session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle.day_index = 2
	_state.last_started_day = 2
	_state.batch_id = "cargo:2"
	_zone.supply = _zone.supply.duplicate(true) as DEF_Delivery


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RAW_SLOT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RAW_SLOT + ".tmp"))
	_world.purge(false)
	_root.queue_free()
	ECS.world = null
	await get_tree().process_frame
	await get_tree().process_frame


func _ready_truck() -> E_MorningTruck:
	var truck: E_MorningTruck = _zone.ensure_truck()
	truck.door_animation.advance(1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return truck


func _item(truck: E_MorningTruck, price: int = -1, quantity: int = 1) -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(Entity)
	body.freeze = true
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.3
	collision.shape = shape
	body.add_child(collision)
	var item: Entity = body as Node as Entity
	item.component_resources = [C_Grabbable.new()]
	if price >= 0:
		var inventory: C_InventoryItem = C_InventoryItem.new()
		inventory.definition = DEF_InventoryItem.new()
		inventory.definition.market_price = price
		inventory.quantity = quantity
		item.component_resources.append(inventory)
	_world.add_entity(item)
	body.global_transform = truck.cargo_slots[0].global_transform
	return item


func _parcel(truck: E_MorningTruck, refused: bool) -> Entity:
	var parcel: Entity = _item(truck, 500)
	var identity: C_Package = C_Package.new()
	identity.package_id = "old/refused"
	parcel.add_component(identity)
	var state: C_PackageState = C_PackageState.new()
	state.registration = C_PackageState.Registration.REGISTERED
	state.registration_number = 7
	parcel.add_component(state)
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = identity.package_id
	record.number = 7
	record.day_index = 1
	(_session.get_component(C_PackageLedger) as C_PackageLedger).records.append(record)
	var visit: CustomerVisit = CustomerVisit.new()
	visit.package_id = identity.package_id
	visit.arrival_day = 1
	visit.actual = (
		CustomerVisit.Actual.PLAYER_DENIED if refused else CustomerVisit.Actual.NOT_RESOLVED
	)
	visit.declaration = (
		CustomerVisit.Declaration.REFUSED if refused else CustomerVisit.Declaration.NONE
	)
	visit.money_delta = -150
	visit.settlement_committed = true
	_flow.visits.append(visit)
	return parcel
#endregion


#region Состав и доход
## Extracts the real scene's authored bindings without starting its World or autosave.
func test_primitive_scene_replacement_dispatches_real_cargo_through_start_shift() -> void:
	var level: Node3D = (
		load("res://content/scenes/primitive_test_level.tscn") as PackedScene
	).instantiate() as Node3D
	assert_null(level.get_node_or_null("Entityes/PackageReturnPoint"))
	var authored_zone: E_ReceivingZone = level.get_node("Entityes/ReceivingZone") as E_ReceivingZone
	var parking: Marker3D = level.get_node("TruckParking") as Marker3D
	assert_same(authored_zone.truck_parking, parking)
	for node: Node in level.find_children("*", "RigidBody3D", true, false):
		if node.get_script() == null and RawPhysicsActorService.is_standalone(node as RigidBody3D):
			assert_true(
				RawPhysicsActorService.actor_id(node as RigidBody3D).begins_with("placed/"),
				"Portable native placement: " + String(level.get_path_to(node)),
			)
	authored_zone.owner = null
	parking.owner = null
	authored_zone.get_parent().remove_child(authored_zone)
	level.remove_child(parking)
	_world.remove_entity(_zone)
	_root.add_child(parking)
	authored_zone.package_parent = _root
	_world.add_entity(authored_zone)
	_zone = authored_zone
	_state = _zone.get_component(C_Receiving) as C_Receiving
	_state.last_started_day = _cycle.day_index
	_state.batch_id = "primitive/cargo/2"
	level.free()
	var truck: E_MorningTruck = await _ready_truck()
	var item: Entity = _item(truck, 25, 3)
	var transition: DayTransitionRequest = DayTransitionRequest.new()
	transition.kind = DayTransitionRequest.Kind.START_SHIFT
	transition.expected_day = _cycle.day_index
	transition.expected_phase = _cycle.phase
	var phase_system: S_DayPhase = S_DayPhase.new()
	_world.add_system(phase_system)
	assert_true(DayPhaseService.submit(transition))
	phase_system.process([_session], [[_cycle]], 0.0)
	phase_system.cmd.execute()
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY)
	assert_false(_world.entities.has(item))
	assert_eq(_wallet.balance, 7)
	assert_eq(_state.dispatched_batch_id, _state.batch_id)


func test_loading_and_extraction_do_not_sell_before_shift() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var item: Entity = _item(truck, 25, 3)
	assert_true(truck.overlaps_cargo(item as Node as PhysicsBody3D))
	assert_eq(_wallet.balance, 0)
	assert_true(_state.cargo_receipts.is_empty())
	(item as Node as Node3D).global_position += Vector3(10, 0, 0)
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_true(_world.entities.has(item))
	assert_eq(_wallet.balance, 0)
	assert_true(_state.cargo_receipts.is_empty())


func test_price_uses_stack_quantity_floor_and_authored_percent() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	_zone.supply.truck_resale_percent = 15
	var item: Entity = _item(truck, 25, 3)
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_false(_world.entities.has(item))
	assert_eq(_wallet.balance, 11)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_wallet.operations[0].reason, MoneyOperation.Reason.TRUCK_RESALE)
	assert_eq(_state.cargo_receipts[0].amount, 11)
	assert_true(_state.cargo_receipts[0].removed)
	assert_true(_state.cargo_receipts[0].settled)


func test_unpriced_trash_and_dead_character_are_disposed_without_income() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var trash: Entity = _item(truck)
	var corpse: Entity = _item(truck)
	corpse.add_component(C_NpcIdentity.new())
	corpse.add_component(C_Death.new())
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_false(_world.entities.has(trash))
	assert_false(_world.entities.has(corpse))
	assert_eq(_wallet.balance, 0)
	assert_true(_wallet.operations.is_empty())
	assert_eq(_state.cargo_receipts.size(), 2)


func test_live_character_held_owned_and_cart_items_are_excluded() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var live: Entity = _item(truck, 25)
	live.add_component(C_NpcIdentity.new())
	var held: Entity = _item(truck, 25)
	held.add_relationship(Relationship.new(R_HeldBy.new(), _session))
	var owned: Entity = _item(truck, 25)
	owned.add_relationship(Relationship.new(R_OwnedBy.new(), _session))
	var cart_item: Entity = _item(truck, 25)
	cart_item.add_relationship(Relationship.new(R_CartCargo.new(), _session))
	var fixed: Entity = _item(truck, 25)
	fixed.add_to_group(&"no_carry")
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	for item: Entity in [live, held, owned, cart_item, fixed]:
		assert_true(_world.entities.has(item))
	assert_eq(_wallet.balance, 0)
	assert_true(_state.cargo_receipts.is_empty())


func test_actual_refusal_returns_without_replacing_settlement_or_declaration() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var parcel: Entity = _parcel(truck, true)
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_false(_world.entities.has(parcel))
	assert_eq(_flow.visits[0].disposition, CustomerVisit.Disposition.RETURNED)
	assert_eq(_flow.visits[0].declaration, CustomerVisit.Declaration.REFUSED)
	assert_eq(_flow.visits[0].actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(_flow.visits[0].money_delta, -150)
	assert_true(_flow.visits[0].settlement_committed)
	assert_false((_session.get_component(C_PackageLedger) as C_PackageLedger).records[0].active)
	assert_eq(_wallet.balance, 0)


func test_foreign_parcel_has_no_sale_and_does_not_invent_lost_or_warehouse_return() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var parcel: Entity = _parcel(truck, false)
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_false(_world.entities.has(parcel))
	assert_eq(_wallet.balance, 0)
	assert_eq(_flow.visits[0].actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_flow.visits[0].declaration, CustomerVisit.Declaration.NONE)
	assert_eq(_flow.visits[0].disposition, CustomerVisit.Disposition.WAREHOUSE)
	assert_true((_session.get_component(C_PackageLedger) as C_PackageLedger).records[0].active)
#endregion


#region Scriptless native cargo and persistence
func test_raw_held_snapshot_releases_carry_and_restores_original_sleep_policy() -> void:
	var body: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	var holder: RawCarryHolder = RawCarryHolder.new()
	holder.component_resources = [C_GrabControl.new(), C_CarryLoad.new(), C_Strength.new()]
	holder.hold_anchor = Node3D.new()
	holder.add_child(holder.hold_anchor)
	_world.add_entity(holder)
	var proxy: Entity = PhysicsGrabTarget.handle_for(body, true)
	var grip: Relationship = Relationship.new(R_HeldBy.new(), holder)
	proxy.add_relationship(grip)
	assert_true(GrabService.grip_added(proxy, grip), "Real applied Carry lifecycle")
	assert_false(body.can_sleep)
	var snapshot: Dictionary = RawPhysicsSnapshot.capture(_root)
	assert_true(RawPhysicsSnapshot.valid(snapshot.actors, _root))
	RawPhysicsSnapshot.restore(snapshot.actors as Array, _root)
	assert_null(GrabQueries.held_relationship(proxy))
	assert_null(GrabQueries.held_in_slot(holder, C_Grabbable.HoldSlot.CARRY))
	assert_true(body.can_sleep, "Released raw body preserves its original sleep policy")


func test_raw_snapshot_preserves_an_explicit_sleep_veto_without_carry() -> void:
	var body: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	body.can_sleep = false
	var snapshot: Dictionary = RawPhysicsSnapshot.capture(_root)
	body.can_sleep = true
	assert_true(RawPhysicsSnapshot.valid(snapshot.actors, _root))
	RawPhysicsSnapshot.restore(snapshot.actors as Array, _root)
	assert_false(body.can_sleep, "A genuine body policy remains false")


func test_raw_cargo_disposes_body_and_transient_proxy_without_income_or_reentry() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var body: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	body.global_transform = truck.cargo_slots[0].global_transform
	var identity: String = RawPhysicsActorService.actor_id(body)
	var proxy: Entity = PhysicsGrabTarget.handle_for(body, true)
	assert_not_null(proxy)
	var callback_snapshots: Array[Dictionary] = []
	_world.entity_removed.connect(
		func(removed: Entity) -> void:
			if removed == proxy:
				callback_snapshots.append(WorldSnapshotService.capture(_root, 2)),
	)
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_false(_world.entities.has(proxy))
	assert_null(_root.get_node_or_null("Props/Barrel"))
	assert_eq(callback_snapshots, [{ }])
	assert_eq(_wallet.balance, 0)
	assert_eq(_state.cargo_receipts.size(), 1)
	assert_eq(_state.cargo_receipts[0].raw_actor_id, identity)
	assert_true(_state.cargo_receipts[0].entity_id.is_empty())
	assert_true(_state.cargo_receipts[0].removed and _state.cargo_receipts[0].settled)
	assert_true(TruckCargoService.commit(_zone, _cycle))
	assert_eq(_state.cargo_receipts.size(), 1)


func test_raw_held_fixed_and_no_carry_bodies_are_excluded() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var held: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	held.global_transform = truck.cargo_slots[0].global_transform
	var proxy: Entity = PhysicsGrabTarget.handle_for(held, true)
	proxy.add_relationship(Relationship.new(R_HeldBy.new(), _session))
	var prefab: PackedScene = load(held.scene_file_path) as PackedScene
	var fixed: RigidBody3D = prefab.instantiate() as RigidBody3D
	var excluded: RigidBody3D = prefab.instantiate() as RigidBody3D
	_root.add_child(fixed)
	_root.add_child(excluded)
	fixed.global_transform = held.global_transform
	excluded.global_transform = held.global_transform
	fixed.freeze = true
	excluded.add_to_group(&"no_carry")
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_true(held.is_inside_tree())
	assert_true(fixed.is_inside_tree())
	assert_true(excluded.is_inside_tree())
	assert_true(_state.cargo_receipts.is_empty())


func test_native_mechanism_part_is_excluded_even_without_freeze_or_no_carry() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var mechanism: Entity = Entity.new()
	_world.add_entity(mechanism)
	var body: RigidBody3D = (
		load("res://resources/kay_kit/prototype_bits/Assets/gltf/Barrel_A/Barrel_A_rigid.tscn")
		as PackedScene
	).instantiate() as RigidBody3D
	mechanism.add_child(body)
	body.global_transform = truck.cargo_slots[0].global_transform
	assert_true(GrabQueries.is_carry_candidate(body))
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_true(body.is_inside_tree())
	assert_true(_state.cargo_receipts.is_empty())


func test_raw_disposal_roundtrip_and_loading_earlier_snapshot_restore_native_body() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var body: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	body.global_transform = truck.cargo_slots[0].global_transform
	var pose: Transform3D = body.global_transform
	var before: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(before, _root))
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	var after: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_eq(AutosaveStore.write(after, RAW_SLOT), OK)
	after = AutosaveStore.read(RAW_SLOT)
	assert_true(WorldSnapshotService.can_restore(after, _root))
	assert_false(after.raw_actors[0].present)
	assert_true(WorldSnapshotService.restore(before, _root))
	var restored: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	assert_not_null(restored)
	assert_null(restored.get_script(), "The native physics body does not become an Entity")
	assert_true(restored.global_transform.is_equal_approx(pose))
	assert_true(_state.cargo_receipts.is_empty())
	assert_true(WorldSnapshotService.restore(after, _root))
	assert_null(_root.get_node_or_null("Props/Barrel"))
	assert_true(TruckCargoService.commit(_zone, _cycle))
	assert_eq(_state.cargo_receipts.size(), 1)
	assert_eq(_wallet.balance, 0)


func test_raw_disposal_survives_a_fresh_native_scene_instance() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var body: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	body.global_transform = truck.cargo_slots[0].global_transform
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	var saved: Dictionary = RawPhysicsSnapshot.capture(_root)
	var fresh: Node3D = (load(_root.scene_file_path) as PackedScene).instantiate() as Node3D
	add_child(fresh)
	assert_not_null(fresh.get_node_or_null("Props/Barrel"))
	assert_true(RawPhysicsSnapshot.valid(saved.actors, fresh))
	RawPhysicsSnapshot.restore(saved.actors as Array, fresh)
	assert_null(fresh.get_node_or_null("Props/Barrel"))
	fresh.queue_free()


func test_invalid_raw_identity_and_receipt_presence_fail_before_world_mutation() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var forged: Dictionary = snapshot.duplicate(true)
	forged.raw_actors[0].actor_id = "placed/ffffffffffffffffffffffffffffffff"
	assert_false(WorldSnapshotService.can_restore(forged, _root))
	assert_false(WorldSnapshotService.restore(forged, _root))
	assert_not_null(_root.get_node_or_null("Props/Barrel"))
	var receipt: TruckCargoReceipt = TruckCargoReceipt.new()
	receipt.batch_id = _state.batch_id
	receipt.day_index = 2
	receipt.raw_actor_id = String(snapshot.raw_actors[0].actor_id)
	receipt.removed = true
	receipt.settled = true
	_state.cargo_receipts.append(receipt)
	assert_false(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 2), _root))
	assert_not_null(_root.get_node_or_null("Props/Barrel"))
	assert_eq(_wallet.balance, 0)


func test_duplicate_raw_identity_and_untagged_placement_fail_closed() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var body: RigidBody3D = _root.get_node("Props/Barrel") as RigidBody3D
	body.global_transform = truck.cargo_slots[0].global_transform
	var prefab: PackedScene = load(body.scene_file_path) as PackedScene
	var duplicate: RigidBody3D = prefab.instantiate() as RigidBody3D
	duplicate.add_to_group(
		StringName(RawPhysicsActorService.ID_GROUP_PREFIX + RawPhysicsActorService.actor_id(body))
	)
	_root.add_child(duplicate)
	assert_false(ReceivingShiftService.commit_departure(_cycle))
	assert_true(body.is_inside_tree())
	assert_true(WorldSnapshotService.capture(_root, 2).is_empty())
	_root.remove_child(duplicate)
	duplicate.free()
	for group: StringName in body.get_groups():
		if String(group).begins_with(RawPhysicsActorService.ID_GROUP_PREFIX):
			body.remove_from_group(group)
	assert_false(ReceivingShiftService.commit_departure(_cycle))
	assert_true(body.is_inside_tree())
	assert_true(WorldSnapshotService.capture(_root, 2).is_empty())
#endregion


#region Повтор, отказ и восстановление
func test_wallet_rejection_keeps_cargo_and_does_not_mark_batch_dispatched() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var item: Entity = _item(truck, 25, 3)
	_wallet.balance = WalletService.MAX_AMOUNT
	assert_false(ReceivingShiftService.commit_departure(_cycle))
	assert_true(_world.entities.has(item))
	assert_eq(_wallet.balance, WalletService.MAX_AMOUNT)
	assert_true(_state.cargo_batch_id.is_empty())
	assert_true(_state.dispatched_batch_id.is_empty())
	assert_false(truck.is_departing())


func test_multiple_cargo_is_preflighted_as_one_total_before_any_removal() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var first: Entity = _item(truck, 25, 3)
	var second: Entity = _item(truck, 25, 3)
	_wallet.balance = WalletService.MAX_AMOUNT - 10
	assert_false(ReceivingShiftService.commit_departure(_cycle))
	assert_true(_world.entities.has(first))
	assert_true(_world.entities.has(second))
	assert_true(_wallet.operations.is_empty())


func test_reentrant_removal_and_repeated_commit_cannot_pay_twice() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var item: Entity = _item(truck, 25, 3)
	var attempts: Array[bool] = []
	var captures: Array[Dictionary] = []
	var on_removal: Callable = func(removed: Entity) -> void:
		if removed == item:
			attempts.append(TruckCargoService.commit(_zone, _cycle))
			captures.append(WorldSnapshotService.capture(_root, _cycle.day_index))
	_world.entity_removed.connect(on_removal)
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_eq(attempts, [false])
	assert_eq(captures.size(), 1)
	assert_true(captures[0].is_empty(), "Structural callback cannot save an intermediate world")
	assert_false(WorldSnapshotService.capture(_root, _cycle.day_index).is_empty())
	assert_true(TruckCargoService.commit(_zone, _cycle))
	assert_eq(_wallet.balance, 7)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_state.cargo_receipts.size(), 1)


func test_receipts_and_wallet_roundtrip_do_not_repeat_paid_removal() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	_item(truck, 25, 3)
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	var receiving_data: Dictionary = SaveDataCodec.component_data(_state).fields as Dictionary
	var wallet_data: Dictionary = SaveDataCodec.component_data(_wallet).fields as Dictionary
	_state.cargo_receipts.clear()
	_wallet.balance = 0
	_wallet.operations.clear()
	assert_true(SaveDataCodec.apply_fields(_state, receiving_data))
	assert_true(SaveDataCodec.apply_fields(_wallet, wallet_data))
	assert_true(TruckCargoService.commit(_zone, _cycle))
	assert_eq(_wallet.balance, 7)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_state.cargo_receipts.size(), 1)


func test_removed_unpaid_receipt_restores_and_completes_without_live_item() -> void:
	await _ready_truck()
	var receipt: TruckCargoReceipt = TruckCargoReceipt.new()
	receipt.batch_id = _state.batch_id
	receipt.entity_id = "removed-item"
	receipt.day_index = 2
	receipt.kind = TruckCargoReceipt.Kind.SALE
	receipt.amount = 7
	receipt.removed = true
	_state.cargo_batch_id = _state.batch_id
	_state.cargo_receipts.append(receipt)
	var data: Dictionary = SaveDataCodec.component_data(_state).fields as Dictionary
	_state.cargo_receipts.clear()
	assert_true(SaveDataCodec.apply_fields(_state, data))
	assert_true(ReceivingShiftService.commit_departure(_cycle))
	assert_true(_state.cargo_receipts[0].settled)
	assert_eq(_wallet.balance, 7)
	assert_eq(_wallet.operations.size(), 1)


func test_invalid_saved_receipt_is_rejected_before_live_mutations() -> void:
	var receipt: TruckCargoReceipt = TruckCargoReceipt.new()
	receipt.batch_id = _state.batch_id
	receipt.entity_id = "invalid-item"
	receipt.day_index = 2
	receipt.settled = true
	_state.cargo_receipts.append(receipt)
	assert_false(ReceivingSnapshotRules.valid(_state, _zone))
	assert_eq(_wallet.balance, 0)
	assert_eq(_state.dispatched_batch_id, "")
#endregion


#region Shared material reservation
func test_crafting_reserve_excludes_actual_cargo_until_the_next_manifest() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	var item: Entity = _item(truck, 100)
	var point: E_CraftingContainer = (
		load("res://content/domains/commerce/entities/crafting_shy_container.tscn") as PackedScene
	).instantiate() as E_CraftingContainer
	(point as Node as Node3D).position = Vector3(40, 0, 0)
	EntityCompositionFixture.register(_world, point)
	var reserve: Relationship = Relationship.new(R_CraftingReserved.new(), point)
	item.add_relationship(reserve)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(truck.overlaps_cargo(item as Node as RigidBody3D))
	assert_true(TruckCargoService.commit(_zone, DayPhaseQueries.current()))
	assert_true(_world.entity_to_archetype.has(item))
	var receiving: C_Receiving = _zone.get_component(C_Receiving) as C_Receiving
	assert_true(receiving.cargo_receipts.is_empty())
	item.remove_relationship(reserve)
	receiving.batch_id = "crafting/next-manifest"
	assert_true(TruckCargoService.commit(_zone, DayPhaseQueries.current()))
	assert_false(_world.entity_to_archetype.has(item))
	assert_eq(receiving.cargo_receipts.size(), 1)
#endregion
