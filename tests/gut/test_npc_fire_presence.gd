extends GutTest
## Real fire presence, native overlap/risk and scheduled publication lifetime boundaries.

const FIRE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_fire_elemental.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const LOST: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_lost.tres"
)

var _root: Node3D
var _world: World
var _district: C_District
var _actor: E_DistrictNpc
var _person: NpcRecord


class PresenceMutator extends Observer:
	## Zero retires, one suspends, two resets the real receiver during the first spawn fact.
	var mode: int = 0
	## Counts the real publication boundary reached by the scheduled regression.
	var spawn_facts: int = 0


	func query() -> QueryBuilder:
		return q.with_all([C_Hazard]).on_event(HazardSpawnResult.EVENT)


	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
		if hazard.definition.key != &"npc_fire_aura":
			return
		spawn_facts += 1
		var actor: E_DistrictNpc = hazard.origin as E_DistrictNpc
		if mode == 0:
			_world.remove_entity(actor)
			actor.free()
		elif mode == 1:
			var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
			DistrictPopulationService.set_placement(
				NpcPopulationQueries.person_for(identity.npc_id),
				actor,
				NpcRecord.Placement.OUTSIDE,
			)
		else:
			DistrictPopulationService.reset_brain(actor)


#region Real native fixture
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
	_district = C_District.new()
	_district.definition = DISTRICT
	session.component_resources = [_district, C_DayCycle.new()]
	_world.add_entity(session)
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ToxicAreaSetup.new())
	_world.add_observer(O_HazardFollowLifecycle.new())
	_world.add_system(S_HazardFollow.new())
	_world.add_system(S_ToxicArea.new())
	_world.add_system(S_HazardLifetime.new())
	_person = NpcRecord.new()
	_person.npc_id = &"fire/presence"
	_person.profile = FIRE
	_person.variation = NpcVariationRules.create(FIRE, 1234, _person.npc_id, 1)
	_person.placement = NpcRecord.Placement.STREET
	_district.people.append(_person)
	_actor = BODY.instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, DISTRICT)
	assert_true(EntityCompositionService.try_register(context))
	_actor.place_at(Vector3.ZERO)
	_actor.freeze = true


func after_each() -> void:
	_world.purge(false)
	ECS.world = null
	_root.free()


func _presence() -> DEF_NpcFireAura:
	return _person.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) as DEF_NpcFireAura


func _effect(key: StringName) -> E_ToxicArea:
	for effect: Entity in _world.query.with_all([C_Hazard, C_ToxicArea]).execute():
		if (effect.get_component(C_Hazard) as C_Hazard).definition.key == key:
			return effect as E_ToxicArea
	return null


func _receiver(point: Vector3) -> Entity:
	var node: CharacterBody3D = CharacterBody3D.new()
	node.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var entity: Entity = node as Node as Entity
	entity.component_resources = [C_Health.new(), C_Living.new()]
	node.collision_layer = 2
	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	node.add_child(collider)
	_world.add_entity(entity)
	node.global_position = point
	return entity


func _physics_ready() -> void:
	for frame: int in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame


func _ordinary_npc(point: Vector3) -> E_DistrictNpc:
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = &"fire/ordinary"
	person.profile = LOST
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	person.placement = NpcRecord.Placement.STREET
	_district.people.append(person)
	var body: E_DistrictNpc = BODY.instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		body,
		_world,
		String(person.npc_id),
	)
	NpcConstructionService.configure_context(context, person, DISTRICT)
	assert_true(EntityCompositionService.try_register(context))
	body.freeze = true
	body.place_at(point)
	return body
#endregion


#region Scheduled publication regression
func _queue_trait_step() -> C_NpcAwareness:
	# A detached second rule makes any stale continuation observable after disable/reset.
	var profile: DEF_NpcArchetype = FIRE.duplicate() as DEF_NpcArchetype
	var later_rule: DEF_NpcTrait = DEF_NpcTrait.new()
	later_rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	profile.rules = [_presence(), later_rule]
	profile.optional_traits = []
	_person.profile = profile
	var awareness: C_NpcAwareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	var cycle: C_DayCycle = DayPhaseQueries.current()
	decision.scheduled_delta = 0.2
	decision.scheduled_day = cycle.day_index
	decision.scheduled_phase = int(cycle.phase)
	var traits: S_NpcTraits = S_NpcTraits.new()
	traits.group = "fire_presence_traits"
	traits.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(traits)
	_world.process(0.0, traits.group)
	assert_true(traits.has_pending_commands())
	return awareness


