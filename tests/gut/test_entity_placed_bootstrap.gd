extends GutTest
## Exercises project World preparation before pinned registration and deferred System.setup.

## Minimal real level contract consumed by the existing save/startup boundary.
class FixtureLevel extends Node:
	## Empty path keeps this fixture outside live user slots.
	var autosave_path: String = ""


## Counts pinned registration calls; the project World must prepare every placed actor first.
class CountingWorld extends GameWorld:
	var _registrations: int = 0

	## Records the one native registration of each placed scene actor.
	func add_entity(actor: Entity, components: Variant = null,
			add_to_tree: bool = true) -> void:
		_registrations += 1
		super.add_entity(actor, components, add_to_tree)

	## Returns the number of native calls made by automatic World.initialize.
	func registrations() -> int:
		return _registrations


## Passive native ready reports complete data without emitting gameplay commands/outcomes.
class PassiveActor extends Entity:
	var _native_ready_calls: int = 0
	var _ready_components: int = 0

	## Counts native readiness while leaving gameplay state untouched.
	func on_ready() -> void:
		_native_ready_calls += 1
		_ready_components = components.size()

	## Returns the number of native initialization callbacks.
	func ready_calls() -> int:
		return _native_ready_calls

	## Returns data visible at the native on_ready boundary.
	func ready_components() -> int:
		return _ready_components


## Deferred setup confirms compilation never binds ECS.world early.
class SetupProbe extends System:
	var _setup_calls: int = 0
	var _setup_entities: int = 0

	## Records the World contents when normal ECS.world binding finalizes setup.
	func setup() -> void:
		_setup_calls += 1
		_setup_entities = _world.entities.size()

	## Returns the number of normal native setup invocations.
	func setup_calls() -> int:
		return _setup_calls

	## Returns the number of fully registered actors visible to passive setup.
	func setup_entities() -> int:
		return _setup_entities


var _level: FixtureLevel = null
var _world: CountingWorld = null
var _actors: Node = null
var _systems: Node = null

#region Prepared fixture lifetime
func before_each() -> void:
	_level = FixtureLevel.new()
	_level.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	_actors = Node.new()
	_actors.name = "Actors"
	_level.add_child(_actors)
	_systems = Node.new()
	_systems.name = "Systems"
	_level.add_child(_systems)
	_world = CountingWorld.new()
	_world.name = "World"
	_world.entity_nodes_root = NodePath("../Actors")
	_world.system_nodes_root = NodePath("../Systems")
	_level.add_child(_world)


func after_each() -> void:
	if ECS.world == _world:
		ECS.world = null
	_world.purge(false)
	_level.free()


func _actor(label: String, recipes: Array[Component]) -> PassiveActor:
	var actor: PassiveActor = PassiveActor.new()
	actor.name = label
	actor.component_resources = recipes
	actor.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(label))
	_actors.add_child(actor)
	actor.owner = _level
	return actor


func _template_actor(actor: Entity, capability_id: StringName,
		recipes: Array[Component]) -> EntityAuthoring:
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = DEF_EntityTemplate.new()
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = capability_id
	capability.component_recipes = recipes
	authoring.entity_template.traits = [capability]
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	return authoring
#endregion

#region Whole placed preparation
## Intrinsic scene and Template data initialize once, before normal passive System.setup.
func test_placed_recipes_prepare_before_native_registration_and_deferred_setup() -> void:
	var actor: PassiveActor = _actor("Actor", [C_DayCycle.new()])
	_template_actor(actor, &"resistance", [C_DamageResistance.new()])
	var probe: SetupProbe = SetupProbe.new()
	_systems.add_child(probe)
	probe.owner = _level
	var previous_world: World = ECS.world
	add_child(_level)
	assert_false(_world.initialization_failed())
	assert_eq(_world.registrations(), 1)
	assert_eq(actor.ready_calls(), 1)
	assert_eq(actor.ready_components(), 3, "Scene, Trait and authored identity are complete")
	assert_eq(probe.setup_calls(), 0)
	assert_eq(ECS.world, previous_world)
	ECS.world = _world
	assert_eq(probe.setup_calls(), 1)
	assert_eq(probe.setup_entities(), 1)
	assert_eq(_world.registrations(), 1)


