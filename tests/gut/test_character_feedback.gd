extends GutTest
## Manual addon audio under both native bodies; presentation cannot move gameplay head/rays.

var _root: Node3D
var _world: World
var _actor: E_RigidBodyCharacter
var _feedback: CharacterFeedback
var _head: Node3D
var _camera: Camera3D


func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/entities/characters/e_rigid_body_character.gd"))
	_actor = body as Node as E_RigidBodyCharacter
	var motion: C_Motion = C_Motion.new()
	motion.is_on_floor = true
	var controller: C_Controller = C_Controller.new()
	controller.direction_motion = Vector3.FORWARD
	_actor.component_resources = [motion, controller, C_GrabControl.new()]
	_head = Node3D.new()
	_head.name = "Head"
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_head.add_child(_camera)
	body.add_child(_head)
	_actor.camera_root = _head
	_feedback = (load("res://content/ui/character_feedback.tscn") as PackedScene).instantiate() as CharacterFeedback
	_feedback.camera_path = NodePath("Head/Camera")
	body.add_child(_feedback)
	_root.add_child(body)
	_world.add_entity(_actor, null, false)


func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null


func _voices(footsteps: Footstepper) -> int:
	var count: int = 0
	for child: Node in footsteps.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			count += 1
		if child is AudioStreamPlayer3D and (child as AudioStreamPlayer3D).playing:
			count += 1
	return count


func test_grounded_motion_plays_manual_audio_and_bobs_only_camera_then_returns_neutral() -> void:
	var footsteps: Footstepper = _feedback.get_node("Footstepper") as Footstepper
	assert_not_null(footsteps.current_sound_profile.sound_footstep)
	assert_eq(_voices(footsteps), 0)
	var head_pose: Transform3D = _head.transform
	var body: RigidBody3D = _actor as Node as RigidBody3D
	body.position = Vector3(0, 0, -0.8)
	var physical_pose: Transform3D = body.transform
	_feedback._physics_process(1.0 / 60.0)
	assert_eq(_voices(footsteps), 1)
	assert_true(body.transform.is_equal_approx(physical_pose))
	assert_true(_head.transform.is_equal_approx(head_pose))
	assert_true(_camera.rotation.is_zero_approx())
	assert_gt(_camera.position.length(), 0.0)
	assert_lte(absf(_camera.position.x), _feedback.bob_amplitude.x)
	assert_lte(absf(_camera.position.y), _feedback.bob_amplitude.y)
	_feedback.reduced_motion = true
	for tick: int in 20:
		_feedback._physics_process(0.05)
	assert_lt(_camera.position.length(), 0.00001)
	assert_true(_head.transform.is_equal_approx(head_pose))


func test_air_idle_modal_and_death_do_not_trigger_footsteps() -> void:
	var footsteps: Footstepper = _feedback.get_node("Footstepper") as Footstepper
	var motion: C_Motion = _actor.get_component(C_Motion) as C_Motion
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	motion.is_on_floor = false
	(_actor as Node as Node3D).position.z -= 0.8
	_feedback._physics_process(1.0 / 60.0)
	assert_eq(_voices(footsteps), 0)
	motion.is_on_floor = true
	controller.direction_motion = Vector3.ZERO
	(_actor as Node as Node3D).position.z -= 0.8
	_feedback._physics_process(1.0 / 60.0)
	assert_eq(_voices(footsteps), 0)
	controller.direction_motion = Vector3.FORWARD
	var token: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.MODAL)
	(_actor as Node as Node3D).position.z -= 0.8
	_feedback._physics_process(1.0 / 60.0)
	assert_eq(_voices(footsteps), 0)
	InteractionControlFocus.release(_actor, token)
	_actor.add_component(C_Death.new())
	(_actor as Node as Node3D).position.z -= 0.8
	_feedback._physics_process(1.0 / 60.0)
	assert_eq(_voices(footsteps), 0)
	assert_true(_camera.position.is_zero_approx())


func test_real_customer_prefab_uses_spatial_addon_players_under_rigid_body() -> void:
	var npc: E_Customer = (load("res://content/entities/customers/customer.tscn") as PackedScene).instantiate() as E_Customer
	(npc as Node as RigidBody3D).freeze = true
	_root.add_child(npc)
	_world.add_entity(npc, null, false)
	var footsteps: Footstepper = npc.get_node("CharacterFeedback/Footstepper") as Footstepper
	assert_true(footsteps.is_manual)
	assert_eq(footsteps.get_child_count(), 3)
	for child: Node in footsteps.get_children():
		assert_true(child is AudioStreamPlayer3D)
	assert_not_null(footsteps.current_sound_profile)
	assert_false((npc.get_node("CharacterFeedback") as CharacterFeedback).bob_enabled)
