extends GutTest
## Verifies prepared authoring recipes reach pinned GECS once without duplicate provider reactions.


## Minimal native Entity with data-only intrinsic recipes and passive initialization counters.
class PreparedActor extends E_TraitedEntity:
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
		_observations.append(
			{
				"ready": EntityCompositionService.composition_ready(actor),
				"components": actor.components.size(),
				"bindings": actor.relationships.size(),
			}
		)


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
	var authoring: E_TraitedEntity = actor as E_TraitedEntity
	authoring.traits = [capability]
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		world,
		"fixture/prepared",
	)
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_true(plan.valid())
	assert_true(EntityBuildRules.validate_registration_batch([context], [plan]))
	assert_true(EntityCompositionService.prepare(actor, plan))
	actor.id = context.actor_id
	var delivered: Array[Script] = []
	actor.component_added.connect(
		func(_entity: Entity, component: Component) -> void:
			delivered.append(component.get_script() as Script),
	)
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
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		null,
		"fixture/rejected",
	)
	var authoring: E_TraitedEntity = actor as E_TraitedEntity
	var duplicate: EntityTrait = EntityTrait.new()
	duplicate.trait_id = &"duplicate"
	duplicate.component_recipes = [C_DayCycle.new()]
	authoring.traits = [duplicate]
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
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		world,
		"fixture/once",
	)
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_true(EntityBuildRules.validate_registration_batch([context], [plan]))
	assert_true(EntityCompositionService.prepare(actor, plan))
	actor.id = context.actor_id
	world.add_entity(actor)
	var resistance: C_DamageResistance = (
		actor.get_component(C_DamageResistance) as C_DamageResistance
	)
	resistance.multipliers[DamageRequest.Type.FIRE] = 0.0
	assert_false(EntityCompositionService.prepare(actor, plan))
	assert_eq(actor.get_component(C_DamageResistance), resistance)
	assert_eq(resistance.multipliers[DamageRequest.Type.FIRE], 0.0)
	assert_eq(actor.intrinsic_calls(), 1)
	assert_eq(actor.passive_ready_calls(), 1)
	world.purge(false)
	world.free()


## A missing direct Trait rejects before native initialization or readiness.
func test_empty_trait_slot_is_reported_without_native_initialization() -> void:
	var actor: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	actor.traits = [null]
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		null,
		"fixture/bad_metadata",
	)
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_false(plan.valid())
	assert_eq(plan.issues[0].code, &"missing_trait")
	assert_eq(actor.intrinsic_calls(), 1)
	assert_eq(actor.passive_ready_calls(), 0)
	assert_eq(actor.components.size(), 0)


## Existing IDs are preserved when a runtime factory rejects its new instance before add_entity.
func test_runtime_factory_gate_rejects_collision_without_replacing_existing_actor() -> void:
	var world: World = World.new()
	add_child(world)
	var existing: Entity = E_TraitedEntity.new()
	existing.id = "fixture/existing"
	world.add_entity(existing)
	var proposed: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		proposed,
		world,
		"fixture/existing",
	)
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
	var first_context: EntitySpawnContext = EntityCompositionService.context_for(
		first,
		world,
		"fixture/planned",
	)
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(first_context)
	assert_true(plan.valid())
	var second: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	var second_context: EntitySpawnContext = EntityCompositionService.context_for(
		second,
		world,
		"fixture/planned",
	)
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
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		null,
		"fixture/no_world",
	)
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
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		world,
		"fixture/runtime",
	)
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


