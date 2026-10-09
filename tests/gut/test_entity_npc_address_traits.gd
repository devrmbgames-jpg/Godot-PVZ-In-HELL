extends GutTest
## Verifies address initial-field composition and whole-batch rejection before population mutation.

const _ADDRESS: PackedScene = preload("res://content/domains/npc/entities/npc_address.tscn")
const _TEMPLATE: DEF_EntityTemplate = preload(
	"res://content/domains/npc/definitions/def_entity_npc_address.tres"
)

var _root: Node3D
var _world: World
var _district: C_District


#region Isolated district construction
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var district_origin: Node3D = Node3D.new()
	district_origin.name = "District"
	_root.add_child(district_origin)
	var first: DEF_DistrictPlace = DEF_DistrictPlace.new()
	first.key = &"home_first"
	first.kind = DEF_DistrictPlace.Kind.HOME
	first.display_name = "First address"
	first.position = Vector3(2, 0, 3)
	var second: DEF_DistrictPlace = DEF_DistrictPlace.new()
	second.key = &"home_second"
	second.kind = DEF_DistrictPlace.Kind.HOME
	second.display_name = "Second address"
	second.position = Vector3(-2, 0, 3)
	var definition: DEF_District = DEF_District.new()
	definition.places = [first, second]
	var session: Entity = Entity.new()
	_district = C_District.new()
	_district.definition = definition
	session.component_resources = [_district, C_DayCycle.new()]
	EntityCompositionFixture.register(_world, session)
	_district = session.get_component(C_District) as C_District
	_world.add_observer(O_DistrictLifecycle.new())


func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null
#endregion


#region Production address Template
## Same generic Trait supports two addresses without a new ET script or source recipe mutation.
func test_address_instance_fields_compile_fresh_scene_data() -> void:
	var first: Entity = autofree(_ADDRESS.instantiate()) as Entity
	var second: Entity = autofree(_ADDRESS.instantiate()) as Entity
	assert_same(EntityCompositionService.authoring_for(first).entity_template, _TEMPLATE)
	var first_context: EntitySpawnContext = EntityCompositionService.context_for(
		first,
		_world,
		"fixture/address/first",
	)
	first_context.initial_fields[C_NpcAddress as Script] = { &"address_id": &"first" }
	var second_context: EntitySpawnContext = EntityCompositionService.context_for(
		second,
		_world,
		"fixture/address/second",
	)
	second_context.initial_fields[C_NpcAddress as Script] = { &"address_id": &"second" }
	var first_plan: EntityBuildPlan = EntityCompositionService.build_plan(first_context)
	var second_plan: EntityBuildPlan = EntityCompositionService.build_plan(second_context)
	assert_true(first_plan.valid())
	assert_true(second_plan.valid())
	var first_address: C_NpcAddress = _address_recipe(first_plan.component_recipes)
	var second_address: C_NpcAddress = _address_recipe(second_plan.component_recipes)
	assert_eq(first_address.address_id, &"first")
	assert_eq(second_address.address_id, &"second")
	first_address.address_id = &"changed"
	assert_eq(second_address.address_id, &"second")
	assert_eq(_address_recipe(first.component_resources).address_id, &"")
	assert_true(first.components.is_empty())


## Native publication observes complete IDs/presentation/pose once for every validated home.
func test_address_batch_publishes_complete_instance_data_once() -> void:
	var published: Array[StringName] = []
	var texts: Array[String] = []
	var positions: Array[Vector3] = []
	_world.entity_added.connect(
		func(actor: Entity) -> void:
			if actor.has_component(C_NpcAddress):
				published.append((actor.get_component(C_NpcAddress) as C_NpcAddress).address_id)
				texts.append((actor.get_node("Address") as Label3D).text)
				positions.append((actor as Node as Node3D).global_position),
	)
	assert_true(DistrictPopulationService.initialize())
	assert_eq(published, [&"home_first", &"home_second"])
	assert_eq(texts, ["First address", "Second address"])
	assert_eq(positions, [Vector3(2, 0, 3), Vector3(-2, 0, 3)])
	assert_eq(_world.query.with_all([C_NpcAddress]).execute().size(), 2)
	assert_true(_district.people.is_empty())


## A conflicting current Template rejects the entire address batch without roster/registry effects.
func test_address_conflict_rejects_batch_before_population_mutation() -> void:
	var conflicting: EntityTrait = EntityTrait.new()
	conflicting.trait_id = &"fixture_duplicate_address"
	conflicting.component_recipes = [C_NpcAddress.new()]
	var before_count: int = _world.entities.size()
	var before_next: int = _district.next_person
	var published: Array[Entity] = []
	_world.entity_added.connect(
		func(actor: Entity) -> void:
			published.append(actor),
	)
	_TEMPLATE.traits.append(conflicting)
	var initialized: bool = DistrictPopulationService.initialize()
	_TEMPLATE.traits.erase(conflicting)
	assert_false(initialized)
	assert_true(published.is_empty())
	assert_eq(_world.entities.size(), before_count)
	assert_eq(_world.entity_id_registry.size(), before_count)
	assert_true(_district.people.is_empty())
	assert_eq(_district.next_person, before_next)
	assert_eq(_district.prepared_morning, 0)
