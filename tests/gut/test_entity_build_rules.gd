extends GutTest
## Exercises pure composition contracts before any registration or ready publication.


## Data-only Profile fixture; no live install operation or mutable shared gameplay model.
class ConfiguredTrait extends EntityTrait:
	## Explicit fields returned to the compiler, keyed by their required Component provider.
	var fields: Dictionary[Script, Dictionary] = { }


	## Supplies exact initial values without touching the scene/World or original provider.
	func configuration_for(_context: EntitySpawnContext) -> Dictionary[Script, Dictionary]:
		return fields


#region Enumerated factory instance fields
## Only declared fields merge into fresh providers with factory provenance; sources stay intact.
func test_factory_fields_require_trait_policy_and_preserve_profile_defaults() -> void:
	var capability: ConfiguredTrait = ConfiguredTrait.new()
	capability.trait_id = &"health"
	capability.fields[C_Health as Script] = { &"base": 80.0, &"value": 80.0 }
	capability.initial_field_names[C_Health as Script] = PackedStringArray(["current"])
	var context: EntitySpawnContext = _context()
	context.initial_fields[C_Health as Script] = { &"current": 37.0 }
	var source: C_Health = C_Health.new()
	var original_health: float = source.current
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[source],
		[],
		context,
	)
	assert_true(plan.valid())
	var built: C_Health = plan.component_recipes[0] as C_Health
	assert_eq(built.current, 37.0)
	assert_eq(built.base, 80.0)
	assert_eq(built.value, 80.0)
	assert_eq(plan.field_provenance[C_Health as Script][&"current"], "context:initial_fields")
	assert_eq(source.current, original_health)


## Undeclared factory values and wrong declared value types reject before preparing any data.
func test_factory_fields_cannot_write_undeclared_or_incompatible_state() -> void:
	var capability: EntityTrait = _trait(&"health", [])
	capability.initial_field_names[C_Health as Script] = PackedStringArray(["current"])
	var context: EntitySpawnContext = _context()
	context.initial_fields[C_Health as Script] = { &"base": 80.0 }
	var forbidden: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[C_Health.new()],
		[],
		context,
	)
	assert_false(forbidden.valid())
	assert_eq(_issue_codes(forbidden), [&"unauthorized_initial_field"])
	assert_true(forbidden.component_recipes.is_empty())
	context.initial_fields[C_Health as Script] = { &"current": "wrong type" }
	var incompatible: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[C_Health.new()],
		[],
		context,
	)
	assert_false(incompatible.valid())
	assert_eq(_issue_codes(incompatible), [&"incompatible_initial_field"])


## A factory cannot become the second writer of a field already declared by a Profile Trait.
func test_factory_fields_do_not_silently_replace_profile_field_writers() -> void:
	var capability: ConfiguredTrait = ConfiguredTrait.new()
	capability.trait_id = &"health"
	capability.fields[C_Health as Script] = { &"current": 50.0 }
	capability.initial_field_names[C_Health as Script] = PackedStringArray(["current"])
	var context: EntitySpawnContext = _context()
	context.initial_fields[C_Health as Script] = { &"current": 50.0 }
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[C_Health.new()],
		[],
		context,
	)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"duplicate_initial_field"])
	assert_true(plan.component_recipes.is_empty())
	assert_eq(plan.issues[0].source, "context:initial_fields")


## Enumerated mutable records/typed containers still belong to each fresh Component aggregate.
func test_factory_field_containers_are_isolated_between_builds() -> void:
	var capability: EntityTrait = _trait(&"district", [])
	capability.initial_field_names[C_District as Script] = PackedStringArray(["people"])
	var people: Array[NpcRecord] = [NpcRecord.new()]
	people[0].npc_id = &"factory_person"
	var context: EntitySpawnContext = _context()
	context.initial_fields[C_District as Script] = { &"people": people }
	var first: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[C_District.new()],
		[],
		context,
	)
	var second: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[C_District.new()],
		[],
		context,
	)
	assert_true(first.valid())
	assert_true(second.valid())
	var first_district: C_District = first.component_recipes[0] as C_District
	var second_district: C_District = second.component_recipes[0] as C_District
	first_district.people[0].npc_id = &"changed"
	assert_eq(second_district.people[0].npc_id, &"factory_person")
	assert_eq(people[0].npc_id, &"factory_person")
	assert_ne(first_district.people[0], people[0])
