extends "res://tests/gut/test_npc_remains.gd"
## Реальное Jolt-пространство, форма лута, ограниченные повторы и постоянный остаток без источника.

const MEAT_SCENE: String = "res://content/entities/inventory/npc_meat_pickup.tscn"

#region Физические проверки
## Дополняет настоящее окружение урона/останков сессионной системой повторов.
func before_each() -> void:
	await super.before_each()
	_world.add_system(S_LootDrops.new())

func _solid(size: Vector3, position: Vector3) -> StaticBody3D:
	var solid: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	solid.add_child(collision)
	solid.position = position
	_root.add_child(solid)
	return solid

func _meat() -> RigidBody3D:
	return (load(MEAT_SCENE) as PackedScene).instantiate() as RigidBody3D

func _solver(body: RigidBody3D) -> ItemPlacementSolver:
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	assert_true(solver.prepare(body))
	return solver

func _policy() -> DEF_ItemPlacement:
	var original: DEF_ItemPlacement = load("res://content/definitions/gameplay/def_item_placement_default.tres") as DEF_ItemPlacement
	var policy: DEF_ItemPlacement = original.duplicate() as DEF_ItemPlacement
	policy.offsets = original.offsets.duplicate()
	return policy

func _find(solver: ItemPlacementSolver, body: RigidBody3D, position: Vector3, policy: DEF_ItemPlacement) -> ItemPlacementSolver.Result:
	return solver.find(_root.get_world_3d().direct_space_state, Transform3D(body.transform.basis, position), policy, [], [body.get_rid()])

## Центр вне двух стен ещё не означает свободную форму; fallback размещает весь предмет вне угла.
func test_corner_uses_full_shape_and_bounded_nearby_fallback() -> void:
	_solid(Vector3(0.2, 4, 10), Vector3(0.1, 2, 0))
	_solid(Vector3(10, 4, 0.2), Vector3(0, 2, 0.1))
	await get_tree().physics_frame
	await get_tree().physics_frame

	var body: RigidBody3D = _meat()
	var result: ItemPlacementSolver.Result = _find(_solver(body), body, Vector3(-0.05, 0.5, -0.05), _policy())
	assert_true(result.available)
	assert_gt(result.attempts, 1)
	assert_lte(result.attempts, 16)
	assert_lt(result.bounds.end.x, 0.0)
	assert_lt(result.bounds.end.z, 0.0)
	assert_almost_eq(result.pose.origin.y, 0.15, 0.01)
	body.free()