#region Physical impact composition
## Real physical scenes publish isolated inboxes before any System can observe registration.
func test_authored_physical_inbox_exists_at_registration_and_is_private_per_instance() -> void:
	var world: World = World.new()
	add_child(world)
	ECS.world = world
	var box_path: String = "res://content/domains/interaction/entities/box.tscn"
	var scene: PackedScene = load(box_path) as PackedScene
	var first: Entity = scene.instantiate() as Entity
	var second: Entity = scene.instantiate() as Entity
	var traits: Array[EntityTrait] = (first as E_TraitedEntity).traits
	var prototype: C_ImpactInbox = traits[0].component_recipes[0] as C_ImpactInbox
	var published_inboxes: Array[C_ImpactInbox] = []
	world.entity_added.connect(
		func(actor: Entity) -> void:
			published_inboxes.append(actor.get_component(C_ImpactInbox) as C_ImpactInbox),
	)

	EntityCompositionFixture.register(world, first)
	EntityCompositionFixture.register(world, second)
	var first_inbox: C_ImpactInbox = first.get_component(C_ImpactInbox) as C_ImpactInbox
	var second_inbox: C_ImpactInbox = second.get_component(C_ImpactInbox) as C_ImpactInbox
	assert_eq(published_inboxes, [first_inbox, second_inbox])
	assert_not_null(first_inbox)
	assert_not_null(second_inbox)
	assert_ne(first_inbox, second_inbox)
	assert_ne(first_inbox, prototype)
	assert_eq((second as E_TraitedEntity).traits, traits)

	# Setup and repeated enable notification bind engine reporting without replacing pending data.
	var pending_contact: PhysicsContact = PhysicsContact.new()
	first_inbox.contacts.append(pending_contact)
	world.add_system(S_Impact.new())
	world.entity_enabled.emit(first)
	assert_eq(first.get_component(C_ImpactInbox), first_inbox)
	assert_eq(first_inbox.contacts, [pending_contact])
	assert_true(second_inbox.contacts.is_empty())
	assert_true(prototype.contacts.is_empty())
	assert_true(prototype.separations.is_empty())
	assert_true((first as Node as RigidBody3D).contact_monitor)
	assert_gte((first as Node as RigidBody3D).max_contacts_reported, S_Impact.CONTACT_LIMIT)
	world.purge(false)
	world.free()
	ECS.world = null


## A physical capability on the wrong native root rejects before registration or identity mutation.
func test_physical_impact_trait_rejects_nonphysical_root_before_native_publication() -> void:
	var world: World = World.new()
	add_child(world)
	var actor: Entity = autofree(E_TraitedEntity.new()) as Entity
	var authoring: E_TraitedEntity = actor as E_TraitedEntity
	authoring.traits = (load(
		"res://content/domains/combat/definitions/def_entity_physical_impact.tres"
	) as DEF_EntityTemplate).traits
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		world,
		"fixture/wrong_physical_root",
	)
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	assert_false(plan.valid())
	assert_false(EntityCompositionService.register_plan(context, plan))
	assert_true(world.entities.is_empty())
	assert_true(world.entity_id_registry.is_empty())
	assert_true(actor.components.is_empty())
	assert_eq(actor.id, "")
	world.free()
#endregion


#region Inherited physical scene recipe
## The retained RigidBody player variant has one living receiver and inherited inbox capability.
func test_rigid_player_variant_compiles_without_duplicate_scene_receivers() -> void:
	var scene: PackedScene = load(
		"res://content/domains/motion/entities/e_rigid_body_character.tscn"
	) as PackedScene
	var actor: Entity = autofree(scene.instantiate()) as Entity
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		null,
		"fixture/rigid_player",
	)
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_true(plan.valid())
	var receiver_count: int = 0
	var inbox_count: int = 0
	for recipe: Component in plan.component_recipes:
		if recipe is C_ImpactReceiver:
			receiver_count += 1
			var receiver: C_ImpactReceiver = recipe as C_ImpactReceiver
			assert_eq(
				receiver.profile,
				load("res://content/domains/combat/definitions/def_impact_living.tres"),
			)
		elif recipe is C_ImpactInbox:
			inbox_count += 1
	assert_eq(receiver_count, 1)
	assert_eq(inbox_count, 1)
	assert_true(actor.components.is_empty())
#endregion