func test_scheduled_traits_materialize_contact_aura_and_continue_the_live_step() -> void:
	var awareness: C_NpcAwareness = _queue_trait_step()
	_world.flush_command_buffers()
	assert_not_null(_effect(&"npc_fire_aura"))
	assert_null(_effect(&"npc_floor_fire"))
	assert_eq(_world.query.with_all([C_Hazard, C_ToxicArea]).execute().size(), 1)
	assert_true(awareness.rule_exposure.has(DEF_NpcTrait.Kind.LIGHT_AVERSION))


func test_scheduled_traits_stop_after_spawn_receiver_retirement() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	_world.add_observer(mutator)
	_queue_trait_step()
	_world.flush_command_buffers()
	assert_eq(mutator.spawn_facts, 1)
	assert_null(_effect(&"npc_floor_fire"))


func test_scheduled_traits_stop_after_spawn_receiver_dormancy() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	mutator.mode = 1
	_world.add_observer(mutator)
	var awareness: C_NpcAwareness = _queue_trait_step()
	_world.flush_command_buffers()
	assert_eq(mutator.spawn_facts, 1)
	assert_null(_effect(&"npc_floor_fire"))
	assert_false(_actor.enabled)
	assert_true(awareness.rule_exposure.is_empty(), "A disabled actor cannot advance later rules")


func test_scheduled_traits_stop_after_spawn_receiver_reset() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	mutator.mode = 2
	_world.add_observer(mutator)
	var awareness: C_NpcAwareness = _queue_trait_step()
	_world.flush_command_buffers()
	assert_eq(mutator.spawn_facts, 1)
	assert_null(_effect(&"npc_floor_fire"))
	assert_true(awareness.rule_exposure.is_empty(), "An obsolete step cannot mutate reset state")
#endregion


#region Independent immutable profiles and physical exposure
func test_native_presence_has_one_reduced_sphere_and_no_floor_effect() -> void:
	assert_true(FIRE.valid_rules())
	assert_true(_presence().valid_configuration())
	var invalid: DEF_NpcFireAura = _presence().duplicate(true) as DEF_NpcFireAura
	invalid.aura = invalid.aura.duplicate() as DEF_ToxicArea
	invalid.aura.floor_height = 0.2
	assert_false(invalid.valid_configuration(), "Fire contact must remain spherical")
	invalid.aura = null
	assert_false(invalid.valid_configuration(), "Fire presence requires its contact profile")
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	var sphere: E_ToxicArea = _effect(&"npc_fire_aura")
	assert_not_null(sphere)
	assert_null(_effect(&"npc_floor_fire"))
	assert_eq((sphere.get_shape().shape as SphereShape3D).radius, 1.6875)
	assert_eq((sphere.get_visual().mesh as SphereMesh).radius, 1.6875)
	assert_false((sphere.get_component(C_HazardLifetime) as C_HazardLifetime).persistent)
	var before: int = _district.next_aura
	for repeat: int in range(3):
		NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_eq(_district.next_aura, before)
	assert_eq(_world.query.with_all([C_Hazard, C_ToxicArea]).execute().size(), 1)