## Смещение/поворот коллайдера и поворот корня участвуют в проверке препятствия.
func test_collider_transform_and_disabled_shapes_are_respected() -> void:
	_solid(Vector3(5, 4, 0.2), Vector3(0, 2, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var body: RigidBody3D = _meat()
	body.rotation.y = PI / 2.0
	var collision: CollisionShape3D = body.get_node("Collision") as CollisionShape3D
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.2, 1, 0.2)
	collision.shape = shape
	collision.position.x = 0.8
	collision.rotation.z = PI / 2.0
	var policy: DEF_ItemPlacement = _policy()
	policy.offsets = PackedVector3Array([Vector3.ZERO])
	var solver: ItemPlacementSolver = _solver(body)
	assert_false(_find(solver, body, Vector3(0, 0.5, 0.2), policy).available)

	collision.disabled = true
	assert_false(solver.prepare(body))
	body.free()

## Свободная семнадцатая позиция не проверяется, если первые 16 перекрыты.
func test_candidate_seventeen_is_never_searched() -> void:
	_solid(Vector3(6, 4, 6), Vector3(0, 2, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var body: RigidBody3D = _meat()
	var policy: DEF_ItemPlacement = _policy()
	policy.offsets.resize(17)
	for index: int in 16:
		policy.offsets[index] = Vector3.ZERO
	policy.offsets[16] = Vector3(10, 0, 0)
	var result: ItemPlacementSolver.Result = _find(_solver(body), body, Vector3(0, 0.5, 0), policy)
	assert_false(result.available)
	assert_eq(result.attempts, 16)
	assert_eq((load("res://content/definitions/gameplay/def_item_placement_default.tres") as DEF_ItemPlacement).offsets.size(), 16)
	body.free()

## Узкая опора под центром не поддерживает весь предмет; без пола лут не создаётся.
func test_support_checks_footprint_and_missing_floor() -> void:
	_solid(Vector3(0.1, 0.2, 0.1), Vector3(20, -0.1, 20))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var body: RigidBody3D = _meat()
	var policy: DEF_ItemPlacement = _policy()
	policy.offsets = PackedVector3Array([Vector3.ZERO])
	var solver: ItemPlacementSolver = _solver(body)
	assert_false(_find(solver, body, Vector3(20, 0.5, 20), policy).available)
	assert_false(_find(solver, body, Vector3(30, 0.5, 30), policy).available)
	body.free()

## Предметы смерти в одном кадре получают непересекающиеся резервы и постоянные ID.
func test_batch_reserves_each_shape_before_next_physics_frame() -> void:
	_damage(_npc(false, 1.0), 200.0)
	var queue: C_LootDrops = LootDropService.current()
	assert_eq(_drops().size(), 4)
	assert_true(queue.pending.is_empty())
	assert_eq(queue.reservations.size(), 4)
	for first: int in queue.reservations.size():
		for second: int in range(first + 1, queue.reservations.size()):
			assert_false(queue.reservations[first].intersects(queue.reservations[second]))
	for item: Entity in _drops():
		var identity: C_PersistentIdentity = item.get_component(C_PersistentIdentity) as C_PersistentIdentity
		assert_not_null(identity)
		assert_eq(identity.key, item.id)
#endregion

#region Повторы и согласованный снимок
## Следование эффектов NPC не переходит к мясу; перенос источника предусмотрен только для упаковки.
func test_npc_remains_do_not_inherit_source_hazard_binding() -> void:
	var npc: E_NpcCharacter = _npc()
	var effect: Entity = Entity.new()
	_world.add_entity(effect)
	effect.add_relationship(Relationship.new(R_HazardFollow.new(), npc))
	_damage(npc, 200.0)
	assert_eq(_drops().size(), 3)
	assert_same(HazardFollowService.binding(effect).target, npc)

## Удаление тела и два restore сохраняют ID; освобождённое место создаёт каждый предмет один раз.
func test_pending_survives_source_removal_and_world_round_trip() -> void:
	var blocker: StaticBody3D = _solid(Vector3(6, 4, 6), Vector3(0, 2, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var npc: E_NpcCharacter = _npc(false, 1.0)
	_damage(npc, 200.0)
	var queue: C_LootDrops = LootDropService.current()
	assert_eq(queue.pending.size(), 4)
	assert_true(_drops().is_empty())
	var ids: Array[String] = []
	for record: PendingLootDrop in queue.pending:
		ids.append(record.drop_id)
	var batch_id: String = queue.pending[0].batch_id
	_world.remove_entity(npc)

	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	queue = LootDropService.current()
	assert_eq(queue.pending.size(), 4)
	assert_true(queue.reservations.is_empty())
	assert_eq(queue.reservation_frame, -1)
	assert_eq(queue.retry_remaining, 0.0)
	for index: int in ids.size():
		assert_eq(queue.pending[index].drop_id, ids[index])

	blocker.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_world.process(0.1, "GamePlay")
	assert_true(queue.pending.is_empty())
	assert_eq(_drops().size(), 4)
	for item: Entity in _drops():
		assert_true(item.id in ids)
	_world.process(2.0, "GamePlay")
	assert_eq(_drops().size(), 4)
	var repeated: Array[Entity] = LootDropService.prepare([load(MEAT_SCENE) as PackedScene], true)
	assert_true(LootDropService.enqueue(queue, batch_id, repeated, PendingLootDrop.new()).is_empty())
	assert_eq(_drops().size(), 4)

## Повторы ограничены временем и количеством; сервис также проверяет фазу перед мутацией.
func test_retry_budget_interval_and_night_gate() -> void:
	var queue: C_LootDrops = LootDropService.current()
	queue.placement = _policy()
	queue.placement.initial_budget = 1
	queue.placement.retry_budget = 1
	_damage(_npc(false, 1.0), 200.0)
	assert_eq(_drops().size(), 1)
	assert_eq(queue.pending.size(), 3)
	_world.process(0.5, "GamePlay")
	assert_eq(_drops().size(), 1)
	_world.process(0.5, "GamePlay")
	assert_eq(_drops().size(), 2)
	assert_eq(queue.pending.size(), 2)

	var session: Entity = _world.query.with_all([C_DayCycle]).execute_one()
	(session.get_component(C_DayCycle) as C_DayCycle).phase = C_DayCycle.Phase.NIGHT
	_world.process(100.0, "GamePlay")
	LootDropService.retry(session, queue)
	assert_eq(_drops().size(), 2)
	assert_eq(queue.pending.size(), 2)

## Дубликат ID, неизвестный prefab и нечисловая позиция отклоняются до изменения мира.
func test_malformed_pending_snapshot_is_rejected_before_mutation() -> void:
	_solid(Vector3(6, 4, 6), Vector3(0, 2, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_damage(_npc(false, 1.0), 200.0)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	var invalid: Dictionary = snapshot.duplicate(true)
	var fields: Dictionary = _queue_fields(invalid)
	var pending: Array = fields.pending as Array
	pending.append(pending[0])
	assert_false(WorldSnapshotService.restore(invalid, _root))
	assert_eq(LootDropService.current().pending.size(), 4)
	assert_true(_drops().is_empty())

	invalid = snapshot.duplicate(true)
	fields = _queue_fields(invalid)
	((fields.pending as Array)[0].fields as Dictionary).scene_path = "res://tests/smoke/delivery_completion_smoke.tscn"
	assert_false(WorldSnapshotService.valid(invalid, _root))
	invalid = snapshot.duplicate(true)
	fields = _queue_fields(invalid)
	((fields.pending as Array)[0].fields as Dictionary).origin = Vector3(NAN, 0, 0)
	assert_false(WorldSnapshotService.valid(invalid, _root))
	assert_eq(LootDropService.current().pending.size(), 4)

func _queue_fields(snapshot: Dictionary) -> Dictionary:
	for record: Dictionary in snapshot.entities:
		for component: Dictionary in record.components:
			if SaveDataCodec.component_script(String(component.type)) == C_LootDrops:
				return component.fields as Dictionary
	return {}
#endregion