#endregion


#region Fresh address recipe lookup
func _address_recipe(recipes: Array[Component]) -> C_NpcAddress:
	for recipe: Component in recipes:
		if recipe is C_NpcAddress:
			return recipe as C_NpcAddress
	return null
#endregion


#region Atomic whole population construction
func _population_profiles(scene_paths: PackedStringArray) -> void:
	var portal: DEF_DistrictPlace = DEF_DistrictPlace.new()
	portal.key = &"portal"
	portal.kind = DEF_DistrictPlace.Kind.PORTAL
	_district.definition.places.append(portal)
	var authored: DEF_District = load(
		"res://content/domains/npc/definitions/def_district_default.tres"
	) as DEF_District
	for scene_path: String in scene_paths:
		var profile: DEF_NpcProfile = authored.profiles[0].duplicate() as DEF_NpcProfile
		profile.npc_scene_path = scene_path
		_district.definition.profiles.append(profile)


## A later invalid NPC root rejects earlier valid bodies and addresses before any publication.
func test_invalid_later_body_rejects_population_before_registry_roster_or_pose_changes() -> void:
	_population_profiles(
		PackedStringArray(
			[
				"res://content/domains/npc/entities/district_npc.tscn",
				"res://content/domains/npc/entities/npc_address.tscn",
			]
		)
	)
	var before_count: int = _world.entities.size()
	var before_children: int = _root.get_child_count()
	var before_next: int = _district.next_person
	var publications: Array[Entity] = []
	_world.entity_added.connect(
		func(actor: Entity) -> void:
			publications.append(actor),
	)
	assert_false(DistrictPopulationService.initialize())
	assert_true(publications.is_empty())
	assert_eq(_world.entities.size(), before_count)
	assert_eq(_world.entity_id_registry.size(), before_count)
	assert_eq(_root.get_child_count(), before_children)
	assert_true(_district.people.is_empty())
	assert_eq(_district.next_person, before_next)
	assert_eq(_district.prepared_morning, 0)


## A body Trait conflict aborts already prepared addresses with no partial population commit.
func test_body_provider_conflict_discards_addresses_and_preserves_person_sequence() -> void:
	_population_profiles(
		PackedStringArray(["res://content/domains/npc/entities/district_npc.tscn"])
	)
	var template: DEF_EntityTemplate = load(
		"res://content/domains/npc/definitions/def_entity_district_npc.tres"
	) as DEF_EntityTemplate
	var conflict: EntityTrait = EntityTrait.new()
	conflict.trait_id = &"duplicate_population_inventory"
	conflict.component_recipes = [C_Inventory.new()]
	var before_count: int = _world.entities.size()
	template.traits.append(conflict)
	var accepted: bool = DistrictPopulationService.initialize()
	template.traits.erase(conflict)
	assert_false(accepted)
	assert_eq(_world.entities.size(), before_count)
	assert_eq(_world.query.with_all([C_NpcAddress]).execute().size(), 0)
	assert_eq(_world.query.with_all([C_NpcIdentity]).execute().size(), 0)
	assert_true(_district.people.is_empty())
	assert_eq(_district.next_person, 1)


## Accepted population publishes complete roster/body data once, and initialize retry is idempotent.
func test_complete_population_commit_and_retry_publish_every_actor_once() -> void:
	_population_profiles(
		PackedStringArray(
			[
				"res://content/domains/npc/entities/district_npc.tscn",
				"res://content/domains/npc/entities/district_npc.tscn",
			]
		)
	)
	var publications: Array[Entity] = []
	_world.entity_added.connect(
		func(actor: Entity) -> void:
			publications.append(actor)
			if actor.has_component(C_NpcIdentity):
				var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
				assert_not_null(NpcPopulationQueries.person_for(identity.npc_id))
				assert_true(actor.has_component(C_Inventory))
				assert_true(actor.has_component(C_Hunger))
				assert_true(actor.has_component(C_InteractionActionSet)),
	)
	assert_true(DistrictPopulationService.initialize())
	assert_eq(publications.size(), 4)
	assert_eq(_district.people.size(), 2)
	assert_eq(_district.next_person, 3)
	assert_true(DistrictPopulationService.initialize())
	assert_eq(publications.size(), 4)
	assert_eq(_district.people.size(), 2)
	assert_eq(_world.query.with_all([C_NpcAddress]).execute().size(), 2)
	assert_eq(_world.query.with_all([C_NpcIdentity]).execute().size(), 2)
#endregion
