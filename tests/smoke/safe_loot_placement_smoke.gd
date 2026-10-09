extends Node
## Два процесса полного района: заблокированный дроп коробки/NPC, удаление источников и восстановление остатка.

const SAVE_PATH: String = "user://safe_loot_placement_smoke.pvzh"
const ARENA: Vector3 = Vector3(100, 0, 100)
const MAX_RECEIVING_FRAMES: int = 900
const MAX_RETRY_STEPS: int = 8

var _failed: bool = false

#region Полный мир и физические препятствия
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup()
	var level: Node3D = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	level.set("autosave_path", "")
	add_child(level)
	_solid(Vector3(30, 0.2, 30), ARENA + Vector3(0, -0.1, 0))
	if restoring:
		level.set_physics_process(false)
		var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
		_check(WorldSnapshotService.valid(snapshot, level), "whole district save is valid")
		_check(WorldSnapshotService.restore(snapshot, level), "whole district restores in a new process")
		if not _failed:
			await _release_restored()
		_cleanup()
	else:
		for frame: int in MAX_RECEIVING_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowQueries.current().visits.size() == 5:
				break
		level.set_physics_process(false)
		_check(CustomerFlowQueries.current().visits.size() == 5, "real morning batch arrived")
		if not _failed:
			await _blocked_sources(level)
	print("Safe loot smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _solid(size: Vector3, position: Vector3) -> void:
	var solid: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	solid.add_child(collision)
	solid.position = position
	add_child(solid)

func _blocked_sources(level: Node3D) -> void:
	_solid(Vector3(16, 8, 16), ARENA + Vector3(0, 4, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var visit: CustomerVisit = CustomerFlowQueries.current().visits[0]
	var parcel: E_Package = PackageQueries.find_live_package(visit.package_id) as E_Package
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.freeze = true
	body.global_position = ARENA + Vector3.UP
	(parcel.get_component(C_PackageState) as C_PackageState).opening = C_PackageState.Opening.OPENED
	var player: Entity = level.get_node("Entityes/Player") as Entity
	var queue: C_LootDrops = LootDropService.current()
	var previous: int = queue.pending.size()
	var quantity: int = parcel.package_definition.content_quantity
	_check(PackageContentsService.release(parcel, player).is_empty(), "blocked real box creates no intersecting contents")
	_check(queue.pending.size() == previous + quantity, "real box records its fixed remainder")
	_check(PackageContentsService.release(parcel, player).is_empty(), "repeated unpack is safe")
	ECS.world.remove_entity(parcel)
	_check(visit.declaration == CustomerVisit.Declaration.NONE, "removing shell never declares parcel LOST")

	var npc: E_NpcCharacter = (load("res://content/domains/commerce/entities/trader.tscn") as PackedScene).instantiate() as E_NpcCharacter
	(npc as Node as RigidBody3D).freeze = true
	(npc as Node as Node3D).position = ARENA + Vector3.UP
	level.add_child(npc)
	EntityCompositionFixture.register(ECS.world, npc, false)
	var remains: C_NpcRemains = npc.get_component(C_NpcRemains) as C_NpcRemains
	remains.definition = remains.definition.duplicate() as DEF_NpcRemains
	remains.definition.loot_chance = 1.0
	var request: DamageRequest = DamageRequest.new()
	request.target = npc
	request.source = player
	request.instigator = player
	request.amount = 10000.0
	_check(DamageRequestService.submit(request), "normal damage pipeline killed physical NPC")
	_check(remains.released, "NPC batch fixed once")
	_check(queue.pending.size() == previous + quantity + remains.definition.meat_piece_count + 1, "NPC and parcel remainders coexist")
	NpcRemainsService.release(npc)
	ECS.world.remove_entity(npc)
	_check(queue.pending.size() == previous + quantity + 4, "source removal and duplicate release preserve same manifest")
	var snapshot: Dictionary = WorldSnapshotService.capture(level, 1)
	_check(WorldSnapshotService.valid(snapshot, level), "full snapshot includes absent sources and pending items")
	_check(AutosaveStore.write(snapshot, SAVE_PATH) == OK, "pending whole district written to disk")
#endregion

#region Возобновление очереди после загрузки
func _release_restored() -> void:
	var queue: C_LootDrops = LootDropService.current()
	_check(not queue.pending.is_empty(), "pending items survived actual process exit")
	_check(queue.reservations.is_empty() and queue.reservation_frame == -1, "derived physical reservations rebuilt after restore")
	var ids: Array[String] = []
	for record: PendingLootDrop in queue.pending:
		ids.append(record.drop_id)
	for step: int in MAX_RETRY_STEPS:
		await get_tree().physics_frame
		await get_tree().physics_frame
		var before: int = queue.pending.size()
		GameTimeFixture.gameplay(ECS.world, queue.placement.retry_seconds)
		_check(before - queue.pending.size() <= queue.placement.retry_budget, "one retry respects item budget")
		if queue.pending.is_empty():
			break
	_check(queue.pending.is_empty(), "free space released complete persisted remainder")
	var found: Dictionary[String, bool] = {}
	for entity: Entity in ECS.world.entities:
		if entity.id in ids:
			_check(not found.has(entity.id), "one physical instance for each fixed ID")
			found[entity.id] = true
			_check((entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == entity.id, "physical key equals planned ID")
	_check(found.size() == ids.size(), "all intended loot recreated exactly once")
	GameTimeFixture.gameplay(ECS.world, queue.placement.retry_seconds)
	_check(queue.pending.is_empty(), "repeat never regenerates consumed manifest")
	var cycle: C_DayCycle = DayPhaseQueries.current()
	_check(cycle.day_index == 1 and cycle.phase == C_DayCycle.Phase.MORNING, "normal day state survives loot restart")

func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Safe loot smoke: " + message)
#endregion