#endregion


#region Declared Profile field configuration
## Profile configuration changes fresh recipes without replacing scene engine/data providers.
func test_explicit_profile_fields_preserve_provider_and_are_order_independent() -> void:
	var health: C_Health = C_Health.new()
	health.current = 9.0
	var maximum: ConfiguredTrait = ConfiguredTrait.new()
	maximum.trait_id = &"maximum"
	maximum.fields[C_Health as Script] = { &"base": 80.0, &"value": 80.0 }
	var current: ConfiguredTrait = ConfiguredTrait.new()
	current.trait_id = &"current"
	current.fields[C_Health as Script] = { &"current": 37.0 }
	var template: Array[EntityTrait] = _template([maximum, current])
	var plan: EntityBuildPlan = EntityBuildRules.compile(template, [health], [], _context())
	template.reverse()
	var reverse: EntityBuildPlan = EntityBuildRules.compile(template, [health], [], _context())
	assert_true(plan.valid())
	assert_true(reverse.valid())
	assert_eq(plan.provenance[C_Health as Script], "scene")
	assert_eq(plan.field_provenance, reverse.field_provenance)
	var built: C_Health = plan.component_recipes[0] as C_Health
	assert_eq(built.current, 37.0)
	assert_eq(built.base, 80.0)
	assert_eq(built.value, 80.0)
	assert_eq((reverse.component_recipes[0] as C_Health).current, 37.0)
	assert_eq(health.current, 9.0)


## Two declarations for one exact field fail even when the proposed values happen to agree.
func test_duplicate_profile_field_writer_is_rejected_without_last_trait_wins() -> void:
	var first: ConfiguredTrait = ConfiguredTrait.new()
	first.trait_id = &"first"
	first.fields[C_Health as Script] = { &"current": 50.0 }
	var second: ConfiguredTrait = ConfiguredTrait.new()
	second.trait_id = &"second"
	second.fields[C_Health as Script] = { &"current": 50.0 }
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([second, first]),
		[C_Health.new()],
		[],
		_context(),
	)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"duplicate_initial_field"])
	assert_string_contains(plan.issues[0].message, "trait:first")
	assert_string_contains(plan.issues[0].message, "trait:second")
	assert_true(plan.component_recipes.is_empty())


## Missing providers, private/runtime fields and wrong value types are configuration errors.
func test_invalid_profile_fields_fail_before_property_assignment_or_registration() -> void:
	var capability: ConfiguredTrait = ConfiguredTrait.new()
	capability.trait_id = &"invalid"
	capability.fields[C_Health as Script] = {
		&"current": "wrong float",
		&"parent": Entity.new(),
		&"definition": DEF_ImpactProfile.new(),
		&"_private": 1,
	}
	var forbidden_parent: Entity = capability.fields[C_Health as Script][&"parent"] as Entity
	autofree(forbidden_parent)
	capability.fields[C_Inventory as Script] = { &"maximum_stacks": 2 }
	var source: C_Health = C_Health.new()
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[source],
		[],
		_context(),
	)
	assert_false(plan.valid())
	assert_has(_issue_codes(plan), &"missing_configuration_provider")
	assert_eq(_issue_codes(plan).count(&"incompatible_initial_field"), 2)
	assert_has(_issue_codes(plan), &"invalid_initial_field")
	assert_true(plan.component_recipes.is_empty())
	assert_null(source.parent)


