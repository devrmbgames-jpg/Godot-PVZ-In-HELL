extends GutTest
## Проверяет разрушение замка/полотна реальным ударом и сохранение результата без повторного создания двери.

var _root: Node3D
var _world: World
var _actor: E_RigidBodyCharacter
var _weapon: Entity


#region Физическое окружение и удар
## Создаёт физического игрока и observers урона/разрушения для реального окна атаки.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_DoorBreakage.new())

	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new()]
	_root.add_child(session)
	session.owner = _root
	FixturePlacedIdentity.assign(_root, session, &"session")
	_world.add_entity(session, null, false)
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/domains/motion/entities/e_rigid_body_character.gd"))
	_actor = body as Node as E_RigidBodyCharacter
	_actor.component_resources = [C_Combat.new(), C_GrabControl.new(), C_Controller.new()]

	var head: Marker3D = Marker3D.new()
	head.position.y = 1.3
	body.add_child(head)
	_actor.head_axis_x = head
	_world.add_entity(_actor)
	_actor.owner = _root
	FixturePlacedIdentity.assign(_root, _actor, &"actor")


## Возвращает отладочный HUD, удаляет World и очищает ECS.world.
func after_each() -> void:
	DebugHudService.set_enabled(true)
	_world.purge(false)
	_root.free()
	ECS.world = null


func _door(path: String) -> E_Door:
	var prefab: PackedScene = load(path) as PackedScene
	var door: E_Door = prefab.instantiate() as E_Door
	(door as Node as Node3D).position = Vector3(-1.22, 0, -1.4)
	_root.add_child(door)
	door.owner = _root
	FixturePlacedIdentity.assign(_root, door, &"door")
	_world.add_entity(door, null, false)
	return door


func _equip(path: String) -> void:
	_weapon = (load(path) as PackedScene).instantiate() as Entity
	_world.add_entity(_weapon)
	var body: RigidBody3D = _weapon as Node as RigidBody3D
	body.freeze = true
	body.position = Vector3(0.5, 1.0, 0)
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	_weapon.add_relationship(Relationship.new(grip, _actor))
	(_actor.get_component(C_GrabControl) as C_GrabControl).held_right = _weapon


func _strike() -> void:
	assert_true(CombatService.start_strike(_actor, _weapon))
	CombatFixture.melee(_actor, 1.0)


#endregion

#region Разрушение физических преград
## Молоток ломает замок, сохраняя физическое полотно и открывание двери.
func test_hammer_breaks_padlock_and_preserves_door_leaf_and_open_action() -> void:
	var door: E_Door = _door("res://content/domains/interaction/entities/padlocked_door.tscn")
	_equip("res://content/domains/combat/entities/hammer.tscn")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var health: C_Health = door.get_component(C_Health) as C_Health
	assert_false(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))
	assert_false(OpenableService.request(_actor, door, OpenableService.Operation.UNLOCK), "Empty access requirement cannot bypass a physical padlock")
	assert_true(CombatGeometry.clear_line(_actor, door, 31))
	_strike()
	assert_gt(health.current, 0.0)
	assert_true((door.get_component(C_Openable) as C_Openable).locked)
	_strike()
	assert_true(health.depleted)
	assert_false((door.get_component(C_Openable) as C_Openable).locked)
	assert_false((door.door_root.get_node("Padlock") as Node3D).visible)
	assert_true(door.door_root.visible)
	assert_gt(door.door_root.collision_layer, 0)
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))

	var status: Label3D = door.get_node("BreakageStatus") as Label3D
	assert_string_contains(status.text, "HP 0/45")
	DebugHudService.set_enabled(false)
	door.sync_destruction_view()
	assert_false(status.visible)
	_strike()
	assert_eq(health.current, 0.0, "Repeated attack cannot repeat terminal depletion")


## Нож разрушает полотно и снимает его физические препятствия для луча.
func test_knife_breaks_leaf_and_removes_all_physical_blockers() -> void:
	var door: E_Door = _door("res://content/domains/interaction/entities/breakable_door.tscn")
	_equip("res://content/domains/combat/entities/utility_blade.tscn")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_actor.head_axis_x.look_at(door.strike_point())
	var point: Vector3 = door.strike_point()
	(_actor as Node as Node3D).global_position = Vector3(point.x, 0, point.z + 1.0)
	_actor.head_axis_x.look_at(point)
	assert_true(CombatGeometry.clear_line(_actor, door, 31))

	var health: C_Health = door.get_component(C_Health) as C_Health
	_strike()
	assert_eq(health.current, 50.0)
	_strike()
	assert_eq(health.current, 10.0)
	_strike()
	assert_true(health.depleted)
	assert_eq((door as Node as CollisionObject3D).collision_layer, 0)
	assert_eq(door.door_root.collision_layer, 0)
	assert_eq(door.door_root.collision_mask, 0)
	assert_false(door.door_root.visible)
	assert_false(OpenableService.can_request(_actor, door, OpenableService.Operation.OPEN))
	await get_tree().physics_frame

	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 1.3, 0), Vector3(0, 1.3, -3), 31, CombatGeometry.exclusions(_actor),
	)
	assert_true(_root.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())


#endregion

#region Сохранение состояния двери
## Snapshot и ночь сохраняют разрушенный замок и возможность открыть дверь.
func test_padlock_depletion_and_unlocked_state_survive_snapshot_and_night() -> void:
	var door: E_Door = _door("res://content/domains/interaction/entities/padlocked_door.tscn")
	var intact: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(CombatService.hit(_actor, _actor, door, 100.0))
	var broken: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(intact, _root))
	door.sync_destruction_view()
	assert_true((door.door_root.get_node("Padlock") as Node3D).visible)
	assert_true((door.get_component(C_Openable) as C_Openable).locked)
	assert_true(WorldSnapshotService.restore(broken, _root))
	door.sync_destruction_view()
	assert_false((door.door_root.get_node("Padlock") as Node3D).visible)
	assert_false((door.get_component(C_Openable) as C_Openable).locked)
	NightResetService.reset()
	assert_true((door.get_component(C_Health) as C_Health).depleted)
	assert_true(OpenableService.can_request(_actor, door, OpenableService.Operation.OPEN))


## Restore меняет состояние одного авторского экземпляра двери, восстанавливая либо отключая столкновения.
func test_broken_leaf_and_intact_physics_restore_without_respawning_authored_door() -> void:
	var door: E_Door = _door("res://content/domains/interaction/entities/breakable_door.tscn")
	var intact: Dictionary = WorldSnapshotService.capture(_root, 2)
	var initial_layer: int = door.door_root.collision_layer
	assert_true(CombatService.hit(_actor, _actor, door, 100.0))
	var broken: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(intact, _root))
	door.sync_destruction_view()
	assert_true(door.door_root.visible)
	assert_eq(door.door_root.collision_layer, initial_layer)
	assert_true(WorldSnapshotService.restore(broken, _root))
	door.sync_destruction_view()
	assert_false(door.door_root.visible)
	assert_eq(door.door_root.collision_layer, 0)
	assert_eq(_world.query.with_all([C_BreakableDoor]).execute().size(), 1)

#endregion
