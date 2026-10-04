extends Node
## Реальная геометрия восьми площадок main_level: наведение, размещение и повторный захват.

const MAIN_LEVEL: PackedScene = preload("res://content/scenes/main_level.tscn")
const PACKAGE: PackedScene = preload("res://content/entities/packages/package_a.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node3D = MAIN_LEVEL.instantiate() as Node3D
	level.set("autosave_path", "")
	add_child(level)
	level.set_physics_process(false)
	await get_tree().physics_frame
	var actor: E_PhysicalCharacter = level.get_node("Entityes/Player") as E_PhysicalCharacter
	var actor_body: Node3D = actor as Node as Node3D
	actor_body.set_physics_process(false)

	var parcel: Entity = PACKAGE.instantiate() as Entity
	ECS.world.add_entity(parcel)
	var body: RigidBody3D = GrabService.physical_body(parcel)
	body.gravity_scale = 0.0
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	for index: int in range(1, 9):
		var suffix: String = str(index) if index > 1 else ""
		var area: E_PlacementArea = level.get_node("Entityes/CarryPlacement" + suffix) as E_PlacementArea
		actor_body.global_position = area.anchor.global_position + Vector3(1.4, -0.6, 0)
		actor.head_axis_x.look_at((area as Node as Node3D).global_position, Vector3.UP)
		actor_body.reset_physics_interpolation()
		body.global_transform = Transform3D(Basis.IDENTITY, area.anchor.global_position + Vector3(1.0, 0.6, 0))
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		var grip: R_HeldBy = R_HeldBy.new()
		grip.slot = C_Grabbable.HoldSlot.CARRY
		parcel.add_relationship(Relationship.new(grip, actor))
		await get_tree().physics_frame
		await get_tree().process_frame
		body.global_transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.3, 0)), area.anchor.global_position + Vector3(1.0, 0.6, 0))
		actor.interaction_ray_cast.look_at(area.anchor.global_position, Vector3.UP)
		actor.interaction_ray_cast.force_update_transform()
		interactor.target = InteractionTargetingService.find_target(actor, interactor)
		if interactor.target != area:
			print("Placement target failed: index=", index, " collider=", actor.interaction_ray_cast.get_collider(), " ray=", actor.interaction_ray_cast.global_position, " direction=", -actor.interaction_ray_cast.global_basis.z, " anchor=", area.anchor.global_position)
		assert(interactor.target == area, "Carry volume must be targetable above the thin pad")
		var choice: InteractionActionChoice = InteractionActionResolver.resolve(actor, DEF_InteractionAction.Slot.INTERACT)
		assert(choice != null and choice.action is DEF_CarryPlacementAction, "Free main-level shelf must offer placement")
		assert(choice.action.caption == "Поставить")
		assert(choice.action.complete(actor, choice.source, choice.target))
		assert(GrabService.held_object(actor) == null)
		assert(body.global_transform.is_equal_approx(area.anchor.global_transform))
		await get_tree().physics_frame
		await get_tree().process_frame
		actor.interaction_ray_cast.look_at(body.global_position + Vector3.UP * 0.2, Vector3.UP)
		assert(InteractionTargetingService.find_target(actor, interactor) == parcel, "Empty-handed retrieval must ignore Carry volume")
		assert(GrabService.can_pickup(actor, parcel, C_Grabbable.HoldSlot.CARRY), "Placed parcel remains grabbable")
		body.global_position = Vector3(0, 3, 0)
		await get_tree().physics_frame
	level.free()
	print("R26 customer handoff placement smoke PASS")
	get_tree().quit()
