extends GutTest
## Verifies detached diagnostics against native editable actors without registration or readiness.

const _LEVEL: PackedScene = preload("res://tests/fixtures/refactoring_v2/authoring_level.tscn")
const _CYCLE: String = "res://tests/fixtures/refactoring_v2/authoring_cycle_scene.tscn"


#region Detached authoring acceptance
## The native scene retains visible physical actors; preview installs no live Components or World.
func test_native_level_preview_keeps_physics_and_registration_detached() -> void:
	var level: Node3D = autofree(_LEVEL.instantiate()) as Node3D
	var world_before: World = ECS.world
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(level)
	assert_true(report.valid, JSON.stringify(report))
	assert_gte((report.actors as Array).size(), 3)
	assert_same(ECS.world, world_before)
	for path: String in ["Resident", "Trader", "Box"]:
		var actor: Entity = level.get_node(path) as Entity
		assert_true(actor as Node is RigidBody3D, path)
		assert_false(actor.is_inside_tree())
		assert_false(actor.is_node_ready())
		assert_eq(actor.ecs_id, 0)
		assert_true(actor.components.is_empty())
		assert_true(actor.relationships.is_empty())
		assert_false(EntityCompositionService.recipes_prepared(actor))
		assert_gt(actor.find_children("*", "MeshInstance3D", true, false).size(), 0, path)
		assert_gt(actor.find_children("*", "CollisionShape3D", true, false).size(), 0, path)


## Duplicate local IDs abort the scene report before any native publication.
func test_duplicated_instance_identity_is_actionable() -> void:
	var level: Node = autofree(_LEVEL.instantiate()) as Node
	level.get_node("Box").set_meta(PlacedIdentityRules.LOCAL_ID_META, &"resident")
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(level)
	assert_false(report.valid)
	assert_string_contains(JSON.stringify(report.issues), "Duplicate placed identity")
	assert_true((level.get_node("Resident") as Entity).components.is_empty())


## A new/imported level must declare a scope instead of silently behaving as a prefab.
func test_missing_level_identity_is_reported() -> void:
	var level: Node = autofree(_LEVEL.instantiate()) as Node
	level.remove_meta(PlacedIdentityRules.WORLD_ID_META)
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(level)
	assert_false(report.valid)
	assert_string_contains(JSON.stringify(report.issues), "persistent_world_id")


## Named Home/Workplace-style endpoints use the runtime binding validation and keep provenance.
func test_missing_named_endpoint_is_actionable_without_live_relationships() -> void:
	var actor: Entity = autofree(Entity.new()) as Entity
	var binding: EntityInitialBinding = EntityInitialBinding.new()
	binding.endpoint = &"Home"
	binding.relation = R_SlotMountedOn.new()
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"home_binding"
	capability.initial_bindings = [binding]
	var template: DEF_EntityTemplate = DEF_EntityTemplate.new()
	template.traits = [capability]
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = template
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(actor)
	assert_false(report.valid)
	assert_string_contains(JSON.stringify(report.actors), "Home")
	assert_true(actor.relationships.is_empty())


## Provider conflicts from the runtime compiler remain visible in the Advanced report.
func test_conflicting_template_reports_component_provider_provenance() -> void:
	var actor: Entity = autofree(Entity.new()) as Entity
	actor.name = "ConflictingActor"
	actor.component_resources = [C_Health.new()]
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"conflicting_health"
	capability.component_recipes = [C_Health.new()]
	var template: DEF_EntityTemplate = DEF_EntityTemplate.new()
	template.traits = [capability]
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = template
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(actor)
	assert_false(report.valid)
	assert_string_contains(JSON.stringify(report.actors), "duplicate_provider")
	assert_string_contains(JSON.stringify(report.actors), "conflicting_health")
	assert_true(actor.components.is_empty())


## A missing structural node is diagnosed before engine setup rather than repaired by preview.
func test_missing_required_node_is_reported_without_scene_repair() -> void:
	var actor: Entity = autofree(Entity.new()) as Entity
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"requires_marker"
	capability.required_nodes = [NodePath("Home")]
	var template: DEF_EntityTemplate = DEF_EntityTemplate.new()
	template.traits = [capability]
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = template
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(actor)
	assert_false(report.valid)
	assert_string_contains(JSON.stringify(report.actors), "missing_node")
	assert_null(actor.get_node_or_null("Home"))


