extends GutTest
## Native camera/Jolt visibility, real compiler publication, manual BT priority and attack gating.

const ANGEL: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_weeping_angel.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)

var _root: Node3D
var _world: World
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _camera: Camera3D
var _constraint: C_NpcGazeFreeze
var _decision: C_NpcDecision
var _automatic_steps: bool = false


class OtherCapability extends DEF_NpcTrait:
	func _init() -> void:
		kind = Kind.CAPABILITY


	func valid_configuration() -> bool:
		return kind == Kind.CAPABILITY


#region Native fixture and physics boundary
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	var session: Entity = Entity.new()
	var district: C_District = C_District.new()
	district.definition = DISTRICT
	session.component_resources = [district, C_DayCycle.new()]
	_world.add_entity(session)
	_person = NpcRecord.new()
	_person.npc_id = &"gaze/angel"
	_person.profile = ANGEL
	_person.variation = NpcVariationRules.create(
		ANGEL,
		GameTimeQueries.current().world_seed,
		_person.npc_id,
		1,
	)
	_person.placement = NpcRecord.Placement.STREET
	(session.get_component(C_District) as C_District).people.append(_person)
	_actor = BODY.instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, DISTRICT)
	assert_true(EntityCompositionService.try_register(context))
	(_actor.get_component(C_CharacterBody) as C_CharacterBody).gravity_scale = 0.0
	_actor.place_at(Vector3(0.0, 0.0, -3.0))
	_constraint = _actor.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
	_decision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	NpcBrainService.bind_engine(_actor)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	_player = player_body as Node as Entity
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_camera = Camera3D.new()
	_camera.position = Vector3.UP * 1.3
	player_body.add_child(_camera)
	_world.add_entity(_player)
	_camera.make_current()
	var sensor: S_NpcGazeFreeze = S_NpcGazeFreeze.new()
	sensor.group = "GazeFixture"
	_world.add_system(sensor)
	var attacks: S_NpcCombat = S_NpcCombat.new()
	attacks.group = "GazeFixture"
	_world.add_system(attacks)
	var intent_owner: S_NpcIntent = S_NpcIntent.new()
	intent_owner.group = "GazeFixture"
	_world.add_system(intent_owner)
	_automatic_steps = false


func after_each() -> void:
	_automatic_steps = false
	for entity: Entity in _world.entities.duplicate():
		_world.remove_entity(entity)
	_world.purge(false)
	ECS.world = null
	_root.free()


func _physics_process(delta: float) -> void:
	if _automatic_steps:
		_world.process(delta, "GazeFixture")


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _sample() -> void:
	_world.process(1.0 / 60.0, "GazeFixture")


