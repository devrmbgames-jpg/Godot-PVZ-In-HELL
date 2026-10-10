extends GutTest
## Tests the production NPC identity/Profile compiler and detached roster projection.

const _SCENE: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const _TRADER_SCENE: PackedScene = preload(
	"res://tests/fixtures/refactoring_v2/trader_npc_template.tscn"
)
const _DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)

var _root: Node3D
var _world: World


#region Fixture lifetime
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world


func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null


func _recipe(recipes: Array[Component], component_script: Script) -> Component:
	for recipe: Component in recipes:
		if recipe.get_script() == component_script:
			return recipe
	return null


func _scene_trader() -> E_DistrictNpc:
	var actor: E_DistrictNpc = _TRADER_SCENE.instantiate() as E_DistrictNpc
	_root.add_child(actor)
	return actor


func _context(actor: Entity, person: NpcRecord, actor_id: String) -> EntitySpawnContext:
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, _world, actor_id)
	NpcConstructionService.configure_context(context, person, _DISTRICT)
	return context
#endregion


#region Initial roster and identity
## Pure allocation preserves existing Profile/home/portal/ID order without sharing mutable records.
func test_initial_roster_is_detached_and_preserves_authored_order() -> void:
	var first: Array[NpcRecord] = NpcPopulationRules.initial_records(_DISTRICT, 1)
	var second: Array[NpcRecord] = NpcPopulationRules.initial_records(_DISTRICT, 1)
	assert_eq(first.size(), _DISTRICT.profiles.size())
	assert_eq(first[0].npc_id, &"npc/1")
	assert_true(first[7].profile.merchant)
	assert_same(first[7].profile, _DISTRICT.profiles[7])
	assert_eq(first[0].home_id, second[0].home_id)
	assert_eq(first[0].portal_id, second[0].portal_id)
	assert_ne(first[0], second[0])
	first[0].npc_id = &"changed"
	assert_eq(second[0].npc_id, &"npc/1")


## Scene and factory identity/Profile inputs are complete when native entity_added publishes.
func test_native_publication_has_identity_persistent_key_and_profile_speed_once() -> void:
	var actor: E_DistrictNpc = _SCENE.instantiate() as E_DistrictNpc
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[0]
	var context: EntitySpawnContext = _context(actor, person, "fixture/npc")
	var publications: Array[StringName] = []
	_world.entity_added.connect(
		func(published: Entity) -> void:
			var identity: C_NpcIdentity = published.get_component(C_NpcIdentity) as C_NpcIdentity
			var persistent: C_PersistentIdentity = published.get_component(C_PersistentIdentity) \
					as C_PersistentIdentity
			var motion: C_Motion = published.get_component(C_Motion) as C_Motion
			assert_eq(identity.npc_id, person.npc_id)
			assert_eq(persistent.key, String(person.npc_id))
			assert_eq(motion.max_speed, person.profile.move_speed)
			assert_true(published.has_component(C_NpcAwareness))
			assert_true(published.has_component(C_NpcDecision))
			assert_true(published.has_component(C_NpcRoute))
			assert_true(published.has_component(C_DamageResistance))
			var combat: C_NpcCombat = published.get_component(C_NpcCombat) as C_NpcCombat
			assert_false(combat.automatic_attack_selection)
			assert_eq(combat.melee_attacks, person.profile.melee_attacks)
			assert_true(published.has_component(C_Inventory))
			var hunger: C_Hunger = published.get_component(C_Hunger) as C_Hunger
			assert_eq(hunger.value, _DISTRICT.npc_start_hunger)
			assert_not_null(hunger.policy)
			var actions: C_InteractionActionSet = published.get_component(C_InteractionActionSet) \
					as C_InteractionActionSet
			assert_eq(actions.actions.size(), 3)
			assert_eq(actions.actions[2].action_id, &"npc_street_dialogue")
			assert_eq(actions.actions[2].slot, DEF_InteractionAction.Slot.INTERACT)
			publications.append(identity.npc_id),
	)
	assert_true(EntityCompositionService.try_register(context))
	assert_eq(publications, [person.npc_id])
	assert_eq(_world.entities.size(), 1)


## Missing roster inputs reject instead of allocating an identity or publishing partial state.
func test_missing_roster_inputs_reject_before_registration() -> void:
	var actor: E_DistrictNpc = autofree(_SCENE.instantiate()) as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		_world,
		"fixture/missing_identity",
	)
	assert_false(EntityCompositionService.try_register(context))
	assert_true(_world.entities.is_empty())
	assert_true(actor.components.is_empty())
	assert_eq(actor.id, "")