## Dependency inspection must reject Scene→Template→Scene before recursive Resource loading.
func test_native_scene_template_cycle_is_rejected_before_load() -> void:
	var issues: PackedStringArray = EntityAuthoringPreviewRules.dependency_issues(_CYCLE)
	assert_eq(issues.size(), 1)
	assert_string_contains(issues[0], "authoring_cycle_scene.tscn")
	assert_string_contains(issues[0], "authoring_cycle_template.tres")


## Reused native prefab assets are acyclic and remain legal.
func test_reused_prefab_dependencies_are_acyclic() -> void:
	var issues: PackedStringArray = EntityAuthoringPreviewRules.dependency_issues(
		_LEVEL.resource_path
	)
	assert_true(issues.is_empty(), str(issues))


## A disposable snapshot preserves external Trait edits without writing the original asset.
func test_snapshot_bundles_unsaved_external_template_values() -> void:
	var actor: Entity = autofree(
		load("res://content/domains/interaction/entities/box.tscn").instantiate()
	) as Entity
	var authoring: EntityAuthoring = actor.get_meta(EntityCompositionService.AUTHORING_META) \
			as EntityAuthoring
	var template: DEF_EntityTemplate = ResourceLoader.load(
		authoring.entity_template.resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as DEF_EntityTemplate
	var original_path: String = template.resource_path
	var original_text: String = FileAccess.get_file_as_string(original_path)
	template.traits[0].required_nodes = [NodePath("UnsavedMarkerRequirement")]
	authoring = authoring.duplicate() as EntityAuthoring
	authoring.entity_template = template
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var snapshot: PackedScene = EntityAuthoringSnapshotRules.capture(actor)
	assert_not_null(snapshot)
	var scene_file: String = "res://".path_join(".artifacts/authoring_snapshot_check.tscn")
	assert_eq(ResourceSaver.save(snapshot, scene_file), OK)
	var loaded: PackedScene = ResourceLoader.load(
		scene_file,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as PackedScene
	var detached: Node = autofree(loaded.instantiate()) as Node
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(detached)
	assert_false(report.valid)
	assert_string_contains(JSON.stringify(report.actors), "UnsavedMarkerRequirement")
	assert_eq(FileAccess.get_file_as_string(original_path), original_text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_file))
#endregion


#region Snapshot provenance acceptance
## Field configuration retains authored Trait paths after a real native snapshot save/reload.
func test_snapshot_field_provenance_uses_original_authored_trait_paths() -> void:
	var level: Node = autofree(_LEVEL.instantiate()) as Node
	var resident: Entity = level.get_node("Resident") as Entity
	resident.component_resources = resident.component_resources.duplicate()
	resident.component_resources.append(C_NpcIdentity.new())
	var authored_template: DEF_EntityTemplate = load(
		"res://content/domains/npc/definitions/def_entity_district_trader.tres"
	) as DEF_EntityTemplate
	var template: DEF_EntityTemplate = DEF_EntityTemplate.new()
	for capability: EntityTrait in authored_template.traits:
		if capability is ET_NpcBrainState:
			template.traits.append(capability)
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = template
	authoring.definitions[&"npc_profile"] = DEF_NpcProfile.new()
	resident.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var snapshot: PackedScene = EntityAuthoringSnapshotRules.capture(level)
	var scene_file: String = "res://".path_join(".artifacts/authoring_provenance_check.tscn")
	assert_eq(ResourceSaver.save(snapshot, scene_file), OK)
	var loaded: PackedScene = ResourceLoader.load(
		scene_file,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as PackedScene
	var detached: Node = autofree(loaded.instantiate()) as Node
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(detached)
	assert_true(report.valid, JSON.stringify(report))
	var configured_fields: int = 0
	for actor_report: Dictionary in report.actors:
		for provider: Dictionary in actor_report.providers:
			for field: Variant in provider.fields:
				var source: String = String(provider.fields[field])
				assert_false(source.contains(scene_file), source)
				assert_false(source.contains(".artifacts/"), source)
				if source.begins_with("trait:npc_brain_state:"):
					configured_fields += 1
					assert_string_contains(source, "def_entity_district_")
	assert_gt(configured_fields, 0, "Native NPC fixture must exercise Trait field configuration")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene_file))
#endregion
