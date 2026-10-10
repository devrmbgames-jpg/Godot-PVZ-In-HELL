extends GutTest
## Direct authoring preserves native registration, scene serialization and recipe ownership.

const _IMPACT: EntityTrait = preload(
	"res://content/domains/combat/authoring/et_impact_capture.tres"
)
const _INHERITED: PackedScene = preload(
	"res://tests/fixtures/refactoring_v2/direct_traits_box.tscn"
)


#region Direct authoring acceptance
func test_raw_and_project_entity_with_empty_traits_keep_native_recipes() -> void:
	for actor: Entity in [Entity.new(), E_TraitedEntity.new()]:
		var world: World = World.new()
		add_child(world)
		actor.component_resources = [C_Health.new()]
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			world,
			"fixture/empty",
		)
		assert_true(EntityCompositionService.try_register(context))
		assert_true(actor.has_component(C_Health))
		assert_true(EntityCompositionService.composition_ready(actor))
		world.purge(false)
		world.free()
	ECS.world = null


func test_native_prefab_roundtrip_assigns_impact_without_template_or_metadata() -> void:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_TraitedEntity as Script)
	var actor: E_TraitedEntity = body as Node as E_TraitedEntity
	actor.traits = [_IMPACT]
	actor.name = "DirectPrefab"
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(actor), OK)
	actor.free()
	var path: String = "res://".path_join(".artifacts/direct_traits/new_prefab.tscn")
	assert_eq(ResourceSaver.save(scene, path), OK)
	var loaded_resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var reloaded: PackedScene = loaded_resource as PackedScene
	var instance: E_TraitedEntity = reloaded.instantiate() as E_TraitedEntity
	assert_eq(instance.traits.size(), 1)
	assert_false(instance.has_meta(&"entity_composition"))
	var world: World = World.new()
	add_child(world)
	var publications: Array[Entity] = []
	world.entity_added.connect(
		func(entity: Entity) -> void:
			publications.append(entity),
	)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		instance,
		world,
		"fixture/direct",
	)
	assert_true(EntityCompositionService.try_register(context))
	assert_true(instance.has_component(C_ImpactInbox))
	assert_eq(publications, [instance])
	assert_false(EntityCompositionService.try_register(context))
	assert_eq(publications, [instance])
	world.purge(false)
	world.free()
	ECS.world = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_inherited_prefab_keeps_direct_traits_and_physical_root() -> void:
	var actor: E_TraitedEntity = autofree(_INHERITED.instantiate()) as E_TraitedEntity
	assert_true(actor as Node is RigidBody3D)
	assert_eq(actor.traits, [_IMPACT])
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		null,
		"fixture/inherited",
	)
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_true(plan.valid())
	var inboxes: int = 0
	for recipe: Component in plan.component_recipes:
		if recipe is C_ImpactInbox:
			inboxes += 1
	assert_eq(inboxes, 1)
#endregion
