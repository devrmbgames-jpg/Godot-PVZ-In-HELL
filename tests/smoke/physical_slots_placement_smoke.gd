extends Node
## Bounded real-physics placement transactions; no rendered inspection.

var _world: World
var _actor: Entity
var _area: E_PlacementArea


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_world.add_observer(O_PhysicalSlotLifecycle.new())
	var actor_body: RigidBody3D = RigidBody3D.new()
	actor_body.set_script(E_RigidBodyCharacter)
	actor_body.freeze = true
	_actor = actor_body as Node as Entity

	var ray: RayCast3D = RayCast3D.new()
	ray.position = Vector3(0, 1, 0)
	ray.target_position = Vector3(0, 0, -3)
	actor_body.add_child(ray)
	_actor.set("interaction_ray_cast", ray)
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(1, 1, -1)
	actor_body.add_child(anchor)
	_actor.set("hold_anchor", anchor)

	var interactor: C_Interactor = C_Interactor.new()
	interactor.collision_mask = 31
	_actor.component_resources = [C_Controller.new(), interactor, C_GrabControl.new(), C_CarryLoad.new(), C_Strength.new()]
	_world.add_entity(_actor)
	_area = (load("res://content/entities/props/placement_area.tscn") as PackedScene).instantiate() as E_PlacementArea
	(_area as Node as Node3D).position = Vector3(0, 1, -2)
	_area.anchor.position = Vector3.ZERO
	_world.add_entity(_area)

	var item: Entity = _box(Vector3(1, 1, -1))
	_hold(item)
	await _sync_physics()
	assert(CarryPlacementService.can_place(_actor, _area), "Clear area/path must accept Carry")
	var blocker: StaticBody3D = _blocker(Vector3(0, 1, -2), Vector3.ONE * 0.3)
	await _sync_physics()
	assert(not CarryPlacementService.place(_actor, _area), "Occupied endpoint must reject")
	assert(GrabService.held_object(_actor) == item, "Rejected placement must preserve Carry")
	blocker.position = Vector3(0.5, 1, -1.5)
	await _sync_physics()
	assert(not CarryPlacementService.place(_actor, _area), "Clear endpoint behind a wall must reject")
	assert(GrabService.held_object(_actor) == item)
	blocker.position = Vector3(10, 1, 0)
	await _sync_physics()
	interactor = _actor.get_component(C_Interactor) as C_Interactor
	ray.target_position = Vector3(0, 0, -3)
	anchor.position = Vector3(0, 1, -1)

	var carried_body: RigidBody3D = GrabService.physical_body(item)
	assert(carried_body != null)
	carried_body.global_position = Vector3(0, 1, -1)
	await _sync_physics()
	interactor.target = InteractionTargetingService.find_target(_actor, interactor)
	assert(interactor.target == _area, "Held Carry body must not steal PlacementArea focus")
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT)
	assert(choice != null and choice.action is DEF_CarryPlacementAction)
	assert(choice.action.complete(_actor, choice.source, choice.target))

	var body: RigidBody3D = GrabService.physical_body(item)
	assert(GrabService.held_object(_actor) == null)
	assert(body.global_position.is_equal_approx(_area.anchor.global_position))
	assert(not body.freeze and PhysicalSlotService.relationship(item) == null)
	var second: Entity = _box(Vector3(1, 1, -1))
	_hold(second)
	await _sync_physics()
	assert(not CarryPlacementService.can_place(_actor, _area), "Placed object occupies area physically")
	body.global_position = Vector3(5, 1, 0)
	await _sync_physics()
	assert(CarryPlacementService.can_place(_actor, _area), "Moving it out frees the area without a claim")
	# Rotation safety: obstacle in the swept volume is rejected before release.
	_area.anchor.rotation.y = PI / 2.0
	blocker.position = Vector3(0.5, 1, -1.5)
	await _sync_physics()
	assert(not CarryPlacementService.place(_actor, _area))
	assert(GrabService.held_object(_actor) == second)
	GrabService.release(_actor, second)
	_world.free()
	ECS.world = null
	print("R11.1 physical slots placement smoke PASS")
	get_tree().quit()


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _box(location: Vector3) -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)
	body.position = location
	body.gravity_scale = 0.0
	body.collision_layer = 8
	body.collision_mask = 29
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.2
	collision.shape = shape
	body.add_child(collision)

	var item: Entity = body as Node as Entity
	item.component_resources = [C_Grabbable.new(), C_Interactable.new()]
	_world.add_entity(item)
	return item


func _hold(item: Entity) -> void:
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.CARRY
	item.add_relationship(Relationship.new(grip, _actor))
	assert(GrabService.held_object(_actor) == item)


func _blocker(location: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = location
	body.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body
