extends Node
## Узкий сценарий связей primitive_test_level: разрушение дверей, вскрытие и опора выпавшей полки.

const FRAME_DELTA: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 180

var _level: Node


func _ready() -> void:
	_run.call_deferred()


## На primitive_test_level проверяет разрушение замка/полотна и реальные выпавшие тела.
func _run() -> void:
	_level = (load("res://content/scenes/primitive_test_level.tscn") as PackedScene).instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	var actor: E_PhysicalCharacter = _level.get_node("Entityes/Player") as E_PhysicalCharacter
	(actor as Node).set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var padlock: E_Door = _level.get_node("Entityes/Doors/PadlockedDoor") as E_Door
	var leaf: E_Door = _level.get_node("Entityes/Doors/BreakableDoor") as E_Door
	assert(not OpenableService.can_request(actor, padlock, OpenableService.Operation.OPEN))
	assert(not OpenableService.can_request(actor, padlock, OpenableService.Operation.UNLOCK))
	assert(CombatService.hit(actor, actor, padlock, 100.0))
	assert(OpenableService.request(actor, padlock, OpenableService.Operation.OPEN))
	assert(not (padlock.door_root.get_node("Padlock") as Node3D).visible)
	assert(padlock.door_root.visible)
	assert(CombatService.hit(actor, actor, leaf, 100.0))
	assert(leaf.door_root.collision_layer == 0)
	assert((leaf as Node as CollisionObject3D).collision_layer == 0)

	var before_count: int = ECS.world.query.with_all([C_InventoryItem]).execute().size()
	for parcel_name: String in ["UnpackSmallShelf", "UnpackMedkits", "UnpackBread"]:
		var parcel: E_Package = _level.get_node("Entityes/Props/" + parcel_name) as E_Package
		(actor as Node as Node3D).global_position = (parcel as Node as Node3D).global_position + Vector3(0, 0, 1.8)
		var ray: RayCast3D = actor.interaction_ray_cast
		ray.look_at((parcel as Node as Node3D).global_position)
		(actor.get_component(C_Interactor) as C_Interactor).target = parcel
		await get_tree().physics_frame
		assert(PackageOpening.request_open(actor, parcel).status == PackageOpenResult.Status.COMMITTED)
		assert((parcel.get_component(C_PackageContents) as C_PackageContents).released)
		assert(PackageOpening.request_open(actor, parcel).status == PackageOpenResult.Status.REJECTED)
	assert(ECS.world.query.with_all([C_InventoryItem]).execute().size() == before_count + 10)

	var shelf: Entity = null
	for candidate: Entity in ECS.world.query.with_all([C_Anchorable]).execute():
		if candidate.scene_file_path == "res://content/domains/interaction/entities/small_shelf.tscn":
			shelf = candidate
	assert(shelf != null)
	var body: RigidBody3D = shelf as Node as RigidBody3D
	for frame: int in SETTLE_FRAMES:
		ECS.world.process(FRAME_DELTA, "Interaction")
		await get_tree().physics_frame
	assert(body.global_position.y > 1.4 and body.global_position.y < 1.7, "Unpacked shelf rests on the actual map floor")
	ECS.world.purge(false)
	_level.free()
	ECS.world = null
	await get_tree().process_frame
	print("Doors contents actual primitive wiring physical unpack support smoke PASS")
	get_tree().quit.call_deferred()