## Typed container configuration keeps nested records isolated between compiled instances.
func test_configured_nested_records_are_copied_and_definitions_remain_shared() -> void:
	var capability: ConfiguredTrait = ConfiguredTrait.new()
	capability.trait_id = &"population"
	var person: NpcRecord = NpcRecord.new()
	person.npc_id = &"configured/person"
	person.profile = DEF_NpcProfile.new()
	var people: Array[NpcRecord] = [person]
	capability.fields[C_District as Script] = { &"people": people }
	var template: Array[EntityTrait] = _template([capability])
	var first: EntityBuildPlan = EntityBuildRules.compile(
		template,
		[C_District.new()],
		[],
		_context(),
	)
	var second: EntityBuildPlan = EntityBuildRules.compile(
		template,
		[C_District.new()],
		[],
		_context(),
	)
	assert_true(first.valid())
	assert_true(second.valid())
	var first_district: C_District = first.component_recipes[0] as C_District
	var second_district: C_District = second.component_recipes[0] as C_District
	assert_ne(first_district.people[0], person)
	assert_ne(first_district.people[0], second_district.people[0])
	assert_same(first_district.people[0].profile, person.profile)
	first_district.people[0].npc_id = &"changed"
	assert_eq(second_district.people[0].npc_id, &"configured/person")
	assert_eq(person.npc_id, &"configured/person")


## Same builtin Array type cannot hide incompatible typed element contracts.
func test_wrong_typed_configuration_container_is_rejected_before_copy() -> void:
	var capability: ConfiguredTrait = ConfiguredTrait.new()
	capability.trait_id = &"wrong_people"
	var wrong_people: Array[String] = ["not an NpcRecord"]
	capability.fields[C_District as Script] = { &"people": wrong_people }
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[C_District.new()],
		[],
		_context(),
	)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"incompatible_initial_field"])
	assert_true(plan.component_recipes.is_empty())
#endregion


#region Provider composition
## Scene-only intrinsic providers use the same compiler and receive independent recipes.
func test_scene_only_build_preserves_intrinsic_values_without_registering() -> void:
	var context: EntitySpawnContext = _context()
	var calendar: C_DayCycle = C_DayCycle.new()
	calendar.clock.elapsed_ticks = 19
	var previous_world: World = ECS.world
	var plan: EntityBuildPlan = EntityBuildRules.compile([], [calendar], [], context)
	assert_true(plan.valid())
	assert_eq(plan.component_recipes.size(), 1)
	var calendar_script: Script = calendar.get_script() as Script
	assert_eq(plan.provenance[calendar_script], "scene")
	var built: C_DayCycle = plan.component_recipes[0] as C_DayCycle
	assert_eq(built.clock.elapsed_ticks, 19)
	assert_ne(built, calendar)
	assert_ne(built.clock, calendar.clock)
	assert_eq(context.actor.components.size(), 0)
	assert_eq(context.actor.id, "")
	assert_eq(ECS.world, previous_world)


## Trait order does not select providers or alter the resulting canonical recipe order.
func test_trait_order_is_irrelevant_and_requirements_see_all_providers() -> void:
	var context: EntitySpawnContext = _context()
	var resistance: EntityTrait = _trait(&"resistance", [C_DamageResistance.new()])
	resistance.required_components = [C_DayCycle]
	var time_trait: EntityTrait = _trait(&"time", [C_DayCycle.new()])
	var template: Array[EntityTrait] = _template([resistance, time_trait])
	var forward: EntityBuildPlan = EntityBuildRules.compile(template, [], [], context)
	template.reverse()
	var reverse: EntityBuildPlan = EntityBuildRules.compile(template, [], [], context)
	assert_true(forward.valid())
	assert_true(reverse.valid())
	assert_eq(_scripts(forward), _scripts(reverse))
	assert_eq(forward.provenance, reverse.provenance)
	assert_eq(forward.component_recipes.size(), 2)


