extends GutTest
## Verifies prepared authoring recipes reach pinned GECS once without duplicate provider reactions.

## Minimal native Entity with data-only intrinsic recipes and passive initialization counters.
class PreparedActor extends Entity:
	var _intrinsic_calls: int = 0
	var _passive_ready_calls: int = 0
	var _ready_components: int = 0

	## Supplies a fresh native data recipe, without installing a live capability.
	func define_components() -> Array[Component]:
		if EntityCompositionService.recipes_prepared(self):
			return []
		_intrinsic_calls += 1
		return [C_DamageResistance.new()]

	## Passive native ready inspects complete data and publishes no gameplay outcomes.
	func on_ready() -> void:
		_passive_ready_calls += 1
		_ready_components = components.size()

	## Returns compile-time provider evaluations for the registration ordering assertion.
	func intrinsic_calls() -> int:
		return _intrinsic_calls

	## Returns passive ready invocations made by pinned GECS.
	func passive_ready_calls() -> int:
		return _passive_ready_calls

	## Returns the complete Component count visible to passive native ready.
	func ready_components() -> int:
		return _ready_components


## Real native subscriptions observe only accepted complete data and initial bindings.
class ReadySpy extends Observer:
	var _kind: StringName
	var _observations: Array[Dictionary] = []

	func _init(kind: StringName) -> void:
		_kind = kind

	## Uses native initial Component, monitor or Relationship notifications.
	func query() -> QueryBuilder:
		if _kind == &"added":
			return q.with_all([C_Health, C_Inventory]).on_added()
		if _kind == &"match":
			return q.with_all([C_Health]).on_match()
		return q.with_all([C_Health]).on_relationship_added([R_SlotMountedOn])

	## Captures actual reaction state; no implementation flags replace the native dispatch.
	func each(_event: Variant, actor: Entity, _payload: Variant = null) -> void:
		_observations.append({"ready": EntityCompositionService.composition_ready(actor),
			"components": actor.components.size(), "bindings": actor.relationships.size()})

	## Returns complete data seen by each real callback for exact-once assertions.
	func observations() -> Array[Dictionary]:
		return _observations.duplicate()


#region Prepared pinned initialization
## Scene/code/Trait providers are each delivered once and on_ready sees the complete composition.
func test_prepared_components_are_added_once_before_passive_native_ready() -> void:
	var world: World = World.new()
	add_child(world)
	var actor: PreparedActor = PreparedActor.new()
	var calendar: C_DayCycle = C_DayCycle.new()
	calendar.clock.elapsed_ticks = 43
	actor.component_resources = [calendar]
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"inventory"
	capability.component_recipes = [C_Inventory.new()]
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = DEF_EntityTemplate.new()
	authoring.entity_template.traits = [capability]
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, world, "fixture/prepared")
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_true(plan.valid())
	assert_true(EntityBuildRules.validate_registration_batch([context], [plan]))
	assert_true(EntityCompositionService.prepare(actor, plan))
	actor.id = context.actor_id
	var delivered: Array[Script] = []
	actor.component_added.connect(func(_entity: Entity, component: Component) -> void:
		delivered.append(component.get_script() as Script))
	world.add_entity(actor)
	assert_eq(world.entities.size(), 1)
	assert_eq(actor.intrinsic_calls(), 1)
	assert_eq(delivered.size(), 3)
	assert_eq(actor.components.size(), 3)
	assert_eq(actor.passive_ready_calls(), 1)
	assert_eq(actor.ready_components(), 3)
	var copied_clock: C_DayCycle = actor.get_component(C_DayCycle) as C_DayCycle
	assert_eq(copied_clock.clock.elapsed_ticks, 43)
	assert_ne(copied_clock.clock, calendar.clock)
	assert_eq(calendar.clock.elapsed_ticks, 43)
	world.purge(false)
	world.free()