#region Physical scene provider coverage
## Every migrated native physical root compiles exactly one inbox without registration side effects.
func test_migrated_physical_scene_roots_have_one_valid_inbox_provider() -> void:
	var paths: PackedStringArray = PackedStringArray(
		[
			"res://content/domains/combat/entities/hammer.tscn",
			"res://content/domains/combat/entities/utility_blade.tscn",
			"res://content/domains/interaction/entities/anchorable_test_box.tscn",
			"res://content/domains/interaction/entities/box.tscn",
			"res://content/domains/interaction/entities/bucket.tscn",
			"res://content/domains/interaction/entities/cloth_sample.tscn",
			"res://content/domains/interaction/entities/large_shelf.tscn",
			"res://content/domains/interaction/entities/marker.tscn",
			"res://content/domains/interaction/entities/small_shelf.tscn",
			"res://content/domains/inventory/entities/bubble_wrap_pickup.tscn",
			"res://content/domains/inventory/entities/food_pickup.tscn",
			"res://content/domains/inventory/entities/med_pickup.tscn",
			"res://content/domains/inventory/entities/npc_meat_pickup.tscn",
			"res://content/domains/motion/entities/character_body_player.tscn",
			"res://content/domains/motion/entities/physical_character.tscn",
			"res://content/domains/motion/entities/e_rigid_body_character.tscn",
			"res://content/domains/packages/entities/content_stub.tscn",
			"res://content/domains/packages/entities/package_debris_stub.tscn",
			"res://content/domains/packages/entities/scanner.tscn",
		]
	)
	for scene_path: String in paths:
		var scene: PackedScene = load(scene_path) as PackedScene
		var actor: Entity = autofree(scene.instantiate()) as Entity
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			null,
			"fixture/physical_scene",
		)
		var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
		var diagnostics: PackedStringArray = PackedStringArray()
		for issue: EntityBuildPlan.Issue in plan.issues:
			diagnostics.append(issue.message)
		assert_true(plan.valid(), scene_path + ": " + "; ".join(diagnostics))
		var inbox_count: int = 0
		for recipe: Component in plan.component_recipes:
			if recipe is C_ImpactInbox:
				inbox_count += 1
		assert_eq(inbox_count, 1, scene_path)
		assert_true(actor.components.is_empty(), scene_path)
#endregion


#region Initial session loot queue
## Native publication sees the queue, and current() only reads its existing mutable aggregate.
func test_session_loot_queue_is_complete_before_publication_and_reads_do_not_install() -> void:
	var world: World = World.new()
	add_child(world)
	ECS.world = world
	var actor: Entity = _loot_session_actor()
	var delivered: Array[Script] = []
	actor.component_added.connect(
		func(_actor: Entity, component: Component) -> void:
			delivered.append(component.get_script() as Script),
	)
	var published: Array[C_LootDrops] = []
	world.entity_added.connect(
		func(subject: Entity) -> void:
			published.append(subject.get_component(C_LootDrops) as C_LootDrops),
	)
	EntityCompositionFixture.register(world, actor)
	var queue: C_LootDrops = actor.get_component(C_LootDrops) as C_LootDrops
	assert_eq(published, [queue])
	assert_not_null(queue)
	assert_eq(delivered.count(C_LootDrops as Script), 1)
	var pending: PendingLootDrop = PendingLootDrop.new()
	pending.drop_id = "fixture/session_loot"
	queue.pending.append(pending)
	var before: int = delivered.size()
	assert_eq(LootDropService.current(), queue)
	assert_eq(LootDropService.current(), queue)
	assert_eq(queue.pending, [pending])
	assert_eq(delivered.size(), before)
	world.purge(false)
	world.free()
	ECS.world = null


## Session queue records and containers are private; immutable placement tuning stays shared.
func test_session_loot_queue_recipes_isolate_runtime_state() -> void:
	var first: Entity = autofree(_loot_session_actor()) as Entity
	var second: Entity = autofree(_loot_session_actor()) as Entity
	var first_plan: EntityBuildPlan = EntityCompositionService.build_plan(
		EntityCompositionService.context_for(first, null, "fixture/first_session")
	)
	var second_plan: EntityBuildPlan = EntityCompositionService.build_plan(
		EntityCompositionService.context_for(second, null, "fixture/second_session")
	)
	assert_true(first_plan.valid())
	assert_true(second_plan.valid())
	var first_queue: C_LootDrops = _loot_recipe(first_plan)
	var second_queue: C_LootDrops = _loot_recipe(second_plan)
	assert_ne(first_queue, second_queue)
	assert_eq(first_queue.placement, second_queue.placement)
	first_queue.pending.append(PendingLootDrop.new())
	first_queue.committed_batches["fixture/batch"] = true
	first_queue.reservations.append(AABB(Vector3.ZERO, Vector3.ONE))
	assert_true(second_queue.pending.is_empty())
	assert_true(second_queue.committed_batches.is_empty())
	assert_true(second_queue.reservations.is_empty())
	assert_true(first.components.is_empty())
	assert_true(second.components.is_empty())


func _loot_session_actor() -> Entity:
	var actor: Entity = E_TraitedEntity.new()
	actor.component_resources = [C_DayCycle.new()]
	var authoring: E_TraitedEntity = actor as E_TraitedEntity
	authoring.traits = (load(
		"res://content/domains/time/definitions/def_entity_day_session.tres"
	) as DEF_EntityTemplate).traits
	return actor