## Scene, code and Trait collisions fail explicitly, retaining both sources in diagnostics.
func test_duplicate_scene_code_and_trait_providers_fail_before_materialization() -> void:
	var context: EntitySpawnContext = _context()
	var capability: EntityTrait = _trait(&"time", [C_DayCycle.new()])
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[C_DayCycle.new()],
		[C_DayCycle.new()],
		context,
	)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"duplicate_provider", &"duplicate_provider"])
	assert_eq(plan.component_recipes.size(), 0)
	assert_eq(plan.bindings.size(), 0)
	assert_string_contains(plan.issues[0].message, "scene")
	assert_string_contains(plan.issues[0].message, "code")
	assert_eq(plan.issues[1].trait_id, &"time")
	assert_eq(plan.issues[1].instance_path, "fixture/actor")
	assert_eq(context.actor.components.size(), 0)


## Two capability identities cannot silently select the last declaration.
func test_duplicate_trait_identity_is_a_configuration_error() -> void:
	var first: EntityTrait = _trait(&"repeated", [C_DayCycle.new()])
	var second: EntityTrait = _trait(&"repeated", [C_DamageResistance.new()])
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([first, second]),
		[],
		[],
		_context(),
	)
	assert_false(plan.valid())
	assert_has(_issue_codes(plan), &"duplicate_trait")
	assert_eq(plan.component_recipes.size(), 0)


## Root/node/Component requirements provide actionable owner and placed-instance diagnostics.
func test_missing_requirements_and_incompatible_root_do_not_mutate_instance() -> void:
	var capability: EntityTrait = _trait(&"physical", [])
	capability.required_root_class = &"RigidBody3D"
	capability.required_nodes = [NodePath("MissingMarker")]
	capability.required_components = [C_DamageResistance]
	var context: EntitySpawnContext = _context()
	var plan: EntityBuildPlan = EntityBuildRules.compile(_template([capability]), [], [], context)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"incompatible_root", &"missing_node", &"missing_component"])
	for issue: EntityBuildPlan.Issue in plan.issues:
		assert_eq(issue.trait_id, &"physical")
		assert_eq(issue.instance_path, "fixture/actor")
	assert_eq(context.actor.get_child_count(), 0)
	assert_eq(context.actor.component_resources.size(), 0)


## Typed tuning stays shared immutable while nested records are fresh in both compiled builds.
func test_two_compiled_builds_isolate_nested_state_and_share_definitions() -> void:
	var district: C_District = C_District.new()
	district.definition = DEF_District.new()
	var person: NpcRecord = NpcRecord.new()
	person.profile = DEF_NpcProfile.new()
	person.npc_id = &"fixture/person"
	district.people = [person]
	var template: Array[EntityTrait] = _template([_trait(&"population", [district])])
	var first: EntityBuildPlan = EntityBuildRules.compile(template, [], [], _context())
	var second: EntityBuildPlan = EntityBuildRules.compile(template, [], [], _context())
	assert_true(first.valid())
	assert_true(second.valid())
	var first_district: C_District = first.component_recipes[0] as C_District
	var second_district: C_District = second.component_recipes[0] as C_District
	assert_eq(first_district.definition, district.definition)
	assert_eq(first_district.people[0].profile, person.profile)
	assert_ne(first_district.people[0], second_district.people[0])
	first_district.people[0].npc_id = &"changed"
	assert_eq(person.npc_id, &"fixture/person")
	assert_eq(second_district.people[0].npc_id, &"fixture/person")
#endregion


#region Binding intents
## An initial binding is fresh data, never a live Relationship during compilation.
func test_candidate_binding_is_valid_without_registration_or_live_relationships() -> void:
	var context: EntitySpawnContext = _context()
	var target: Entity = autofree(Entity.new()) as Entity
	context.candidate_actors = [context.actor, target]
	context.bindings[&"support"] = target
	var intent: EntityInitialBinding = _binding(&"support")
	var capability: EntityTrait = _trait(&"mounted", [])
	capability.initial_bindings = [intent]
	var plan: EntityBuildPlan = EntityBuildRules.compile(_template([capability]), [], [], context)
	assert_true(plan.valid())
	assert_eq(plan.bindings.size(), 1)
	assert_eq(plan.bindings[0].target, target)
	assert_ne(plan.bindings[0].relation, intent.relation)
	assert_eq(context.actor.relationships.size(), 0)
	assert_eq(target.relationships.size(), 0)