## Two instances of one NPC key fail the whole batch before native collision replacement.
func test_repeated_roster_identity_rejects_the_whole_batch() -> void:
	var first: E_DistrictNpc = autofree(_SCENE.instantiate()) as E_DistrictNpc
	var second: E_DistrictNpc = autofree(_SCENE.instantiate()) as E_DistrictNpc
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[0]
	var contexts: Array[EntitySpawnContext] = [
		_context(first, person, "fixture/first"),
		_context(second, person, "fixture/second"),
	]
	var plans: Array[EntityBuildPlan] = []
	for context: EntitySpawnContext in contexts:
		plans.append(EntityCompositionService.build_plan(context))
	assert_false(EntityBuildRules.validate_registration_batch(contexts, plans))
	assert_true(_world.entities.is_empty())
	assert_true(first.components.is_empty())
	assert_true(second.components.is_empty())
#endregion


#region Authored immunity defaults
## Fire immunity is already present at publication and mutable resistance maps are instance-local.
func test_fire_resistance_compiles_before_publication_and_isolated_per_instance() -> void:
	var people: Array[NpcRecord] = NpcPopulationRules.initial_records(_DISTRICT, 1)
	var person: NpcRecord = null
	for candidate: NpcRecord in people:
		if candidate.profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null:
			person = candidate
			break
	assert_not_null(person)
	var first: E_DistrictNpc = autofree(_SCENE.instantiate()) as E_DistrictNpc
	var second: E_DistrictNpc = autofree(_SCENE.instantiate()) as E_DistrictNpc
	var first_plan: EntityBuildPlan = EntityCompositionService.build_plan(
		_context(first, person, "fixture/first_fire")
	)
	var second_plan: EntityBuildPlan = EntityCompositionService.build_plan(
		_context(second, person, "fixture/second_fire")
	)
	assert_true(first_plan.valid())
	assert_true(second_plan.valid())
	var first_resistance: C_DamageResistance = _recipe(
		first_plan.component_recipes,
		C_DamageResistance,
	) as C_DamageResistance
	var second_resistance: C_DamageResistance = _recipe(
		second_plan.component_recipes,
		C_DamageResistance,
	) as C_DamageResistance
	assert_eq(first_resistance.multipliers[DamageRequest.Type.FIRE], 0.0)
	first_resistance.multipliers[DamageRequest.Type.FIRE] = 0.5
	assert_eq(second_resistance.multipliers[DamageRequest.Type.FIRE], 0.0)
	assert_true(first.components.is_empty())
	assert_true(second.components.is_empty())
#endregion


#region Resident and merchant provider ownership
## Spawned merchant gets the same declared role Traits and a scene-owned furniture marker.
func test_spawned_merchant_compiles_inventory_hunger_trade_and_authored_marker() -> void:
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[7]
	var actor: E_DistrictNpc = autofree(_SCENE.instantiate()) as E_DistrictNpc
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(
		_context(actor, person, "fixture/spawned_merchant")
	)
	assert_true(plan.valid())
	var trader: C_Trader = _recipe(plan.component_recipes, C_Trader) as C_Trader
	assert_same(
		trader.profile,
		load("res://content/domains/commerce/definitions/def_trader_default.tres"),
	)
	var actions: C_InteractionActionSet = (
		_recipe(plan.component_recipes, C_InteractionActionSet) as C_InteractionActionSet
	)
	assert_eq(actions.actions.size(), 4)
	assert_eq(actions.actions[2].action_id, &"npc_street_dialogue")
	assert_eq(actions.actions[3].action_id, &"trade")
	assert_not_null(_recipe(plan.component_recipes, C_Inventory))
	assert_eq(
		(_recipe(plan.component_recipes, C_Hunger) as C_Hunger).value,
		_DISTRICT.npc_start_hunger,
	)
	assert_eq((actor.get_node("FurniturePickup") as Marker3D).position, Vector3(2, 0, 0))
	assert_true(actor.components.is_empty())


## Existing Trader providers keep authored Profile/action Definitions without a second provider.
func test_placed_trader_variant_preserves_scene_profile_and_merges_actions_explicitly() -> void:
	var actor: E_DistrictNpc = _scene_trader()
	var scene_trader: C_Trader = _recipe(actor.component_resources, C_Trader) as C_Trader
	var scene_actions: C_InteractionActionSet = _recipe(
		actor.component_resources,
		C_InteractionActionSet,
	) as C_InteractionActionSet
	var pickup: Marker3D = actor.get_node("FurniturePickup") as Marker3D
	var authored_pickup_pose: Transform3D = pickup.transform
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[7]
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(
		_context(actor, person, "fixture/placed_merchant")
	)
	assert_true(plan.valid())
	var trader: C_Trader = _recipe(plan.component_recipes, C_Trader) as C_Trader
	var actions: C_InteractionActionSet = (
		_recipe(plan.component_recipes, C_InteractionActionSet) as C_InteractionActionSet
	)
	assert_same(trader.profile, scene_trader.profile)
	assert_ne(trader, scene_trader)
	assert_eq(actions.actions.size(), scene_actions.actions.size() + 3)
	assert_same(actions.actions[2], scene_actions.actions[0])
	var street: DEF_InteractionAction = actions.actions.back()
	assert_eq(street.action_id, &"npc_street_dialogue")
	assert_eq(scene_actions.actions.size(), 1, "Authored action aggregate stays immutable")
	assert_eq(pickup.transform, authored_pickup_pose, "Authored pickup pose is preserved")


