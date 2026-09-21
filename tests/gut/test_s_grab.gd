extends GutTest


## Headless DisplayServer cannot capture the cursor. Replace only this OS boundary.
class CapturedInput extends S_PlayerInput:
	func _accepts_input() -> bool:
		return true


	func feed_event(event: InputEvent) -> void:
		_unhandled_input(event)


var grab_world: World
var holder_entity: Entity
var box_entity: Entity
var holder_body: RigidBody3D
var box_body: RigidBody3D
var input_state: C_Controller
var grab_control: C_GrabControl
var carry_load: C_CarryLoad


#region Fixture
func before_each() -> void:
	grab_world = World.new()
	add_child(grab_world)
	ECS.world = grab_world
	var observer: O_GrabLifecycle = O_GrabLifecycle.new()
	grab_world.add_observer(observer)
	holder_entity = make_holder(Vector3.ZERO)
	box_entity = make_box(Vector3(0.0, 1.0, -1.5))
	holder_body = holder_entity as Node as RigidBody3D
	box_body = box_entity as Node as RigidBody3D
	input_state = holder_entity.get_component(C_Controller) as C_Controller
	grab_control = holder_entity.get_component(C_GrabControl) as C_GrabControl
	carry_load = holder_entity.get_component(C_CarryLoad) as C_CarryLoad
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	interactor.target = box_entity


func after_each() -> void:
	var remaining: Array[Entity] = grab_world.entities.duplicate()
	for actor: Entity in remaining:
		if is_instance_valid(actor):
			S_Grab.entity_unavailable(actor)
	grab_world.free()
	ECS.world = null


func make_holder(location: Vector3) -> Entity:
	var rigid: RigidBody3D = RigidBody3D.new()
	rigid.set_script(E_RigidBodyCharacter)
	rigid.position = location
	rigid.freeze = true
	var actor: Entity = rigid as Node as Entity
	var origin: Marker3D = Marker3D.new()
	origin.position.y = 1.0
	rigid.add_child(origin)
	var interaction_ray: RayCast3D = RayCast3D.new()
	interaction_ray.position.y = 1.0
	interaction_ray.target_position = Vector3(0.0, 0.0, -3.0)
	interaction_ray.enabled = true
	rigid.add_child(interaction_ray)
	actor.set("interaction_ray_cast", interaction_ray)
	actor.set("hold_anchor", origin)
	actor.component_resources = [
		C_Controller.new(),
		C_Interactor.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
	]
	grab_world.add_entity(actor)
	return actor


func make_box(location: Vector3) -> Entity:
	var rigid: RigidBody3D = RigidBody3D.new()
	rigid.set_script(E_Grabbable)
	rigid.position = location
	rigid.gravity_scale = 0.0
	rigid.mass = 5.0
	rigid.continuous_cd = true
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape_resource: BoxShape3D = BoxShape3D.new()
	shape_resource.size = Vector3.ONE * 0.6
	shape_node.shape = shape_resource
	rigid.add_child(shape_node)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "BoxMesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE * 0.6
	mesh_instance.mesh = box_mesh
	rigid.add_child(mesh_instance)
	var actor: Entity = rigid as Node as Entity
	var config: C_Grabbable = C_Grabbable.new()
	config.movement_speed_multiplier = 0.6
	config.movement_acceleration_multiplier = 0.5
	actor.component_resources = [C_Interactable.new(), config]
	grab_world.add_entity(actor)
	return actor
#endregion


