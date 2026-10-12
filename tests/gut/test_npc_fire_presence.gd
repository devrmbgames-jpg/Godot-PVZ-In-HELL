extends GutTest
## Real fire NPC presence, native floor overlap, common damage, route height and owner teardown.

const FIRE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_fire_elemental.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const FLOOR: DEF_ToxicArea = preload(
	"res://content/domains/hazards/definitions/def_npc_floor_fire.tres"
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


	func query() -> QueryBuilder:
		return q.with_all([C_Hazard]).on_event(HazardSpawnResult.EVENT)


	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
		if hazard.definition.key != &"npc_fire_aura":
			return
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


#region Independent immutable profiles and physical exposure
func test_native_presence_has_one_sphere_and_one_authored_ten_metre_floor() -> void:
	assert_true(FIRE.valid_rules())
	assert_true(_presence().valid_configuration())
	var invalid: DEF_NpcFireAura = _presence().duplicate(true) as DEF_NpcFireAura
	invalid.floor_hazard = DEF_ToxicArea.new()
	invalid.floor_hazard.floor_height = 0.2
	invalid.floor_hazard.key = invalid.aura.key
	assert_false(invalid.valid_configuration(), "The two effects require distinct authored keys")
	invalid.floor_hazard = null
	assert_false(invalid.valid_configuration(), "Typed fire presence requires its floor profile")
	assert_eq(FLOOR.radius, 10.0)
	assert_eq(FLOOR.floor_height, 0.2)
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	var sphere: E_ToxicArea = _effect(&"npc_fire_aura")
	var floor: E_ToxicArea = _effect(&"npc_floor_fire")
	assert_not_null(sphere)
	assert_not_null(floor)
	assert_true(floor.enabled)
	assert_eq((sphere.get_shape().shape as SphereShape3D).radius, 2.25)
	assert_eq((floor.get_shape().shape as CylinderShape3D).radius, 10.0)
	assert_almost_eq((floor.get_shape().shape as CylinderShape3D).height, 0.2, 0.001)
	assert_almost_eq((floor.get_visual().mesh as CylinderMesh).height, 0.2, 0.001)
	assert_eq(floor.global_position, Vector3.UP * 0.1)
	var before: int = _district.next_aura
	for repeat: int in range(3):
		NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_eq(_district.next_aura, before)
	assert_eq(_world.query.with_all([C_Hazard, C_ToxicArea]).execute().size(), 2)


func test_floor_burns_real_ground_receiver_but_not_raised_or_outside_and_source_is_immune() -> void:
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	var ground: Entity = _receiver(Vector3(8.0, 0.0, 0.0))
	var raised: Entity = _receiver(Vector3(8.0, 1.0, 0.0))
	var outside: Entity = _receiver(Vector3(11.0, 0.0, 0.0))
	await _physics_ready()
	var floor: E_ToxicArea = _effect(&"npc_floor_fire")
	assert_true(floor.get_area().overlaps_body(ground as Node as PhysicsBody3D))
	assert_false(floor.get_area().overlaps_body(raised as Node as PhysicsBody3D))
	assert_false(floor.get_area().overlaps_body(outside as Node as PhysicsBody3D))
	_world.process(FLOOR.tick_seconds)
	assert_eq((ground.get_component(C_Health) as C_Health).current, 100.0 - FLOOR.damage_per_tick)
	assert_eq((raised.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq((outside.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq((_actor.get_component(C_Health) as C_Health).current, 100.0)


func test_floor_route_risk_clips_height_and_agrees_with_damage_and_immunity() -> void:
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	var normal: E_DistrictNpc = _ordinary_npc(Vector3(8.0, 0.0, 0.0))
	assert_true(NpcRouteSolver.danger_here(normal))
	normal.add_component(C_PlayerInputController.new())
	assert_false(NpcSleepService.blockers().is_empty())
	normal.place_at(Vector3(8.0, 1.0, 0.0))
	assert_false(NpcRouteSolver.danger_here(normal))
	assert_true(NpcSleepService.blockers().is_empty())
	var floor_path: PackedVector3Array = [Vector3(7.0, 0.0, 0.0), Vector3(9.0, 0.0, 0.0)]
	var raised_path: PackedVector3Array = [Vector3(7.0, 1.0, 0.0), Vector3(9.0, 1.0, 0.0)]
	var ascent: PackedVector3Array = [Vector3(7.0, 0.0, 0.0), Vector3(9.0, 1.0, 0.0)]
	var full: float = NpcRouteSolver.expected_damage(normal, floor_path)
	assert_gt(full, 0.0)
	assert_eq(NpcRouteSolver.expected_damage(normal, raised_path), 0.0)
	assert_almost_eq(NpcRouteSolver.expected_damage(normal, ascent), full * 0.2, 0.001)
	assert_eq(NpcRouteSolver.expected_damage(_actor, floor_path), 0.0)
	var legacy: DEF_ToxicArea = DEF_ToxicArea.new()
	assert_eq(legacy.floor_height, 0.0)
	assert_true(HazardProfileRules.valid(legacy))
	for invalid: float in [-0.1, INF, NAN]:
		legacy.floor_height = invalid
		assert_false(HazardProfileRules.valid(legacy))


func test_both_effects_follow_native_owner_and_retire_when_it_becomes_dormant() -> void:
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	_actor.place_at(Vector3(3.0, 0.0, 2.0))
	_world.process(0.0)
	assert_eq(_effect(&"npc_floor_fire").global_position, Vector3(3.0, 0.1, 2.0))
	assert_eq(
		_effect(&"npc_fire_aura").global_position,
		Vector3(3.0, NpcPerceptionService.TORSO_HEIGHT, 2.0),
	)
	var floor: E_ToxicArea = _effect(&"npc_floor_fire")
	var hazard: C_Hazard = floor.get_component(C_Hazard) as C_Hazard
	var restored: C_Hazard = C_Hazard.new()
	assert_true(SaveDataCodec.apply_fields(restored, SaveDataCodec.component_data(hazard).fields))
	assert_eq((restored.definition as DEF_ToxicArea).floor_height, 0.2)
	var references: Dictionary = PersistentHazardState.capture(floor, _root)
	var actors: Dictionary[String, Entity] = { }
	actors[ActorIdentityRules.key_for(_actor, _root)] = _actor
	var before: int = _district.next_aura
	PersistentHazardState.restore(references, floor, actors)
	assert_eq(_district.next_aura, before)
	var binding: Relationship = HazardFollowService.binding(floor)
	assert_same(binding.target, _actor)
	assert_eq((binding.relation as R_HazardFollow).local_offset.origin, Vector3.UP * 0.1)
	assert_eq((floor.get_shape().shape as CylinderShape3D).radius, 10.0)
	DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.OUTSIDE)
	_world.process(0.0)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 0)


func test_first_spawn_receiver_retirement_prevents_second_effect() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	_world.add_observer(mutator)
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_null(_effect(&"npc_floor_fire"))


func test_first_spawn_receiver_dormancy_prevents_second_effect() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	mutator.mode = 1
	_world.add_observer(mutator)
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_null(_effect(&"npc_floor_fire"))
	assert_false(_actor.enabled)


func test_first_spawn_receiver_reset_prevents_old_second_effect() -> void:
	var mutator: PresenceMutator = PresenceMutator.new()
	mutator.mode = 2
	_world.add_observer(mutator)
	NpcTraitService.ensure_aura(_actor, _person, _presence())
	assert_null(_effect(&"npc_floor_fire"))
#endregion