## A missing explicitly selected scene provider rejects instead of falling back to a Trait provider.
func test_missing_scene_trader_provider_rejects_without_fallback() -> void:
	var actor: E_DistrictNpc = _scene_trader()
	var remaining: Array[Component] = []
	for recipe: Component in actor.component_resources:
		if not recipe is C_Trader:
			remaining.append(recipe)
	actor.component_resources = remaining
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[7]
	assert_false(
		EntityCompositionService.try_register(
			_context(actor, person, "fixture/missing_scene_trader"),
			false,
		)
	)
	assert_true(_world.entities.is_empty())
	assert_true(actor.components.is_empty())
	assert_eq(actor.id, "")


## A duplicate scene/role Trait provider aborts native registration before any mutable state exists.
func test_authored_inventory_conflicts_with_resident_trait_provider() -> void:
	var actor: E_DistrictNpc = autofree(_SCENE.instantiate()) as E_DistrictNpc
	actor.component_resources.append(C_Inventory.new())
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[0]
	var context: EntitySpawnContext = _context(actor, person, "fixture/conflicting_inventory")
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	assert_false(plan.valid())
	assert_true(
		plan
		.issues
		.any(
			func(issue: EntityBuildPlan.Issue) -> bool:
				return issue.code == &"duplicate_provider",
		)
	)
	assert_false(EntityCompositionService.register_plan(context, plan))
	assert_true(_world.entities.is_empty())
	assert_true(actor.components.is_empty())
#endregion


#region Initial action provider conflicts
## Supplemental role Definitions cannot silently override another compiled action ID.
func test_duplicate_additional_role_action_is_rejected_before_registration() -> void:
	var actor: E_DistrictNpc = _SCENE.instantiate() as E_DistrictNpc
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[0]
	var context: EntitySpawnContext = _context(actor, person, "duplicate-action")
	var roles: EntityTrait = null
	for candidate: EntityTrait in actor.traits:
		if candidate.trait_id == &"npc_roles":
			roles = candidate
	var extra: Array = roles.get("additional_actions") as Array
	extra.append(extra[0])
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	extra.pop_back()
	assert_false(plan.valid())
	assert_true(actor.components.is_empty())
	actor.free()
#endregion


#region Initial navigation route capability
## Native publication exposes private route buffers before any scheduled decision can advance.
func test_route_state_is_ready_at_publication_and_isolated_between_instances() -> void:
	var people: Array[NpcRecord] = NpcPopulationRules.initial_records(_DISTRICT, 1)
	var published: Array[C_NpcRoute] = []
	_world.entity_added.connect(
		func(actor: Entity) -> void:
			var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
			assert_not_null(route)
			assert_true(route.points.is_empty())
			assert_eq(route.map_iteration, -1)
			assert_false(route.pending)
			published.append(route),
	)
	for index: int in range(2):
		var actor: E_DistrictNpc = _SCENE.instantiate() as E_DistrictNpc
		var context: EntitySpawnContext = _context(
			actor,
			people[index],
			"fixture/initial_route/%d" % index,
		)
		assert_true(EntityCompositionService.try_register(context))
	assert_eq(published.size(), 2)
	assert_ne(published[0], published[1])

	# A route operation on one actor cannot mutate another actor's compiled navigation state.
	published[0].points.append(Vector3(1, 0, 2))
	published[0].pending = true
	published[0].blocked_seconds = 3.0
	assert_true(published[1].points.is_empty())
	assert_false(published[1].pending)
	assert_eq(published[1].blocked_seconds, 0.0)
#endregion


#region Route participation reconstruction
## Explicit reset clears route data without removing/reinstalling the initial capability.
func test_brain_reset_retains_the_compiled_route_without_component_events() -> void:
	var person: NpcRecord = NpcPopulationRules.initial_records(_DISTRICT, 1)[0]
	var actor: E_DistrictNpc = _SCENE.instantiate() as E_DistrictNpc
	assert_true(
		EntityCompositionService.try_register(_context(actor, person, "fixture/reset_route"))
	)
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	route.points.append(Vector3(3, 0, 4))
	route.map_iteration = 12
	route.pending = true
	route.elapsed = 1.5
	var changes: Array[Component] = []
	actor.component_added.connect(
		func(_subject: Entity, component: Component) -> void:
			changes.append(component),
	)
	actor.component_removed.connect(
		func(_subject: Entity, component: Component) -> void:
			changes.append(component),
	)

	DistrictPopulationService.reset_brain(actor)
	assert_same(actor.get_component(C_NpcRoute), route)
	assert_true(changes.is_empty())
	assert_true(route.points.is_empty())
	assert_eq(route.map_iteration, -1)
	assert_false(route.pending)
	assert_eq(route.elapsed, 0.0)
#endregion