## Absent required bindings fail; an explicitly optional endpoint is deliberately omitted.
func test_required_and_optional_absent_bindings_have_distinct_contracts() -> void:
	var intent: EntityInitialBinding = _binding(&"support")
	var capability: EntityTrait = _trait(&"mounted", [])
	capability.initial_bindings = [intent]
	var template: Array[EntityTrait] = _template([capability])
	var required_plan: EntityBuildPlan = EntityBuildRules.compile(template, [], [], _context())
	assert_false(required_plan.valid())
	assert_eq(_issue_codes(required_plan), [&"missing_binding"])
	intent.optional = true
	var optional_plan: EntityBuildPlan = EntityBuildRules.compile(template, [], [], _context())
	assert_true(optional_plan.valid())
	assert_eq(optional_plan.bindings.size(), 0)


## A valid Entity outside the explicit candidate set/World is still an invalid endpoint.
func test_foreign_binding_is_rejected_without_touching_the_endpoint() -> void:
	var context: EntitySpawnContext = _context()
	var foreign: Entity = autofree(Entity.new()) as Entity
	context.bindings[&"support"] = foreign
	var capability: EntityTrait = _trait(&"mounted", [])
	capability.initial_bindings = [_binding(&"support")]
	var plan: EntityBuildPlan = EntityBuildRules.compile(_template([capability]), [], [], context)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"foreign_binding"])
	assert_eq(plan.bindings.size(), 0)
	assert_eq(foreign.components.size(), 0)
	assert_eq(foreign.relationships.size(), 0)


## Two endpoint aliases cannot contribute the same Relationship/Entity pair twice.
func test_duplicate_relationship_provider_fails_even_with_different_endpoint_names() -> void:
	var context: EntitySpawnContext = _context()
	var target: Entity = autofree(Entity.new()) as Entity
	context.candidate_actors = [target]
	context.bindings[&"first"] = target
	context.bindings[&"second"] = target
	var first: EntityTrait = _trait(&"first", [])
	first.initial_bindings = [_binding(&"first")]
	var second: EntityTrait = _trait(&"second", [])
	second.initial_bindings = [_binding(&"second")]
	var plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([second, first]),
		[],
		[],
		context,
	)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"duplicate_binding"])
	assert_eq(plan.bindings.size(), 0)


## Factory bindings carry context provenance and remain fresh/uninstalled during compilation.
func test_factory_binding_intent_uses_same_pure_validation_and_fresh_recipe() -> void:
	var context: EntitySpawnContext = _context()
	var target: Entity = autofree(Entity.new()) as Entity
	context.candidate_actors = [target]
	context.bindings[&"source"] = target
	var intent: EntityInitialBinding = _binding(&"source")
	context.initial_bindings = [intent]
	var plan: EntityBuildPlan = EntityBuildRules.compile([], [], [], context)
	assert_true(plan.valid())
	assert_eq(plan.bindings.size(), 1)
	assert_eq(plan.bindings[0].source, "context")
	assert_same(plan.bindings[0].target, target)
	assert_ne(plan.bindings[0].relation, intent.relation)
	assert_true(context.actor.relationships.is_empty())
	assert_true(target.relationships.is_empty())


## Factory/Template duplicate bindings cannot become registration-order overrides.
func test_factory_and_trait_binding_collision_rejects_with_context_provenance() -> void:
	var context: EntitySpawnContext = _context()
	var target: Entity = autofree(Entity.new()) as Entity
	context.candidate_actors = [target]
	context.bindings[&"source"] = target
	context.initial_bindings = [_binding(&"source")]
	var capability: EntityTrait = _trait(&"source", [])
	capability.initial_bindings = [_binding(&"source")]
	var plan: EntityBuildPlan = EntityBuildRules.compile(_template([capability]), [], [], context)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"duplicate_binding"])
	assert_eq(plan.issues[0].source, "context")
	assert_eq(plan.issues[0].trait_id, &"")
	assert_true(plan.bindings.is_empty())
	assert_true(context.actor.relationships.is_empty())