func _loot_recipe(plan: EntityBuildPlan) -> C_LootDrops:
	for recipe: Component in plan.component_recipes:
		if recipe is C_LootDrops:
			return recipe as C_LootDrops
	return null
#endregion


#region Package content capability
## All authored content variants compile one receiver and optional emitter without live publication.
func test_package_content_variants_compile_authored_capabilities_before_registration() -> void:
	var keys: PackedStringArray = PackedStringArray(
		["stub", "tools", "power_cells", "oil", "glass", "equipment", "bottles", "books"]
	)
	for key: String in keys:
		var actor: E_PackageContent = autofree(_content_actor(key)) as E_PackageContent
		var plan: EntityBuildPlan = EntityCompositionService.build_plan(
			EntityCompositionService.context_for(actor, null, "fixture/content/" + key)
		)
		assert_true(plan.valid(), key)
		var receiver: C_ImpactReceiver = _content_recipe(plan, C_ImpactReceiver) as C_ImpactReceiver
		assert_not_null(receiver, key)
		assert_eq(receiver.profile, actor.impact_profile, key)
		assert_not_null(_content_recipe(plan, C_ImpactInbox), key)
		var emitter: C_HazardEmitter = _content_recipe(plan, C_HazardEmitter) as C_HazardEmitter
		if actor.hazard_scene == null:
			assert_null(emitter, key)
		else:
			assert_not_null(emitter, key)
			assert_eq(emitter.hazard_scene, actor.hazard_scene, key)
		assert_true(actor.components.is_empty(), key)
		assert_eq(actor.id, "", key)


## Native entity_added observes every capability, including hazardous content, exactly once.
func test_package_content_native_publication_sees_complete_capabilities() -> void:
	var world: World = World.new()
	add_child(world)
	var actor: E_PackageContent = _content_actor("power_cells")
	var delivered: Array[Script] = []
	actor.component_added.connect(
		func(_actor: Entity, component: Component) -> void:
			delivered.append(component.get_script() as Script),
	)
	var published: Array[bool] = []
	world.entity_added.connect(
		func(subject: Entity) -> void:
			published.append(
				subject.has_component(C_ImpactInbox) and subject.has_component(C_ImpactReceiver)
				and subject.has_component(C_HazardEmitter)
			),
	)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		world,
		"fixture/content/published",
	)
	assert_true(EntityCompositionService.try_register(context))
	assert_eq(published, [true])
	assert_eq(delivered.count(C_ImpactReceiver as Script), 1)
	assert_eq(delivered.count(C_ImpactInbox as Script), 1)
	assert_eq(delivered.count(C_HazardEmitter as Script), 1)
	assert_eq(
		(actor.get_component(C_ImpactReceiver) as C_ImpactReceiver).profile,
		actor.impact_profile,
	)
	assert_eq(
		(actor.get_component(C_HazardEmitter) as C_HazardEmitter).hazard_scene,
		actor.hazard_scene,
	)
	world.purge(false)
	world.free()


## Mutable impact/hazard state is private while authored tuning and hazard scenes retain identity.
func test_package_content_recipes_isolate_mutable_state() -> void:
	var first: E_PackageContent = autofree(_content_actor("oil")) as E_PackageContent
	var second: E_PackageContent = autofree(_content_actor("oil")) as E_PackageContent
	var first_plan: EntityBuildPlan = EntityCompositionService.build_plan(
		EntityCompositionService.context_for(first, null, "fixture/content/first")
	)
	var second_plan: EntityBuildPlan = EntityCompositionService.build_plan(
		EntityCompositionService.context_for(second, null, "fixture/content/second")
	)
	assert_true(first_plan.valid())
	assert_true(second_plan.valid())
	var first_emitter: C_HazardEmitter = (
		_content_recipe(first_plan, C_HazardEmitter) as C_HazardEmitter
	)
	var second_emitter: C_HazardEmitter = (
		_content_recipe(second_plan, C_HazardEmitter) as C_HazardEmitter
	)
	var first_inbox: C_ImpactInbox = _content_recipe(first_plan, C_ImpactInbox) as C_ImpactInbox
	var second_inbox: C_ImpactInbox = _content_recipe(second_plan, C_ImpactInbox) as C_ImpactInbox
	assert_ne(first_emitter, second_emitter)
	assert_ne(first_inbox, second_inbox)
	assert_eq(first_emitter.hazard_scene, second_emitter.hazard_scene)
	first_emitter.fired = true
	first_emitter.sequence = 9
	first_inbox.contacts.append(PhysicsContact.new())
	assert_false(second_emitter.fired)
	assert_eq(second_emitter.sequence, 0)
	assert_true(second_inbox.contacts.is_empty())