## One provider conflict aborts the complete placed set before any actor's native on_ready.
func test_duplicate_provider_aborts_all_placed_registration_without_side_effects() -> void:
	var neighbour: PassiveActor = _actor("Neighbour", [C_DamageResistance.new()])
	var invalid: PassiveActor = _actor("Invalid", [C_DayCycle.new()])
	_template_actor(invalid, &"duplicate", [C_DayCycle.new()])
	add_child(_level)
	assert_true(_world.initialization_failed())
	assert_eq(_world.registrations(), 0)
	assert_eq(_world.entities.size(), 0)
	assert_eq(_world.entity_id_registry.size(), 0)
	assert_eq(neighbour.ready_calls(), 0)
	assert_eq(invalid.ready_calls(), 0)
	assert_false(EntityCompositionService.recipes_prepared(neighbour))
	assert_false(EntityCompositionService.recipes_prepared(invalid))
	assert_eq(neighbour.id, "")
	assert_eq(invalid.id, "")
	assert_true(_world.composition_issues().any(func(issue: EntityBuildPlan.Issue) -> bool:
		return issue.code == &"duplicate_provider"))


## The pre-native gate prevents GECS's replacement policy for repeated authored Entity IDs.
func test_duplicate_entity_id_is_rejected_before_native_collision_replacement() -> void:
	var first: PassiveActor = _actor("First", [])
	var second: PassiveActor = _actor("Second", [])
	first.id = "repeated/id"
	second.id = "repeated/id"
	add_child(_level)
	assert_true(_world.initialization_failed())
	assert_eq(_world.registrations(), 0)
	assert_eq(first.ready_calls(), 0)
	assert_eq(second.ready_calls(), 0)
	assert_false(first.is_queued_for_deletion())
	assert_false(second.is_queued_for_deletion())
	assert_eq(_world.entity_id_registry.size(), 0)


## A later-declared endpoint is validated as part of the same set and bound after both registrations.
func test_initial_binding_uses_fully_registered_endpoint_from_the_placed_set() -> void:
	var source: PassiveActor = _actor("Source", [])
	var target: PassiveActor = _actor("Target", [])
	var authoring: EntityAuthoring = _template_actor(source, &"mounted", [])
	authoring.bindings[&"support"] = NodePath("../Target")
	var intent: EntityInitialBinding = EntityInitialBinding.new()
	intent.relation = R_SlotMountedOn.new()
	intent.endpoint = &"support"
	authoring.entity_template.traits[0].initial_bindings = [intent]
	add_child(_level)
	assert_false(_world.initialization_failed())
	assert_eq(_world.registrations(), 2)
	assert_eq(source.relationships.size(), 1)
	assert_eq(source.relationships[0].target, target)
	assert_ne(source.relationships[0].relation, intent.relation)
	assert_gt(target.ecs_id, 0)
	assert_eq(source.ready_calls(), 1)
	assert_eq(target.ready_calls(), 1)
#endregion

#region District construction before native registration
## The same prepass gives placed merchant identity and fresh roster before ECS.world binding.
func test_placed_district_roster_and_merchant_identity_precede_native_publication() -> void:
	var district: C_District = C_District.new()
	district.definition = load(
		"res://content/domains/npc/definitions/def_district_default.tres") as DEF_District
	var session: PassiveActor = _actor("Session", [district, C_DayCycle.new()])
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = load(
		"res://content/domains/npc/definitions/def_entity_district_session.tres") as DEF_EntityTemplate
	session.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var prefab: PackedScene = load(
		"res://content/domains/npc/entities/district_npc.tscn") as PackedScene
	var merchant: E_DistrictNpc = prefab.instantiate() as E_DistrictNpc
	merchant.name = "Trader"
	merchant.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"Trader")
	_actors.add_child(merchant)
	merchant.owner = _level
	var inspection_slot: Entity = merchant.get_node("InspectionParcelSlot") as Entity
	inspection_slot.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"merchant_inspection_slot")
	var publications: Array[StringName] = []
	_world.entity_added.connect(func(actor: Entity) -> void:
		if actor == merchant:
			publications.append((actor.get_component(C_NpcIdentity) as C_NpcIdentity).npc_id))
	var previous_world: World = ECS.world
	add_child(_level)
	var diagnostics: Array[String] = _world.identity_issues()
	for issue: EntityBuildPlan.Issue in _world.composition_issues():
		diagnostics.append("%s: %s" % [issue.code, issue.message])
	assert_false(_world.initialization_failed(), str(diagnostics))
	if _world.initialization_failed():
		return
	assert_eq(_world.registrations(), 3)
	assert_eq(publications, [&"npc/8"])
	assert_eq(ECS.world, previous_world)
	var committed: C_District = session.get_component(C_District) as C_District
	assert_eq(committed.people.size(), district.definition.profiles.size())
	assert_eq(committed.next_person, 1 + committed.people.size())
	assert_true(district.people.is_empty(), "Scene recipes remain immutable")
	assert_true(committed.people[7].profile.merchant)
#endregion