## Invalid compilation does not replace authoring providers or proceed into native registration.
func test_failed_prepare_preserves_scene_inputs_without_ready_side_effects() -> void:
	var actor: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	var source: C_DayCycle = C_DayCycle.new()
	actor.component_resources = [source]
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, null, "fixture/rejected")
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = DEF_EntityTemplate.new()
	var duplicate: EntityTrait = EntityTrait.new()
	duplicate.trait_id = &"duplicate"
	duplicate.component_recipes = [C_DayCycle.new()]
	authoring.entity_template.traits = [duplicate]
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_false(plan.valid())
	assert_false(EntityCompositionService.prepare(actor, plan))
	assert_eq(actor.component_resources[0], source)
	assert_eq(actor.components.size(), 0)
	assert_eq(actor.passive_ready_calls(), 0)
	assert_eq(actor.id, "")


## The same validated plan cannot silently re-prepare a previously committed scene instance.
func test_repeated_preparation_is_rejected_without_changing_registered_state() -> void:
	var world: World = World.new()
	add_child(world)
	var actor: PreparedActor = PreparedActor.new()
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, world, "fixture/once")
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_true(EntityBuildRules.validate_registration_batch([context], [plan]))
	assert_true(EntityCompositionService.prepare(actor, plan))
	actor.id = context.actor_id
	world.add_entity(actor)
	var resistance: C_DamageResistance = actor.get_component(C_DamageResistance) as C_DamageResistance
	resistance.multipliers[DamageRequest.Type.FIRE] = 0.0
	assert_false(EntityCompositionService.prepare(actor, plan))
	assert_eq(actor.get_component(C_DamageResistance), resistance)
	assert_eq(resistance.multipliers[DamageRequest.Type.FIRE], 0.0)
	assert_eq(actor.intrinsic_calls(), 1)
	assert_eq(actor.passive_ready_calls(), 1)
	world.purge(false)
	world.free()


## Wrong metadata is a configuration error, instead of silently falling back to scene-only data.
func test_invalid_authoring_metadata_is_reported_without_native_initialization() -> void:
	var actor: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	actor.set_meta(EntityCompositionService.AUTHORING_META, "invalid resource")
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, null,
		"fixture/bad_metadata")
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_false(plan.valid())
	assert_eq(plan.issues[0].code, &"invalid_authoring")
	assert_eq(actor.intrinsic_calls(), 0)
	assert_eq(actor.passive_ready_calls(), 0)
	assert_eq(actor.components.size(), 0)


## Existing IDs are preserved when a runtime factory rejects its new instance before add_entity.
func test_runtime_factory_gate_rejects_collision_without_replacing_existing_actor() -> void:
	var world: World = World.new()
	add_child(world)
	var existing: Entity = Entity.new()
	existing.id = "fixture/existing"
	world.add_entity(existing)
	var proposed: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	var context: EntitySpawnContext = EntityCompositionService.context_for(proposed, world,
		"fixture/existing")
	assert_false(EntityCompositionService.try_register(context))
	assert_eq(world.entities, [existing])
	assert_eq(world.entity_id_registry[existing.id], existing)
	assert_eq(proposed.passive_ready_calls(), 0)
	assert_eq(proposed.components.size(), 0)
	assert_eq(proposed.id, "")
	assert_false(existing.is_queued_for_deletion())
	world.purge(false)
	world.free()


## A successful plan for one actor cannot become a recipe/identity authority for another instance.
func test_validated_factory_plan_cannot_register_a_different_actor() -> void:
	var world: World = World.new()
	add_child(world)
	var first: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	var first_context: EntitySpawnContext = EntityCompositionService.context_for(first, world,
		"fixture/planned")
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(first_context)
	assert_true(plan.valid())
	var second: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	var second_context: EntitySpawnContext = EntityCompositionService.context_for(second, world,
		"fixture/planned")
	assert_false(EntityCompositionService.prepare(second, plan))
	assert_false(EntityCompositionService.recipes_prepared(second))
	assert_false(EntityCompositionService.register_plan(second_context, plan))
	assert_eq(plan.issues[0].code, &"inconsistent_plan")
	assert_true(world.entities.is_empty())
	assert_true(world.entity_id_registry.is_empty())
	assert_eq(first.id, "")
	assert_eq(second.id, "")
	assert_eq(second.passive_ready_calls(), 0)
	world.free()