## Missing required factory endpoints fail before any native registration or data copy.
func test_factory_missing_binding_is_configuration_failure() -> void:
	var context: EntitySpawnContext = _context()
	context.initial_bindings = [_binding(&"absent")]
	var plan: EntityBuildPlan = EntityBuildRules.compile([], [C_Inventory.new()], [], context)
	assert_false(plan.valid())
	assert_eq(_issue_codes(plan), [&"missing_binding"])
	assert_eq(plan.issues[0].source, "context")
	assert_true(plan.component_recipes.is_empty())
	assert_true(plan.bindings.is_empty())
	assert_eq(context.actor.id, "")


## Multiple targets of one Relationship type stay valid, matching GECS pair semantics.
func test_distinct_relationship_targets_are_valid() -> void:
	var context: EntitySpawnContext = _context()
	var first_target: Entity = autofree(Entity.new()) as Entity
	var second_target: Entity = autofree(Entity.new()) as Entity
	context.candidate_actors = [first_target, second_target]
	context.bindings[&"first"] = first_target
	context.bindings[&"second"] = second_target
	var capability: EntityTrait = _trait(&"mounted", [])
	capability.initial_bindings = [_binding(&"first"), _binding(&"second")]
	var plan: EntityBuildPlan = EntityBuildRules.compile(_template([capability]), [], [], context)
	assert_true(plan.valid())
	assert_eq(plan.bindings.size(), 2)
	assert_eq(plan.bindings[0].target, first_target)
	assert_eq(plan.bindings[1].target, second_target)
#endregion


#region Explicit build context
## Missing instance/identity produces configuration issues before any provider is materialized.
func test_instance_and_identity_are_required_boundary_inputs() -> void:
	var missing_instance: EntitySpawnContext = EntitySpawnContext.new()
	var first: EntityBuildPlan = EntityBuildRules.compile([], [], [], missing_instance)
	assert_false(first.valid())
	assert_eq(_issue_codes(first), [&"missing_instance"])
	var missing_id: EntitySpawnContext = _context()
	missing_id.actor_id = ""
	var second: EntityBuildPlan = EntityBuildRules.compile([], [], [], missing_id)
	assert_false(second.valid())
	assert_eq(_issue_codes(second), [&"missing_identity"])
	assert_eq(missing_id.actor.id, "")
#endregion


#region Whole-set rejection before native registration
## Duplicate Entity IDs reject both neighbours, without assigning either captured identity.
func test_duplicate_entity_ids_reject_whole_set_without_changing_instances() -> void:
	var first: EntitySpawnContext = _context()
	var second: EntitySpawnContext = _context()
	var first_plan: EntityBuildPlan = EntityBuildRules.compile([], [C_DayCycle.new()], [], first)
	var second_plan: EntityBuildPlan = EntityBuildRules.compile(
		[],
		[C_DamageResistance.new()],
		[],
		second,
	)
	assert_false(
		EntityBuildRules.validate_registration_batch([first, second], [first_plan, second_plan])
	)
	assert_has(_issue_codes(second_plan), &"duplicate_entity_id")
	assert_has(_issue_codes(first_plan), &"batch_rejected")
	assert_false(first_plan.valid())
	assert_false(second_plan.valid())
	assert_eq(first_plan.component_recipes.size(), 0)
	assert_eq(second_plan.component_recipes.size(), 0)
	assert_eq(first.actor.id, "")
	assert_eq(second.actor.id, "")


## An existing registry entry is preserved rather than invoking GECS collision replacement.
func test_registered_id_is_rejected_without_removing_existing_actor() -> void:
	var world: World = autofree(World.new()) as World
	var existing: Entity = autofree(Entity.new()) as Entity
	existing.id = "fixture/id"
	world.entities = [existing]
	world.entity_id_registry[existing.id] = existing
	var context: EntitySpawnContext = _context()
	context.world = world
	var plan: EntityBuildPlan = EntityBuildRules.compile([], [], [], context)
	assert_false(EntityBuildRules.validate_registration_batch([context], [plan]))
	assert_has(_issue_codes(plan), &"registered_entity_id")
	assert_eq(world.entities, [existing])
	assert_eq(world.entity_id_registry[existing.id], existing)
	assert_false(existing.is_queued_for_deletion())
	assert_eq(context.actor.id, "")