## Missing authored tuning and duplicate scene providers reject without identity or World mutation.
func test_package_content_invalid_providers_reject_before_registration() -> void:
	var world: World = World.new()
	add_child(world)
	var missing: E_PackageContent = autofree(_content_actor("stub")) as E_PackageContent
	missing.impact_profile = null
	var duplicate: E_PackageContent = autofree(_content_actor("stub")) as E_PackageContent
	duplicate.component_resources.append(C_ImpactReceiver.new())
	for actor: E_PackageContent in [missing, duplicate]:
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			world,
			"fixture/content/rejected",
		)
		var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
		assert_false(plan.valid())
		assert_false(EntityCompositionService.register_plan(context, plan))
		assert_true(actor.components.is_empty())
		assert_eq(actor.id, "")
	assert_true(world.entities.is_empty())
	assert_true(world.entity_id_registry.is_empty())
	world.free()


## A detached valid loot batch is checked without creating live capabilities or publishing actors.
func test_content_loot_preflight_keeps_world_and_native_instances_unpublished() -> void:
	var world: World = World.new()
	add_child(world)
	ECS.world = world
	var scenes: Array[PackedScene] = [
		load("res://content/domains/packages/entities/content_oil.tscn") as PackedScene,
		load("res://content/domains/packages/entities/content_tools.tscn") as PackedScene,
	]
	var prepared: Array[Entity] = LootDropService.prepare(scenes)
	assert_eq(prepared.size(), 2)
	for actor: Entity in prepared:
		assert_true(actor.components.is_empty())
		assert_false(EntityCompositionService.recipes_prepared(actor))
		assert_eq(actor.id, "")
		actor.free()
	assert_true(world.entities.is_empty())
	assert_true(world.entity_id_registry.is_empty())
	world.free()
	ECS.world = null


func _content_actor(key: String) -> E_PackageContent:
	var scene_path: String = "res://content/domains/packages/entities/content_%s.tscn" % key
	var scene: PackedScene = load(scene_path) as PackedScene
	return scene.instantiate() as E_PackageContent


func _content_recipe(plan: EntityBuildPlan, script: Script) -> Component:
	var found: Component = null
	for recipe: Component in plan.component_recipes:
		if recipe.get_script() == script:
			assert_null(found, "Only one content capability provider is permitted")
			found = recipe
	return found
#endregion


#region Runtime per-Entity reaction barrier
## Native multi-Component on_added matching is preserved; callbacks see final bindings exactly once.
func test_factory_observers_wait_for_readiness_and_preserve_native_initial_counts() -> void:
	var world: World = World.new()
	add_child(world)
	var target: Entity = E_TraitedEntity.new()
	EntityCompositionFixture.register(world, target)
	var spies: Array[ReadySpy] = [
		ReadySpy.new(&"added"),
		ReadySpy.new(&"match"),
		ReadySpy.new(&"relationship"),
	]
	for spy: ReadySpy in spies:
		world.add_observer(spy)
	var actor: PreparedActor = PreparedActor.new()
	actor.component_resources = [C_Health.new(), C_Inventory.new()]
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		world,
		"fixture/complete_reactions",
	)
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
		assert_eq(spy.observations(), [{ "ready": true, "components": 3, "bindings": 1 }])
	assert_eq(actor.passive_ready_calls(), 1)
	assert_eq(actor.relationships[0].target, target)
	world.purge(false)
	world.free()


## Failed preflight never suspends unrelated reactions or publishes the rejected actor as ready.
func test_failed_factory_keeps_observers_active_without_ready_or_initial_effects() -> void:
	var world: World = World.new()
	add_child(world)
	var existing: Entity = E_TraitedEntity.new()
	existing.id = "fixture/collision"
	EntityCompositionFixture.register(world, existing)
	var spy: ReadySpy = ReadySpy.new(&"match")
	world.add_observer(spy)
	var actor: PreparedActor = autofree(PreparedActor.new()) as PreparedActor
	actor.component_resources = [C_Health.new()]
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		world,
		existing.id,
	)
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