func _wall(size: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.position = Vector3(0.0, 1.3, -1.5)
	return wall
#endregion


#region Camera clipping and actual solid geometry
func test_current_player_camera_frustum_and_clip_planes_define_observation() -> void:
	await _sync_physics()
	assert_true(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	_camera.rotation.y = PI
	assert_false(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	_camera.rotation.y = 0.0
	_camera.far = 1.0
	assert_false(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	_camera.far = 100.0
	_camera.near = 4.0
	assert_false(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	_camera.near = 0.05
	_camera.fov = 20.0
	_actor.place_at(Vector3(4.0, 0.0, -3.0))
	assert_false(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	assert_false(NpcCameraVisibility.observed(_actor, null, _constraint.rule))


func test_wall_blocks_observation_and_partial_body_visibility_still_freezes() -> void:
	var wall: StaticBody3D = _wall(Vector3(4.0, 4.0, 0.2))
	await _sync_physics()
	assert_false(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	((wall.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.x = 0.1
	await _sync_physics()
	assert_true(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	wall.collision_layer = 0
	await _sync_physics()
	assert_true(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))


func test_unrelated_viewport_camera_and_hidden_actor_do_not_count_as_player_gaze() -> void:
	await _sync_physics()
	var spectator: Camera3D = Camera3D.new()
	_root.add_child(spectator)
	spectator.make_current()
	assert_false(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
	_camera.make_current()
	_actor.hide()
	assert_false(NpcCameraVisibility.observed(_actor, _player, _constraint.rule))
#endregion


#region Native physics, BT and attack priority
func test_observation_cancels_attack_and_freezes_without_waiting_for_decision_budget() -> void:
	await _sync_physics()
	assert_true(CombatService.bind_target(_actor, _player))
	var combat: C_NpcCombat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	combat.attack = combat.melee_attacks[0]
	combat.phase = C_NpcCombat.Phase.WINDUP
	var generation: int = combat.execution_generation
	var health: C_Health = _player.get_component(C_Health) as C_Health
	var before: float = health.current
	_actor.velocity = Vector3.RIGHT * 2.0
	NpcIntentService.move_to(_actor, Vector3.RIGHT * 4.0, 0.3)
	_decision.scheduled_delta = 0.0
	_sample()
	assert_true(_constraint.observed)
	assert_false(_actor.physical_motion_allowed())
	assert_eq(_actor.velocity, Vector3.ZERO)
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	assert_eq(controller.direction_motion, Vector3.ZERO)
	assert_eq(controller.direction_look, Vector3.ZERO)
	assert_eq(_actor.navigation_agent.avoidance_priority, S_NpcIntent.WAITING_AVOIDANCE_PRIORITY)
	assert_eq(combat.phase, C_NpcCombat.Phase.READY)
	assert_gt(combat.execution_generation, generation)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(health.current, before)
	assert_true(_decision.wake_requested)
	assert_true(_decision.wake_urgent)
	assert_eq(_decision.scheduled_delta, 0.0)
	var pose: Vector3 = _actor.global_position
	await _sync_physics()
	assert_almost_eq(_actor.global_position, pose, Vector3.ONE * 0.0001)
	var lifecycle: int = _decision.lifecycle_generation
	_sample()
	assert_eq(_decision.lifecycle_generation, lifecycle, "Stable visibility does not spam wakes")


func test_native_tree_prioritizes_freeze_over_danger_blood_and_combat() -> void:
	await _sync_physics()
	assert_true(CombatService.bind_target(_actor, _player))
	(_actor.get_component(C_NpcAwareness) as C_NpcAwareness).hazard_distress = true
	NpcIntentService.move_to(_actor, Vector3.RIGHT * 4.0, 0.3)
	_sample()
	assert_true(NpcBrainService.update_tree(_actor, 0.1))
	assert_eq(_decision.active_behavior, "Замер под взглядом")
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.EMERGENCY)
	assert_false((_actor.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert_same(CombatQueries.target_for(_actor), _player)
	var runner: BTPlayer = _actor.get_node("Brain") as BTPlayer
	assert_eq(runner.update_mode, BTPlayer.MANUAL)


func test_unobserved_frame_releases_body_and_requests_one_urgent_resample() -> void:
	await _sync_physics()
	_sample()
	_decision.wake_requested = false
	_decision.wake_urgent = false
	var generation: int = _decision.lifecycle_generation
	_camera.rotation.y = PI
	_automatic_steps = true
	await _sync_physics()
	_automatic_steps = false
	assert_false(_constraint.observed)
	assert_true(_actor.physical_motion_allowed())
	assert_true(_decision.wake_urgent)
	assert_eq(_decision.lifecycle_generation, generation + 1)
	_sample()
	assert_eq(_decision.lifecycle_generation, generation + 1)


func test_attack_callbacks_cannot_bypass_the_sampled_constraint() -> void:
	await _sync_physics()
	assert_true(CombatService.bind_target(_actor, _player))
	_sample()
	assert_false(NpcAttackService.can_start(_actor, C_NpcCombat.Kind.MELEE, 0))
	var combat: C_NpcCombat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	combat.attack = combat.melee_attacks[0]
	combat.phase = C_NpcCombat.Phase.WINDUP
	assert_false(NpcAttackService.commit_effect(_actor))
	assert_eq(combat.phase, C_NpcCombat.Phase.READY)
	assert_same(CombatQueries.target_for(_actor), _player)


func test_observation_pauses_native_animation_and_unobserved_body_resumes() -> void:
	await _sync_physics()
	var animator: AnimationPlayer = _actor.animation_player
	assert_true(animator.has_animation(_actor.idle_animation))
	animator.play(_actor.idle_animation)
	_sample()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(animator.is_playing())
	var position: float = animator.current_animation_position
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(animator.current_animation_position, position)
	_camera.rotation.y = PI
	_sample()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(animator.is_playing())


func test_reset_restore_and_dormant_participation_reconcile_native_freeze() -> void:
	await _sync_physics()
	var variation: Dictionary = SaveDataCodec.encode(_person.variation) as Dictionary
	_sample()
	assert_false(_actor.physical_motion_allowed())
	var config: C_CharacterBody = _actor.get_component(C_CharacterBody) as C_CharacterBody
	config.impulse_velocity = Vector3.RIGHT
	config.pending_rebound_velocity = Vector3.UP
	config.incoming_bodies[1] = C_CharacterBody.BodyMotion.new()
	DistrictPopulationService.reset_brain(_actor)
	assert_eq(config.impulse_velocity, Vector3.ZERO)
	assert_eq(config.pending_rebound_velocity, Vector3.ZERO)
	assert_true(config.incoming_bodies.is_empty())
	assert_false(_constraint.observed)
	assert_true(_actor.physical_motion_allowed())
	assert_eq(SaveDataCodec.encode(_person.variation), variation)
	DistrictPopulationService.restore_participation()
	assert_same(_constraint.rule, NpcGazeQueries.selected_rule(_person.rules_for()))
	assert_false(_constraint.observed)
	_sample()
	assert_false(_actor.physical_motion_allowed())
	_actor.set_participating(false)
	_constraint.observed = false
	_actor.sync_gaze_constraint()
	assert_false(
		_actor.physical_motion_allowed(),
		"Releasing observation cannot wake a dormant body",
	)
#endregion


#region Detached compiler and authored trait validation
func test_combat_speed_uses_live_binding_without_base_speed_or_variation_drift() -> void:
	_camera.rotation.y = PI
	await _sync_physics()
	var motion: C_Motion = _actor.get_component(C_Motion) as C_Motion
	var base_speed: float = motion.max_speed
	var variation: Dictionary = SaveDataCodec.encode(_person.variation) as Dictionary
	_sample()
	assert_eq(motion.control_speed_multiplier, 1.0)
	assert_true(CombatService.bind_target(_actor, _player))
	_sample()
	assert_eq(motion.control_speed_multiplier, ANGEL.aggressive_speed_multiplier)
	var expected: float = base_speed * ANGEL.aggressive_speed_multiplier
	assert_almost_eq(MotionRules.effective_speed(motion, null, null), expected, 0.0001)
	assert_almost_eq(_actor.navigation_agent.max_speed, expected, 0.0001)
	assert_eq(motion.max_speed, base_speed)
	_camera.rotation.y = 0.0
	_sample()
	assert_true(_constraint.observed)
	assert_eq(motion.control_speed_multiplier, 1.0)
	assert_same(CombatQueries.target_for(_actor), _player)
	_camera.rotation.y = PI
	_sample()
	assert_eq(motion.control_speed_multiplier, ANGEL.aggressive_speed_multiplier)
	CombatService.end_combat(_actor)
	_sample()
	assert_eq(motion.control_speed_multiplier, 1.0)
	assert_eq(motion.max_speed, base_speed)
	assert_eq(SaveDataCodec.encode(_person.variation), variation)


func test_native_body_consumes_combat_speed_policy_and_reset_clears_it() -> void:
	_camera.rotation.y = PI
	await _sync_physics()
	var motion: C_Motion = _actor.get_component(C_Motion) as C_Motion
	var base_speed: float = motion.max_speed
	motion.air_acceleration = 100.0
	assert_true(CombatService.bind_target(_actor, _player))
	NpcIntentService.move_to(_actor, _actor.global_position + Vector3.RIGHT * 20.0, 0.3)
	(_actor.get_component(C_NpcIntent) as C_NpcIntent).navigation_enabled = false
	_automatic_steps = true
	for frame: int in range(40):
		await get_tree().physics_frame
		if _actor.velocity.length() > base_speed * 1.5:
			break
	_automatic_steps = false
	assert_gt(_actor.velocity.length(), base_speed * 1.5)
	assert_eq(motion.max_speed, base_speed)
	DistrictPopulationService.reset_brain(_actor)
	assert_eq(motion.control_speed_multiplier, 1.0)
	assert_null(CombatQueries.target_for(_actor))
	DistrictPopulationService.restore_participation()
	assert_eq(motion.control_speed_multiplier, 1.0)
	assert_eq(motion.max_speed, base_speed)


func test_dead_or_unregistered_target_does_not_apply_combat_speed() -> void:
	_camera.rotation.y = PI
	await _sync_physics()
	assert_true(CombatService.bind_target(_actor, _player))
	var motion: C_Motion = _actor.get_component(C_Motion) as C_Motion
	_sample()
	assert_gt(motion.control_speed_multiplier, 1.0)
	_player.add_component(C_Death.new())
	_sample()
	assert_eq(motion.control_speed_multiplier, 1.0)
	_player.remove_component(C_Death)
	_world.remove_entity(_player)
	_sample()
	assert_eq(motion.control_speed_multiplier, 1.0)
	_player.free()


func test_combat_speed_authored_bounds_and_default_actors() -> void:
	var profile: DEF_NpcArchetype = ANGEL.duplicate() as DEF_NpcArchetype
	for invalid: float in [NAN, INF, 0.9, 4.1]:
		profile.aggressive_speed_multiplier = invalid
		assert_false(profile.valid_rules())
	profile.aggressive_speed_multiplier = 1.0
	assert_true(profile.valid_rules())
	assert_eq(C_Motion.new().control_speed_multiplier, 1.0)
	assert_eq(DEF_NpcArchetype.new().aggressive_speed_multiplier, 1.0)


func test_selected_capability_is_installed_before_entity_added() -> void:
	var fresh: E_DistrictNpc = BODY.instantiate() as E_DistrictNpc
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = &"gaze/publication"
	person.profile = ANGEL
	person.variation = NpcVariationRules.create(
		ANGEL,
		GameTimeQueries.current().world_seed,
		person.npc_id,
		1,
	)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		fresh,
		_world,
		"gaze/publication",
	)
	NpcConstructionService.configure_context(context, person, DISTRICT)
	var seen: Array[bool] = []
	_world.entity_added.connect(
		func(published: Entity) -> void:
			if published == fresh:
				var installed: C_NpcGazeFreeze = (
					published.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
				)
				assert_same(installed.rule, _constraint.rule)
				assert_false(installed.observed)
				seen.append(true),
	)
	var registered: bool = EntityCompositionService.try_register(context)
	assert_true(registered)
	if not registered:
		fresh.free()
	assert_eq(seen.size(), 1)


func test_typed_capabilities_compose_and_reject_invalid_or_duplicate_tuning() -> void:
	var profile: DEF_NpcArchetype = ANGEL.duplicate() as DEF_NpcArchetype
	var other: OtherCapability = OtherCapability.new()
	other.key = &"fixture/other_capability"
	profile.rules = [profile.rules[0], other]
	assert_true(NpcVariationRules.valid_archetype(profile))
	var duplicate: DEF_NpcGazeFreeze = DEF_NpcGazeFreeze.new()
	duplicate.key = &"fixture/second_freeze"
	profile.rules.append(duplicate)
	assert_false(NpcVariationRules.valid_archetype(profile))
	profile.rules = [duplicate]
	duplicate.sample_offsets.clear()
	assert_false(NpcVariationRules.valid_archetype(profile))
	var untyped: DEF_NpcTrait = DEF_NpcTrait.new()
	untyped.key = &"fixture/untyped_capability"
	untyped.kind = DEF_NpcTrait.Kind.CAPABILITY
	profile.rules = [untyped]
	assert_false(NpcVariationRules.valid_archetype(profile))
#endregion


#region Native impact while observed
func test_frozen_native_npc_receives_raw_impact_without_motion_or_stored_release() -> void:
	_world.add_observer(O_Damage.new())
	var impacts: S_Impact = S_Impact.new()
	impacts.group = "GazeFixture"
	_world.add_system(impacts)
	await _sync_physics()
	_sample()
	assert_true(_constraint.observed)
	# This physical freeze case uses the native Angel recipe with a nonimmune test receiver.
	# The authored Angel resistance remains unchanged.
	(
		_actor.get_component(C_DamageResistance) as C_DamageResistance
	).multipliers[DamageRequest.Type.IMPACT] = 1.0
	var body: CharacterBody3D = _actor as Node as CharacterBody3D
	var origin: Vector3 = body.global_position
	var health: C_Health = _actor.get_component(C_Health) as C_Health
	health.value = 100.0
	health.current = 100.0
	var projectile: RigidBody3D = RigidBody3D.new()
	projectile.mass = 20.0
	projectile.gravity_scale = 0.0
	projectile.continuous_cd = true
	projectile.collision_mask = 2
	projectile.collision_layer = 4
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.2
	collision.shape = shape
	projectile.add_child(collision)
	_world.add_child(projectile)
	projectile.position = origin + Vector3(-3.0, 0.85, 0.0)
	projectile.linear_velocity = Vector3.RIGHT * 20.0
	for frame: int in 45:
		await get_tree().physics_frame
		await get_tree().process_frame
		_sample()
	assert_lt(health.current, 100.0, "Observed NPC still receives real physical damage")
	assert_true(_constraint.observed)
	assert_eq(body.global_position, origin)
	var config: C_CharacterBody = _actor.get_component(C_CharacterBody) as C_CharacterBody
	assert_eq(config.impulse_velocity, Vector3.ZERO)
	assert_eq(config.pending_rebound_velocity, Vector3.ZERO)
	projectile.free()
	_camera.rotation.y = PI
	_sample()
	assert_false(_constraint.observed)
	for frame: int in 12:
		await get_tree().physics_frame
	assert_eq(body.global_position, origin, "Ending observation cannot release old impacts")
#endregion
