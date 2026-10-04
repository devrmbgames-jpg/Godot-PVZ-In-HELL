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

## Removing and reattaching manual footsteps releases old playback and keeps the pool usable.
func test_removed_footsteps_release_audio_and_can_play_after_reattachment() -> void:
	for spatial: bool in [false, true]:
		var footsteps: CharacterFootstepper = CharacterFootstepper.new()
		footsteps.manual_footstep = true
		footsteps.manual_jump = true
		footsteps.manual_land = true
		footsteps.material_aware_enabled = false
		footsteps.audio_is_3d = spatial
		footsteps.default_sound_profile = FootstepperSoundProfile.new()
		_root.add_child(footsteps)
		footsteps.play_footstep()
		assert_eq(_voices(footsteps), 1)

		_root.remove_child(footsteps)
		assert_eq(_voices(footsteps), 0, "Removed characters must release active playback")
		for audio_node: Node in footsteps.get_children():
			if audio_node is AudioStreamPlayer3D:
				assert_null((audio_node as AudioStreamPlayer3D).stream)
			elif audio_node is AudioStreamPlayer:
				assert_null((audio_node as AudioStreamPlayer).stream)

		_root.add_child(footsteps)
		footsteps.play_footstep()
		assert_eq(_voices(footsteps), 1, "All pooled voices remain available after reattachment")
		footsteps.free()


func test_grounded_motion_plays_manual_audio_and_bobs_only_camera_then_returns_neutral() -> void:
	var footsteps: Footstepper = _feedback.get_node("Footstepper") as Footstepper
	assert_not_null(footsteps.current_sound_profile.sound_footstep)
	assert_eq(_voices(footsteps), 0)
	var head_pose: Transform3D = _head.transform
	var body: RigidBody3D = _actor as Node as RigidBody3D
	body.position = Vector3(0, 0, -1.4)
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


func test_normal_cadence_and_camera_share_phase_even_when_audio_is_muted() -> void:
	var footsteps: Footstepper = _feedback.get_node("Footstepper") as Footstepper
	_feedback.bob_response = 10000.0
	(_actor as Node as Node3D).position.z -= 0.7
	_feedback._physics_process(0.1)
	assert_eq(_voices(footsteps), 0, "Обычный шаг ещё не закончился")
	(_actor as Node as Node3D).position.z -= 0.7
	_feedback._physics_process(0.1)
	assert_eq(_voices(footsteps), 1)
	assert_almost_eq(_camera.position.y, -_feedback.bob_amplitude.y, 0.00001, "Звук на нижней точке камеры")
	_feedback.footsteps_enabled = false
	(_actor as Node as Node3D).position.z -= 1.4
	_feedback._physics_process(0.2)
	assert_almost_eq(_camera.position.y, _feedback.bob_amplitude.y, 0.00001, "Отключение звука не меняет фазу")


func test_player_belt_lowers_without_camera_pitch_and_returns_to_authored_pose() -> void:
	var actor: E_PhysicalCharacter = (load("res://content/entities/characters/character_body_player.tscn") as PackedScene).instantiate() as E_PhysicalCharacter
	_root.add_child(actor as Node)
	_world.add_entity(actor, null, false)
	assert_eq(actor.crouch_mounts.size(), 2)
	var mount: Node3D = actor.crouch_mounts[0]
	var standing: Vector3 = mount.position
	var crouch: C_Crouch = actor.get_component(C_Crouch) as C_Crouch
	var system: S_CrouchPresentation = S_CrouchPresentation.new()
	crouch.active = true
	actor.head_axis_x.rotation.x = 0.5
	system.process([actor], [[crouch]], 1.0)
	assert_lt(mount.position.y, standing.y - 0.5)
	assert_gt(mount.position.y, 0.1, "Пояс не пересекает пол")
	assert_eq(mount.position.x, standing.x)
	assert_true(mount.rotation.is_zero_approx(), "Pitch камеры не вращает пояс")
	crouch.active = false
	system.process([actor], [[crouch]], 1.0)
	assert_true(mount.position.is_equal_approx(standing))
	system.free()