#region Gameplay transitions
func test_interact_picks_up_and_releases_with_load_and_collision_cleanup() -> void:
	input_state.interact_pressed = true
	S_Grab.handle_input(holder_entity)
	assert_eq(S_Grab.held_object(holder_entity), box_entity)
	assert_true(carry_load.active)
	assert_eq(carry_load.speed_multiplier, 0.6)
	assert_true(box_body.get_collision_exceptions().has(holder_body))
	assert_false(box_body.freeze)
	S_Grab.handle_input(holder_entity)
	assert_null(S_Grab.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_eq(carry_load.speed_multiplier, 1.0)
	assert_false(box_body.get_collision_exceptions().has(holder_body))


func test_release_preserves_linear_and_angular_inertia() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	box_body.linear_velocity = Vector3(2.0, 3.0, 4.0)
	box_body.angular_velocity = Vector3(0.0, 2.0, 1.0)
	S_Grab.release(holder_entity, box_entity)
	assert_eq(box_body.linear_velocity, Vector3(2.0, 3.0, 4.0))
	assert_eq(box_body.angular_velocity, Vector3(0.0, 2.0, 1.0))


func test_primary_throws_after_releasing_ownership() -> void:
	for physics_tick: int in 2:
		await get_tree().physics_frame
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	input_state.action_main_pressed = true
	input_state.direction_look = Vector3.FORWARD
	S_Grab.handle_input(holder_entity)
	assert_null(S_Grab.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_false(box_body.get_collision_exceptions().has(holder_body))
	for physics_tick: int in 2:
		await get_tree().physics_frame
	assert_lt(box_body.linear_velocity.z, -9.5)


func test_free_primary_and_secondary_do_not_acquire_object() -> void:
	input_state.action_main_pressed = true
	input_state.action_second_held = true
	S_Grab.handle_input(holder_entity)
	assert_null(S_Grab.held_relationship(box_entity))
	assert_false(grab_control.rotation_active)
	assert_eq(box_body.linear_velocity, Vector3.ZERO)


func test_rotation_uses_offset_and_preserves_input_and_look() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	input_state.action_second_held = true
	input_state.look_delta = Vector2(30.0, 20.0)
	var initial_look: Vector3 = input_state.direction_look
	var initial_basis: Basis = box_body.basis
	S_Grab.handle_input(holder_entity)
	var grip: C_HeldBy = S_Grab.held_relationship(box_entity).relation as C_HeldBy
	assert_true(grab_control.rotation_active)
	assert_false(grip.rotation_offset.is_equal_approx(Quaternion.IDENTITY))
	assert_eq(input_state.look_delta, Vector2(30.0, 20.0))
	assert_eq(input_state.direction_look, initial_look)
	assert_eq(box_body.basis, initial_basis)
	input_state.action_second_held = false
	S_Grab.handle_input(holder_entity)
	assert_false(grab_control.rotation_active)


func test_holder_capacity_and_exclusive_ownership() -> void:
	var other_box: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var other_holder: Entity = make_holder(Vector3(1.0, 0.0, 0.0))
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	assert_false(S_Grab.try_pickup(holder_entity, other_box))
	assert_false(S_Grab.try_pickup(other_holder, box_entity))
	assert_eq(box_entity.relationships.size(), 1)


func test_external_relationship_removal_restores_runtime_state() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	grab_control.rotation_active = true
	box_entity.remove_relationship(S_Grab.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_null(grab_control.held_object)
	assert_false(box_body.get_collision_exceptions().has(holder_body))


func test_external_relationship_addition_applies_lifecycle() -> void:
	box_entity.add_relationship(Relationship.new(C_HeldBy.new(), holder_entity))
	assert_eq(S_Grab.held_object(holder_entity), box_entity)
	assert_true(carry_load.active)
	S_Grab.release(holder_entity, box_entity)
	assert_false(carry_load.active)


func test_world_removal_of_held_entity_cleans_up() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	grab_control.rotation_active = true
	grab_world.remove_entity(box_entity)
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_null(grab_control.held_object)


func test_deleted_object_cleans_up_holder() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	grab_control.rotation_active = true
	box_entity.queue_free()
	await get_tree().process_frame
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_null(grab_control.held_object)


func test_deleted_holder_releases_object() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	holder_entity.queue_free()
	await get_tree().process_frame
	assert_null(S_Grab.held_relationship(box_entity))
	assert_true(box_body.get_collision_exceptions().is_empty())


func test_disabled_holder_releases_object() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	grab_world.disable_entity(holder_entity)
	assert_null(S_Grab.held_relationship(box_entity))
	assert_false(carry_load.active)


func test_disabled_or_distant_target_is_rejected() -> void:
	var interactable: C_Interactable = box_entity.get_component(C_Interactable) as C_Interactable
	interactable.enabled = false
	assert_false(S_Grab.try_pickup(holder_entity, box_entity))
	interactable.enabled = true
	box_body.position.z = -20.0
	for physics_tick: int in 2:
		await get_tree().physics_frame
	assert_false(S_Grab.try_pickup(holder_entity, box_entity))


func test_raycast_selects_and_highlights_only_the_current_target() -> void:
	for physics_tick: int in 2:
		await get_tree().physics_frame
	var targeting: S_InteractionTargeting = S_InteractionTargeting.new()
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var mesh_instance: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	var previous_overlay: StandardMaterial3D = StandardMaterial3D.new()
	mesh_instance.material_overlay = previous_overlay
	interactor.target = null
	targeting.process([holder_entity], [[interactor]], 0.0)
	assert_eq(interactor.target, box_entity)
	assert_not_null(mesh_instance.material_overlay)
	assert_ne(mesh_instance.material_overlay, previous_overlay)
	var interaction_ray: RayCast3D = S_Grab.interaction_raycast(holder_entity)
	interaction_ray.rotation.y = PI
	targeting.process([holder_entity], [[interactor]], 0.0)
	assert_null(interactor.target)
	assert_eq(mesh_instance.material_overlay, previous_overlay)
	targeting.free()


func test_carry_modifiers_leave_base_motion_unchanged() -> void:
	var motion: C_Motion = C_Motion.new()
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	assert_almost_eq(S_Motion.effective_speed(motion, carry_load), 3.6, 0.001)
	assert_eq(S_Motion.effective_acceleration(motion.ground_acceleration, carry_load), 12.5)
	assert_eq(motion.max_speed, 6.0)
	assert_eq(motion.ground_acceleration, 25.0)
	S_Grab.release(holder_entity, box_entity)
	assert_eq(S_Motion.effective_speed(motion, carry_load), 6.0)
#endregion


#region Solver math
func test_position_force_compensates_gravity_and_is_bounded() -> void:
	var config: C_Grabbable = C_Grabbable.new()
	var gravity: Vector3 = Vector3(0.0, -10.0, 0.0)
	assert_eq(
		S_Grab.position_force(Vector3.ZERO, Vector3.ZERO, gravity, 5.0, config),
		Vector3(0.0, 50.0, 0.0),
	)
	var force: Vector3 = S_Grab.position_force(
		Vector3.ONE * 100.0,
		Vector3.ZERO,
		gravity,
		80.0,
		config,
	)
	assert_almost_eq(force.length(), config.max_hold_force, 0.001)


func test_rotation_shortest_arc_and_damping() -> void:
	var config: C_Grabbable = C_Grabbable.new()
	assert_eq(
		S_Grab.rotation_acceleration(
			Quaternion.IDENTITY,
			-Quaternion.IDENTITY,
			Vector3.ZERO,
			config,
		),
		Vector3.ZERO,
	)
	var torque: Vector3 = S_Grab.rotation_acceleration(
		Quaternion.IDENTITY,
		Quaternion.IDENTITY,
		Vector3.UP,
		config,
	)
	assert_eq(torque, -Vector3.UP * config.rotation_damping)
	var offset: Quaternion = Quaternion.IDENTITY
	for step_index: int in 1000:
		offset = S_Grab.rotated_offset(offset, Vector2(4.0, 3.0))
	assert_almost_eq(offset.length(), 1.0, 0.00001)


func test_throw_impulse_preserves_velocity_semantics_for_mass_profiles() -> void:
	assert_eq(S_Grab.throw_impulse(Vector3.FORWARD, 10.0, 5.0), Vector3(0.0, 0.0, -50.0))
	assert_eq(S_Grab.throw_impulse(Vector3.FORWARD, 3.0, 80.0), Vector3(0.0, 0.0, -240.0))
#endregion


#region Actual physics
func test_solver_moves_dynamic_box_to_anchor_without_teleporting() -> void:
	box_body.gravity_scale = 1.0
	var initial_position: Vector3 = box_body.global_position
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	assert_eq(box_body.global_position, initial_position)
	for physics_tick: int in 100:
		await get_tree().physics_frame
	assert_almost_eq(box_body.global_position.z, -1.75, 0.1)
	assert_almost_eq(box_body.global_position.y, 1.0, 0.1)
	assert_not_null(S_Grab.held_relationship(box_entity))


func test_teleport_breaks_grip_and_restores_carry_state() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	holder_body.position.x = 20.0
	for physics_tick: int in 3:
		await get_tree().physics_frame
	assert_null(S_Grab.held_relationship(box_entity))
	assert_false(carry_load.active)


func test_wall_occludes_targeting_and_pickup() -> void:
	var wall: StaticBody3D = make_wall(Vector3(0.0, 1.0, -0.75))
	for physics_tick: int in 2:
		await get_tree().physics_frame
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	assert_null(S_InteractionTargeting.find_target(holder_entity, interactor))
	assert_false(S_Grab.try_pickup(holder_entity, box_entity))
	wall.free()


func test_held_box_collides_with_wall_instead_of_snapping_through() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	var wall: StaticBody3D = make_wall(Vector3(0.0, 1.0, -2.5))
	var grip: C_HeldBy = S_Grab.held_relationship(box_entity).relation as C_HeldBy
	grip.hold_distance = 3.3
	for physics_tick: int in 100:
		await get_tree().physics_frame
	assert_gt(box_body.global_position.z, -2.3)
	assert_not_null(S_Grab.held_relationship(box_entity))
	wall.free()


func make_wall(location: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = location
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5.0, 5.0, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	grab_world.add_child(wall)
	return wall
#endregion


#region Input priority and failure states
func test_player_input_edges_are_consumed_once_on_physics_tick() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var input_system: CapturedInput = CapturedInput.new()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	input_system.feed_event(event)
	var holders: Array[Entity] = [holder_entity]
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	assert_true(input_state.interact_pressed)
	S_Grab.handle_input(holder_entity)
	assert_eq(S_Grab.held_object(holder_entity), box_entity)
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	assert_false(input_state.interact_pressed)
	S_Grab.handle_input(holder_entity)
	assert_eq(S_Grab.held_object(holder_entity), box_entity)
	input_system.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_rotation_priority_does_not_accumulate_camera_input() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	var input_system: S_PlayerInput = CapturedInput.new()
	var holders: Array[Entity] = [holder_entity]
	Input.action_press(&"action_secondary")
	input_system.look_mouse = Vector2(40.0, 20.0)
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	S_Grab.handle_input(holder_entity)
	assert_true(grab_control.rotation_active)
	assert_eq(input_state.direction_look, Vector3.FORWARD)
	assert_eq(input_state.look_delta, Vector2(40.0, 20.0))
	Input.action_release(&"action_secondary")
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	S_Grab.handle_input(holder_entity)
	assert_false(grab_control.rotation_active)
	assert_eq(input_state.direction_look, Vector3.FORWARD)
	input_system.look_mouse = Vector2(10.0, 0.0)
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	assert_ne(input_state.direction_look, Vector3.FORWARD)
	input_system.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_freezing_held_body_releases_on_next_control_tick() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	box_body.freeze = true
	S_Grab.handle_input(holder_entity)
	assert_null(S_Grab.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)


func test_death_releases_hold_without_requiring_input() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	var health: C_Health = C_Health.new()
	holder_entity.add_component(health)
	health.value = 0.0
	S_Grab.handle_input(holder_entity)
	assert_null(S_Grab.held_relationship(box_entity))
	assert_false(carry_load.active)


func test_solver_rotates_body_through_torque() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	var grip: C_HeldBy = S_Grab.held_relationship(box_entity).relation as C_HeldBy
	grip.rotation_offset = Quaternion(Vector3.UP, PI * 0.5)
	for physics_tick: int in 100:
		await get_tree().physics_frame
	var result_rotation: Quaternion = box_body.global_basis.get_rotation_quaternion()
	assert_lt(result_rotation.angle_to(grip.rotation_offset), 0.15)
	assert_not_null(S_Grab.held_relationship(box_entity))
#endregion


#region External ownership invariants
func test_external_second_holder_is_rejected_without_changing_original_grip() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	var other_holder: Entity = make_holder(Vector3(1.0, 0.0, 0.0))
	box_entity.add_relationship(Relationship.new(C_HeldBy.new(), other_holder))
	assert_eq(box_entity.relationships.size(), 1)
	assert_eq(S_Grab.held_object(holder_entity), box_entity)
	assert_null(S_Grab.held_object(other_holder))
	assert_false(box_body.can_sleep)
	assert_true(box_body.get_collision_exceptions().has(holder_body))


func test_external_duplicate_relation_cannot_leave_lifecycle_effects() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	box_entity.add_relationship(Relationship.new(C_HeldBy.new(), holder_entity))
	assert_lte(box_entity.relationships.size(), 1)
	# GECS removes matching pairs, so rejecting an identical duplicate releases both.
	if S_Grab.held_relationship(box_entity) == null:
		assert_false(carry_load.active)
		assert_false(box_body.get_collision_exceptions().has(holder_body))
		assert_true(box_body.can_sleep)


func test_world_removal_of_holder_releases_source_relationship() -> void:
	assert_true(S_Grab.try_pickup(holder_entity, box_entity))
	grab_world.remove_entity(holder_entity)
	assert_null(S_Grab.held_relationship(box_entity))
	assert_true(box_body.get_collision_exceptions().is_empty())
#endregion
