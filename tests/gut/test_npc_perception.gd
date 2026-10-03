extends GutTest
## Physics-based perception and anonymous hearing, independent of parcel visits.

var _root: Node3D = null
var _world: World = null
var _district: C_District = null
var _observer: E_DistrictNpc = null
var _target: E_DistrictNpc = null
var _profile: DEF_NpcProfile = null
var _wall: StaticBody3D = null

#region Fixtures
## Creates frozen physical actors so engine rays query real collision geometry.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	var district_node: Node3D = Node3D.new()
	district_node.name = "District"
	_root.add_child(district_node)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var session_node: Node = Node.new()
	session_node.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var session: Entity = session_node as Entity
	var component: C_District = C_District.new()
	component.definition = DEF_District.new()
	session.component_resources = [component, C_DayCycle.new()]
	_world.add_entity(session)
	_district = session.get_component(C_District) as C_District
	_profile = DEF_NpcProfile.new()
	_profile.dark_vision_fraction = 1.0
	_profile.schedule = DEF_NpcSchedule.new()
	_observer = _actor(Vector3.ZERO)
	_target = _actor(Vector3(0, 0, -3))
	_wall = StaticBody3D.new()
	_wall.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 3, 0.5)
	collision.shape = box
	_wall.add_child(collision)
	_root.add_child(_wall)
	_wall.position = Vector3(20, 1.5, -1.5)

## Releases all real actors and cache state.
func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		_world.remove_entity(entity)
	_world.purge(false)
	ECS.world = null
	_root.free()
	_root = null

func _actor(world_position: Vector3) -> E_DistrictNpc:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(load("res://content/entities/npc/e_district_npc.gd"))
	var actor: E_DistrictNpc = body as Node as E_DistrictNpc
	actor.component_resources = [C_Health.new(), C_NpcAwareness.new(), C_NpcDecision.new(), C_NpcIntent.new(), C_NpcCombat.new(), C_NpcIdentity.new()]
	body.freeze = true
	body.collision_layer = 2
	body.collision_mask = 31
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	collision.shape = capsule
	collision.position = Vector3.UP * 0.85
	body.add_child(collision)
	_world.add_entity(actor)
	body.global_position = world_position
	return actor

func _synchronize() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
#endregion

#region Visibility
## A real wall hides every point, while a small carried-size box leaves visible body points.
func test_wall_occlusion_and_partial_cover() -> void:
	await _synchronize()
	assert_true(NpcPerceptionService.can_see(_observer, _target, _profile))
	_wall.position = Vector3(0, 1.5, -1.5)
	await _synchronize()
	assert_false(NpcPerceptionService.can_see(_observer, _target, _profile))
	var shape: BoxShape3D = (_wall.get_child(0) as CollisionShape3D).shape as BoxShape3D
	shape.size = Vector3(0.25, 0.3, 0.3)
	await _synchronize()
	assert_true(NpcPerceptionService.can_see(_observer, _target, _profile))

## Ordinary eyes lose distant dark targets; night eyes keep physical sight.
func test_darkness_and_night_vision() -> void:
	_target.place_at(Vector3(0, 0, -8))
	_profile.dark_vision_fraction = 0.1
	await _synchronize()
	assert_false(NpcPerceptionService.can_see(_observer, _target, _profile))
	var night_rule: DEF_NpcTrait = DEF_NpcTrait.new()
	night_rule.kind = DEF_NpcTrait.Kind.DARK_PREDATOR
	_profile.rules.append(night_rule)
	assert_true(NpcPerceptionService.can_see(_observer, _target, _profile))

## Search retains the last sighting rather than copying the target through a wall.
func test_hidden_target_position_never_updates_search_memory() -> void:
	var person: NpcRecord = NpcRecord.new()
	person.profile = _profile
	CombatService.bind_target(_observer, _target)
	await _synchronize()
	NpcPerceptionService.sense(_observer, person, _target, 0.2)
	var awareness: C_NpcAwareness = _observer.get_component(C_NpcAwareness) as C_NpcAwareness
	var confirmed: Vector3 = awareness.last_seen_position
	_wall.position = Vector3(0, 1.5, -1.5)
	_target.place_at(Vector3(0.5, 0, -6))
	await _synchronize()
	NpcPerceptionService.sense(_observer, person, _target, 0.2)
	assert_false(awareness.target_visible)
	assert_eq(awareness.last_seen_position, confirmed)
	assert_almost_eq(awareness.search_elapsed, 0.2, 0.001)
#endregion

#region Hearing
## The gameplay circuit and visual light switch together and change actual detection.
func test_light_switch_changes_visibility() -> void:
	_target.place_at(Vector3(0, 0, -8))
	_profile.dark_vision_fraction = 0.1
	var circuit: Entity = _world.query.with_all([C_District]).execute_one()
	var state: C_LightCircuit = C_LightCircuit.new()
	state.circuit_id = &"test_sight"
	state.light_groups = [&"test_sight_lamps"]
	circuit.add_component(state)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = 12.0
	lamp.light_energy = 4.0
	lamp.add_to_group(&"test_sight_lamps")
	var view: CircuitLightView = CircuitLightView.new()
	view.name = "CircuitLightView"
	view.circuit_id = &"test_sight"
	lamp.add_child(view)
	_root.add_child(lamp)
	lamp.position = Vector3(0, 3, -8)
	_district.light_sources.append(lamp)
	await _synchronize()
	assert_true(NpcPerceptionService.can_see(_observer, _target, _profile))
	assert_true(LightCircuitService.set_enabled(circuit, false))
	assert_false(lamp.visible)
	assert_false(NpcPerceptionService.can_see(_observer, _target, _profile))
	assert_true(LightCircuitService.set_enabled(circuit, true))
	assert_true(lamp.visible)
	assert_true(NpcPerceptionService.can_see(_observer, _target, _profile))

## Opening a physical door emits a location but creates no social accusation.
func test_interaction_noise_is_anonymous() -> void:
	_observer.add_component(C_PlayerInputController.new())
	PlayerInteractionEvents.publish(_observer, _target, PlayerInteractionEvent.Kind.DOOR_OPENED)
	assert_eq(_district.noises.size(), 1)
	assert_eq(_district.noises[0].position, _target.global_position)
	assert_null(CombatService.target_for(_target))

## A noise behind cover supplies a position without inventing a combat opponent.
func test_hearing_does_not_reveal_source_identity() -> void:
	_wall.position = Vector3(0, 1.5, -1.5)
	await _synchronize()
	var noise: NpcNoise = NpcNoise.new()
	noise.position = Vector3(0, 1.0, -3)
	noise.radius = 20.0
	noise.source = _target
	assert_true(NpcPerceptionService.hear(_observer, _profile, noise))
	var awareness: C_NpcAwareness = _observer.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_eq(awareness.heard_position, noise.position)
	assert_null(CombatService.target_for(_observer))
	assert_false(awareness.target_visible)
#endregion