## Distinct Entity IDs cannot conceal a repeated stable placed identity.
func test_duplicate_stable_ids_reject_the_entire_prepared_set() -> void:
	var first: EntitySpawnContext = _context()
	var second: EntitySpawnContext = _context()
	second.actor_id = "fixture/second"
	var identity: C_AuthoredIdentity = C_AuthoredIdentity.new()
	identity.world_id = &"level"
	identity.local_id = &"actor"
	var first_plan: EntityBuildPlan = EntityBuildRules.compile([], [identity], [], first)
	var second_plan: EntityBuildPlan = EntityBuildRules.compile([], [identity], [], second)
	assert_false(
		EntityBuildRules.validate_registration_batch([first, second], [first_plan, second_plan])
	)
	assert_has(_issue_codes(second_plan), &"duplicate_stable_id")
	assert_false(first_plan.valid())
	assert_eq(identity.world_id, &"level")
	assert_eq(identity.local_id, &"actor")


## A binding's alleged unregistered candidate must have a plan in the committed set.
func test_candidate_endpoint_without_prepared_plan_aborts_batch() -> void:
	var context: EntitySpawnContext = _context()
	var endpoint: Entity = autofree(Entity.new()) as Entity
	context.candidate_actors = [endpoint]
	context.bindings[&"support"] = endpoint
	var capability: EntityTrait = _trait(&"mounted", [])
	capability.initial_bindings = [_binding(&"support")]
	var plan: EntityBuildPlan = EntityBuildRules.compile(_template([capability]), [], [], context)
	assert_true(plan.valid())
	assert_false(EntityBuildRules.validate_registration_batch([context], [plan]))
	assert_has(_issue_codes(plan), &"unprepared_binding")
	assert_eq(plan.bindings.size(), 0)
	assert_eq(context.actor.relationships.size(), 0)


## Whole-set fixup may reference a later-declared actor without a second registration path.
func test_prepared_endpoint_is_valid_independent_of_actor_order() -> void:
	var source: EntitySpawnContext = _context()
	var target: EntitySpawnContext = _context()
	target.actor_id = "fixture/target"
	source.candidate_actors = [source.actor, target.actor]
	source.bindings[&"support"] = target.actor
	var capability: EntityTrait = _trait(&"mounted", [])
	capability.initial_bindings = [_binding(&"support")]
	var source_plan: EntityBuildPlan = EntityBuildRules.compile(
		_template([capability]),
		[],
		[],
		source,
	)
	var target_plan: EntityBuildPlan = EntityBuildRules.compile([], [], [], target)
	assert_true(
		EntityBuildRules.validate_registration_batch([source, target], [source_plan, target_plan])
	)
	assert_eq(source_plan.bindings.size(), 1)
	assert_eq(source.actor.id, "")
	assert_eq(target.actor.id, "")
	assert_eq(source.actor.relationships.size(), 0)


## Native instance identity is an explicit contract; a context cannot silently replace it.
func test_captured_context_cannot_rename_native_instance_identity() -> void:
	var context: EntitySpawnContext = _context()
	context.actor.id = "authored/id"
	var plan: EntityBuildPlan = EntityBuildRules.compile([], [], [], context)
	assert_false(EntityBuildRules.validate_registration_batch([context], [plan]))
	assert_has(_issue_codes(plan), &"identity_mismatch")
	assert_eq(context.actor.id, "authored/id")
#endregion