func test_contact_burns_inside_but_not_removed_shell_or_wide_radius_and_source_is_immune() -> void:
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	var inside: Entity = _receiver(Vector3(1.0, 0.0, 0.0))
	var removed_shell: Entity = _receiver(Vector3(2.2, 0.0, 0.0))
	var wide: Entity = _receiver(Vector3(8.0, 0.0, 0.0))
	await _physics_ready()
	var sphere: E_ToxicArea = _effect(&"npc_fire_aura")
	assert_true(sphere.get_area().overlaps_body(inside as Node as PhysicsBody3D))
	assert_false(sphere.get_area().overlaps_body(removed_shell as Node as PhysicsBody3D))
	assert_false(sphere.get_area().overlaps_body(wide as Node as PhysicsBody3D))
	_world.process(_presence().aura.tick_seconds)
	assert_eq((inside.get_component(C_Health) as C_Health).current, 96.0)
	assert_eq((removed_shell.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq((wide.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq((_actor.get_component(C_Health) as C_Health).current, 100.0)


func test_contact_route_risk_and_sleep_exclude_removed_shell_and_wide_radius() -> void:
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	var normal: E_DistrictNpc = _ordinary_npc(Vector3(1.0, 0.0, 0.0))
	assert_true(NpcRouteSolver.danger_here(normal))
	normal.add_component(C_PlayerInputController.new())
	assert_false(NpcSleepService.blockers().is_empty())
	normal.place_at(Vector3(2.2, 0.0, 0.0))
	assert_false(NpcRouteSolver.danger_here(normal))
	# Sleep retains its separate authored safety margin beyond the physical contact volume.
	normal.place_at(Vector3(8.0, 0.0, 0.0))
	assert_true(NpcSleepService.blockers().is_empty())
	var contact_path: PackedVector3Array = [Vector3(1.0, 0.0, 0.0), Vector3(1.5, 0.0, 0.0)]
	var shell_path: PackedVector3Array = [Vector3(2.2, 0.0, 0.0), Vector3(2.4, 0.0, 0.0)]
	var wide_path: PackedVector3Array = [Vector3(7.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0)]
	assert_gt(NpcRouteSolver.expected_damage(normal, contact_path), 0.0)
	assert_eq(NpcRouteSolver.expected_damage(normal, shell_path), 0.0)
	assert_eq(NpcRouteSolver.expected_damage(normal, wide_path), 0.0)
	assert_eq(NpcRouteSolver.expected_damage(_actor, contact_path), 0.0)


func test_contact_aura_follows_native_owner_and_retires_when_it_becomes_dormant() -> void:
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	_actor.place_at(Vector3(3.0, 0.0, 2.0))
	_world.process(0.0)
	assert_eq(
		_effect(&"npc_fire_aura").global_position,
		Vector3(3.0, NpcPerceptionService.TORSO_HEIGHT, 2.0),
	)
	var sphere: E_ToxicArea = _effect(&"npc_fire_aura")
	var hazard: C_Hazard = sphere.get_component(C_Hazard) as C_Hazard
	var restored: C_Hazard = C_Hazard.new()
	assert_true(SaveDataCodec.apply_fields(restored, SaveDataCodec.component_data(hazard).fields))
	assert_eq((restored.definition as DEF_ToxicArea).radius, 1.6875)
	var references: Dictionary = PersistentHazardState.capture(sphere, _root)
	var actors: Dictionary[String, Entity] = { }
	actors[ActorIdentityRules.key_for(_actor, _root)] = _actor
	var before: int = _district.next_aura
	PersistentHazardState.restore(references, sphere, actors)
	assert_eq(_district.next_aura, before)
	var binding: Relationship = HazardFollowService.binding(sphere)
	assert_same(binding.target, _actor)
	assert_eq(
		(binding.relation as R_HazardFollow).local_offset.origin,
		Vector3.UP * NpcPerceptionService.TORSO_HEIGHT,
	)
	assert_eq((sphere.get_shape().shape as SphereShape3D).radius, 1.6875)
	DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.OUTSIDE)
	_world.process(0.0)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 0)


func test_contact_spawn_receiver_retirement_never_materializes_floor_effect() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	_world.add_observer(mutator)
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_eq(mutator.spawn_facts, 1)
	assert_null(_effect(&"npc_floor_fire"))


func test_contact_spawn_receiver_dormancy_never_materializes_floor_effect() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	mutator.mode = 1
	_world.add_observer(mutator)
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_null(_effect(&"npc_floor_fire"))
	assert_false(_actor.enabled)


func test_contact_spawn_receiver_reset_never_materializes_floor_effect() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	mutator.mode = 2
	_world.add_observer(mutator)
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_null(_effect(&"npc_floor_fire"))
#endregion