## Pure preview accepts no World; runtime registration preflight must reject it explicitly.
func test_runtime_registration_requires_world_and_returns_actionable_configuration_issue() -> void:
	var actor: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, null,
		"fixture/no_world")
	assert_true(EntityCompositionService.build_plan(context).valid())
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	assert_false(plan.valid())
	assert_eq(plan.issues[0].code, &"missing_world")
	assert_false(EntityCompositionService.register_plan(context, plan))
	assert_eq(actor.components.size(), 0)
	assert_eq(actor.passive_ready_calls(), 0)
	assert_eq(actor.id, "")


## Runtime factory uses the same optional Template/code preparation and invokes native ready once.
func test_runtime_factory_gate_registers_complete_native_data_once() -> void:
	var world: World = World.new()
	add_child(world)
	var actor: PreparedActor = PreparedActor.new()
	actor.component_resources = [C_DayCycle.new()]
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, world,
		"fixture/runtime")
	assert_true(EntityCompositionService.try_register(context))
	assert_eq(world.entities.size(), 1)
	assert_eq(actor.id, "fixture/runtime")
	assert_eq(actor.intrinsic_calls(), 1)
	assert_eq(actor.passive_ready_calls(), 1)
	assert_eq(actor.ready_components(), 2)
	assert_true(EntityCompositionService.recipes_prepared(actor))
	world.purge(false)
	world.free()
#endregion

#region Runtime per-Entity reaction barrier
## Native multi-Component on_added matching is preserved; callbacks see final bindings exactly once.
func test_factory_observers_wait_for_readiness_and_preserve_native_initial_counts() -> void:
	var world: World = World.new()
	add_child(world)
	var target: Entity = Entity.new()
	EntityCompositionFixture.register(world, target)
	var spies: Array[ReadySpy] = [ReadySpy.new(&"added"), ReadySpy.new(&"match"),
		ReadySpy.new(&"relationship")]
	for spy: ReadySpy in spies:
		world.add_observer(spy)
	var actor: PreparedActor = PreparedActor.new()
	actor.component_resources = [C_Health.new(), C_Inventory.new()]
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, world,
		"fixture/complete_reactions")
	context.bindings[&"support"] = target
	var intent: EntityInitialBinding = EntityInitialBinding.new()
	intent.relation = R_SlotMountedOn.new()
	intent.endpoint = &"support"
	context.initial_bindings = [intent]
	assert_false(EntityCompositionService.composition_ready(actor))
	assert_true(EntityCompositionService.try_register(context))
	assert_true(EntityCompositionService.composition_ready(actor))
	for spy: ReadySpy in spies:
		assert_true(spy.active)
		assert_eq(spy.observations(), [{"ready": true, "components": 3, "bindings": 1}])
	assert_eq(actor.passive_ready_calls(), 1)
	assert_eq(actor.relationships[0].target, target)
	world.purge(false)
	world.free()


## Failed preflight never suspends unrelated reactions or publishes the rejected actor as ready.
func test_failed_factory_keeps_observers_active_without_ready_or_initial_effects() -> void:
	var world: World = World.new()
	add_child(world)
	var existing: Entity = Entity.new()
	existing.id = "fixture/collision"
	EntityCompositionFixture.register(world, existing)
	var spy: ReadySpy = ReadySpy.new(&"match")
	world.add_observer(spy)
	var actor: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	actor.component_resources = [C_Health.new()]
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor,
		world, existing.id)
	assert_false(EntityCompositionService.try_register(context))
	assert_true(spy.active)
	assert_true(spy.observations().is_empty())
	assert_false(EntityCompositionService.composition_ready(actor))
	assert_false(EntityCompositionService.recipes_prepared(actor))
	assert_eq(actor.passive_ready_calls(), 0)
	assert_eq(world.entities, [existing])
	world.purge(false)
	world.free()
#endregion
