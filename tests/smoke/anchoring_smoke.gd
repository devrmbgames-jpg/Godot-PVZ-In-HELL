extends Node
## One-shot real-physics support-cluster validation for player anchoring.

var _world: World
var _actor: Entity
var _hammer: Entity
var _ray: RayCast3D
var _interactor: C_Interactor


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_actor = _make_actor()
	_hammer = _make_hammer()
	_hold_hammer()

	var bottom: Entity = _box(Vector3(0.0, 0.25, -2.0))
	var middle: Entity = _box(Vector3(0.20, 0.75, -2.0))
	var top: Entity = _box(Vector3(0.40, 1.25, -2.0))
	var authored_frozen: Entity = _box(Vector3(0.60, 1.75, -2.0))
	var authored_body: RigidBody3D = GrabService.physical_body(authored_frozen)
	authored_body.freeze = true

	await _sync_physics()
	assert(_anchor_visible(bottom), "Bottom must anchor through the real ray target")
	assert(_anchor_visible(middle), "Middle must anchor before support-cluster validation")
	assert(_anchor_visible(top), "Top must anchor before support-cluster validation")
	assert(AnchoringService.is_player_anchored(bottom))
	assert(AnchoringService.is_player_anchored(middle))
	assert(AnchoringService.is_player_anchored(top))
	assert(not AnchoringService.is_player_anchored(authored_frozen))

	await _sync_physics()
	assert(_aim(bottom))
	assert(AnchoringService.unfix(_actor, bottom), "Root unfix must succeed")
	assert(not AnchoringService.is_player_anchored(bottom))
	assert(not AnchoringService.is_player_anchored(middle), "Direct supported anchor must join unfix")
	assert(not AnchoringService.is_player_anchored(top), "Recursive supported anchor must join unfix")
	assert(not GrabService.physical_body(bottom).freeze)
	assert(not GrabService.physical_body(middle).freeze)
	assert(not GrabService.physical_body(top).freeze)
	assert(authored_body.freeze, "Authored frozen neighbor must never be unfrozen")

	_world.free()
	ECS.world = null
	print("R11.1 anchoring support smoke PASS")
	get_tree().quit()


func _make_actor() -> Entity:
	var actor_body: RigidBody3D = RigidBody3D.new()
	actor_body.set_script(E_RigidBodyCharacter)
	actor_body.freeze = true
	var actor: Entity = actor_body as Node as Entity
	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -3)
	actor_body.add_child(_ray)
	actor.set("interaction_ray_cast", _ray)

	var hand: Marker3D = Marker3D.new()
	hand.position = Vector3(0.8, 0.8, -0.5)
	actor_body.add_child(hand)
	actor.set("hold_anchor", hand)
	actor.set("right_hand_slot", hand)
	actor.set("left_hand_slot", hand)
	actor.set("lowered_right_hand_slot", hand)
	actor.set("lowered_left_hand_slot", hand)
	_interactor = C_Interactor.new()
	_interactor.collision_mask = 8
	actor.component_resources = [
		C_Controller.new(),
		_interactor,
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
	]
	_world.add_entity(actor)
	_interactor = actor.get_component(C_Interactor) as C_Interactor
	return actor


func _make_hammer() -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)
	body.position = Vector3(1.0, 1.0, -0.5)
	body.gravity_scale = 0.0
	body.collision_layer = 8
	body.collision_mask = 29
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.1
	collision.shape = shape
	body.add_child(collision)

	var hammer: Entity = body as Node as Entity
	var grabbable: C_Grabbable = C_Grabbable.new()
	grabbable.allowed_hand_slots = 6
	hammer.component_resources = [grabbable, C_AnchorTool.new()]
	_world.add_entity(hammer)
	return hammer


func _box(location: Vector3) -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)
	body.position = location
	body.gravity_scale = 0.0
	body.collision_layer = 8
	body.collision_mask = 29
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.5
	collision.shape = shape
	body.add_child(collision)
	var item: Entity = body as Node as Entity
	var config: C_Anchorable = C_Anchorable.new()
	config.minimum_rest_seconds = 0.0
	config.support_tolerance = 0.05
	item.component_resources = [config, C_Interactable.new()]
	_world.add_entity(item)
	return item


func _hold_hammer() -> void:
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	_hammer.add_relationship(Relationship.new(grip, _actor))
	assert(GrabService.held_in_slot(_actor, C_Grabbable.HoldSlot.RIGHT_HAND) == _hammer)


func _anchor_visible(target: Entity) -> bool:
	if not _aim(target):
		return false

	var config: C_Anchorable = target.get_component(C_Anchorable) as C_Anchorable
	AnchoringService.update_stability(target, config, 0.01)
	return AnchoringService.anchor(_actor, _hammer, target)


func _aim(target: Entity) -> bool:
	var body: RigidBody3D = GrabService.physical_body(target)
	_ray.position = Vector3(body.global_position.x, body.global_position.y, 0)
	_ray.target_position = Vector3(0, 0, -3)
	_interactor.target = target
	_ray.force_raycast_update()
	return InteractionTargetingService.find_target(_actor, _interactor) == target


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
