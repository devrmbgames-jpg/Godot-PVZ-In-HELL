extends GutTest


class Actor extends Entity:
	var interaction_ray_cast: RayCast3D
	var hold_anchor: Node3D
	var right_hand_slot: Node3D
	var left_hand_slot: Node3D
	var lowered_right_hand_slot: Node3D
	var lowered_left_hand_slot: Node3D


var _world: World
var _actor: Actor
var _slot: E_PhysicalSlot
var _item: Entity
var _body: RigidBody3D


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_world.add_observer(O_PhysicalSlotLifecycle.new())
	_actor = Actor.new()
	_actor.component_resources = [C_Controller.new(), C_Interactor.new(), C_GrabControl.new(), C_CarryLoad.new(), C_Strength.new()]
	var ray: RayCast3D = RayCast3D.new()
	ray.position = Vector3(0, 1, 0)
	ray.target_position = Vector3(0, 0, -3)
	_actor.add_child(ray)
	_actor.interaction_ray_cast = ray
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0.5, 1, -0.5)
	_actor.add_child(anchor)
	_actor.hold_anchor = anchor
	_actor.right_hand_slot = anchor
	_actor.left_hand_slot = anchor
	_actor.lowered_right_hand_slot = anchor
	_actor.lowered_left_hand_slot = anchor
	_world.add_entity(_actor)
	_slot = (load("res://content/entities/props/physical_slot.tscn") as PackedScene).instantiate() as E_PhysicalSlot
	(_slot as Node as Node3D).position = Vector3(0, 1, -1.5)
	_world.add_entity(_slot)
	_item = _make_item()
	_body = GrabService.physical_body(_item)
	_hold(_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	await get_tree().physics_frame
	await get_tree().process_frame


func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		PhysicalSlotService.entity_unavailable(entity)
		GrabService.entity_unavailable(entity)
	_world.free()
	ECS.world = null


func _make_item() -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)
	body.position = Vector3(1, 1, -1)
	body.gravity_scale = 0.0
	body.collision_layer = 8
	body.collision_mask = 29
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.1
	collision.shape = shape
	body.add_child(collision)
	var item: Entity = body as Node as Entity
	var config: C_Grabbable = C_Grabbable.new()
	config.allowed_hand_slots = 6
	item.component_resources = [config, C_Interactable.new()]
	_world.add_entity(item)
	return item


func _hold(item: Entity, hand: C_Grabbable.HoldSlot) -> void:
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = hand
	item.add_relationship(Relationship.new(grip, _actor))


func test_store_freezes_attaches_and_restores_physics_on_take() -> void:
	var original_parent: Node = _body.get_parent()
	_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_body.set_physics_process(true)
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_null(GrabService.held_relationship(_item))
	assert_eq(PhysicalSlotService.occupant(_slot), _item)
	assert_true(_body.freeze)
	assert_eq(_body.collision_layer, 0)
	assert_eq(_body.collision_mask, 0)
	assert_false(_body.is_physics_processing())
	assert_eq(_body.get_parent(), _slot.anchor)
	(_slot as Node as Node3D).position.x += 0.2
	assert_eq(_body.global_position, _slot.anchor.global_position)
	(_slot as Node as Node3D).position.x -= 0.2
	assert_true(GrabService.take_from_storage(_actor, _item, C_Grabbable.HoldSlot.LEFT_HAND))
	assert_null(PhysicalSlotService.relationship(_item))
	assert_eq(GrabService.held_in_slot(_actor, C_Grabbable.HoldSlot.LEFT_HAND), _item)
	assert_false(_body.freeze)
	assert_eq(_body.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
	assert_eq(_body.collision_layer, 8)
	assert_eq(_body.collision_mask, 29)
	assert_true(_body.is_physics_processing())
	assert_eq(_body.get_parent(), original_parent)


func test_occupied_slot_and_filter_failure_preserve_hand() -> void:
	var config: C_PhysicalSlot = _slot.get_component(C_PhysicalSlot) as C_PhysicalSlot
	config.filter = DEF_AccessRequirement.new()
	config.filter.required_item_id = &"key"
	assert_false(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_eq(GrabService.held_in_slot(_actor, C_Grabbable.HoldSlot.RIGHT_HAND), _item)
	config.filter = null
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	var other: Entity = _make_item()
	_hold(other, C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_false(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_eq(GrabService.held_in_slot(_actor, C_Grabbable.HoldSlot.RIGHT_HAND), other)


func test_full_hand_requires_explicit_common_replacement() -> void:
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	var other: Entity = _make_item()
	_hold(other, C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_false(GrabService.take_from_storage(_actor, _item, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_true(_body.freeze)
	assert_true(GrabService.take_from_storage(_actor, _item, C_Grabbable.HoldSlot.RIGHT_HAND, true))
	assert_null(GrabService.held_relationship(other))
	assert_true(GrabService.entity_available(other))


func test_slot_removal_restores_item_and_releases_ownership() -> void:
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	_world.remove_entity(_slot)
	assert_null(PhysicalSlotService.relationship(_item))
	assert_false(_body.freeze)
	assert_eq(_body.collision_layer, 8)
	assert_true(GrabService.entity_available(_item))


func test_external_relation_removal_restores_physics() -> void:
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	_item.remove_relationship(PhysicalSlotService.relationship(_item))
	assert_null(PhysicalSlotService.occupant(_slot))
	assert_false(_body.freeze)
	assert_eq(_body.collision_mask, 29)


func test_worn_access_requires_mount_relationship() -> void:
	var identity: C_AccessItem = C_AccessItem.new()
	identity.item_id = &"key"
	_item.add_component(identity)
	var requirement: DEF_AccessRequirement = DEF_AccessRequirement.new()
	requirement.required_item_id = &"key"
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_false(ItemAccessService.evaluate(_actor, requirement).is_allowed())
	_slot.add_relationship(Relationship.new(R_SlotMountedOn.new(), _actor))
	assert_true(ItemAccessService.evaluate(_actor, requirement).is_allowed())


func test_resolver_uses_swapped_secondary_hand_without_leaking_to_carry() -> void:
	var interactor: C_Interactor = _actor.get_component(C_Interactor) as C_Interactor
	interactor.target = _slot
	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	control.swap_hand_controls = true
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.USE)
	assert_not_null(choice)
	if choice != null:
		choice.action.execute(_actor, choice.source, choice.target)
	assert_eq(PhysicalSlotService.occupant(_slot), _item)
	assert_null(GrabService.held_object(_actor))


func test_removing_slot_configuration_restores_stored_body() -> void:
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	_slot.remove_component(C_PhysicalSlot)
	assert_null(PhysicalSlotService.relationship(_item))
	assert_false(_body.freeze)
	assert_eq(_body.collision_layer, 8)


func test_mount_owner_removal_releases_stored_item() -> void:
	_slot.reparent(_actor)
	_slot.add_relationship(Relationship.new(R_SlotMountedOn.new(), _actor))
	assert_true(PhysicalSlotService.store(_actor, _slot, C_Grabbable.HoldSlot.RIGHT_HAND))
	_world.remove_entity(_actor)
	assert_false(_world.entities.has(_slot))
	assert_null(PhysicalSlotService.relationship(_item))
	assert_false(_body.freeze)
	assert_true(GrabService.entity_available(_item))
	await get_tree().process_frame
	assert_false(is_instance_valid(_slot))
	for registered: Entity in _world.entities:
		assert_true(is_instance_valid(registered), "No freed child slot remains in ECS")