#region Authored recipe ownership
## Duplicated scene instances cannot overwrite one another through a shared identity Resource.
func test_placed_identity_compilation_isolates_shared_prefab_recipe() -> void:
	var root: Node = autofree(Node.new()) as Node
	root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"level")
	var first: Entity = Entity.new()
	var second: Entity = Entity.new()
	root.add_child(first)
	root.add_child(second)
	first.owner = root
	second.owner = root
	first.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"first")
	second.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"second")
	var source_recipe: C_AuthoredIdentity = C_AuthoredIdentity.new()
	source_recipe.world_id = &"original"
	source_recipe.local_id = &"source"
	first.component_resources = [source_recipe]
	second.component_resources = [source_recipe]
	assert_eq(PlacedIdentityRules.compile_for(root), [])
	var first_identity: C_AuthoredIdentity = PlacedIdentityRules.component_for(first)
	var second_identity: C_AuthoredIdentity = PlacedIdentityRules.component_for(second)
	assert_ne(first_identity, source_recipe)
	assert_ne(first_identity, second_identity)
	assert_eq(first_identity.actor_key(), "placed/level/first")
	assert_eq(second_identity.actor_key(), "placed/level/second")
	assert_eq(source_recipe.world_id, &"original")
	assert_eq(source_recipe.local_id, &"source")


## Invalid metadata rejects the whole placed set before replacing any Resource reference.
func test_invalid_placed_set_preserves_shared_authoring_inputs() -> void:
	var root: Node = autofree(Node.new()) as Node
	root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"level")
	var first: Entity = Entity.new()
	var second: Entity = Entity.new()
	root.add_child(first)
	root.add_child(second)
	first.owner = root
	second.owner = root
	first.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"duplicate")
	second.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"duplicate")
	var source_recipe: C_AuthoredIdentity = C_AuthoredIdentity.new()
	first.component_resources = [source_recipe]
	second.component_resources = [source_recipe]
	assert_false(PlacedIdentityRules.compile_for(root).is_empty())
	assert_eq(first.component_resources[0], source_recipe)
	assert_eq(second.component_resources[0], source_recipe)
	assert_eq(source_recipe.world_id, &"")
	assert_eq(source_recipe.local_id, &"")


## Repeated bootstrap validation reads registered identity without rewriting its immutable contract.
func test_registered_placed_identity_cannot_be_silently_changed() -> void:
	var root: Node = autofree(Node.new()) as Node
	root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"level")
	var actor: Entity = Entity.new()
	root.add_child(actor)
	actor.owner = root
	actor.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"actor")
	var registered: C_AuthoredIdentity = C_AuthoredIdentity.new()
	registered.world_id = &"level"
	registered.local_id = &"actor"
	actor.add_component(registered)
	assert_true(PlacedIdentityRules.compile_for(root).is_empty())
	assert_eq(actor.get_component(C_AuthoredIdentity), registered)
	actor.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"changed")
	assert_false(PlacedIdentityRules.compile_for(root).is_empty())
	assert_eq(registered.local_id, &"actor")
	assert_eq(actor.get_component(C_AuthoredIdentity), registered)
#endregion


#region Fixture construction
func _context() -> EntitySpawnContext:
	var context: EntitySpawnContext = EntitySpawnContext.new()
	context.actor = autofree(Entity.new()) as Entity
	context.actor_id = "fixture/id"
	context.instance_path = "fixture/actor"
	return context


func _trait(capability_id: StringName, recipes: Array[Component]) -> EntityTrait:
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = capability_id
	capability.component_recipes = recipes
	return capability


func _template(capabilities: Array[EntityTrait]) -> Array[EntityTrait]:
	return capabilities


func _binding(endpoint: StringName) -> EntityInitialBinding:
	var intent: EntityInitialBinding = EntityInitialBinding.new()
	intent.relation = R_SlotMountedOn.new()
	intent.endpoint = endpoint
	return intent


func _scripts(plan: EntityBuildPlan) -> Array[Script]:
	var provider_scripts: Array[Script] = []
	for recipe: Component in plan.component_recipes:
		provider_scripts.append(recipe.get_script() as Script)
	return provider_scripts


func _issue_codes(plan: EntityBuildPlan) -> Array[StringName]:
	var codes: Array[StringName] = []
	for issue: EntityBuildPlan.Issue in plan.issues:
		codes.append(issue.code)
	return codes
#endregion
