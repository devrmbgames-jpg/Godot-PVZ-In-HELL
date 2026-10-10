extends GutTest
## Production package Template/Profile compilation, isolation and duplicate-provider rejection.

const _PACKAGE: PackedScene = preload("res://content/domains/packages/entities/package.tscn")
const _TEMPLATE: DEF_EntityTemplate = preload(
	"res://content/domains/packages/definitions/def_entity_package.tres"
)


#region Profile-derived package capabilities
## Profile defaults replace exact fresh fields, while scene shape and source recipes stay intact.
func test_package_profile_compiles_health_impact_contents_and_liquid_before_registration() -> void:
	var parcel: E_Package = autofree(_PACKAGE.instantiate()) as E_Package
	var definition: DEF_Package = parcel.package_definition.duplicate() as DEF_Package
	definition.maximum_health = 73.0
	definition.throw_velocity = 5.5
	definition.tags |= DEF_Package.Tag.LIQUID
	definition.liquid_maximum_angle_degrees = 35.0
	definition.liquid_tilt_seconds = 4.0
	definition.liquid_tilt_damage = 7.0
	parcel.package_definition = definition
	var original_health: C_Health = _recipe(parcel.component_resources, C_Health) as C_Health
	var original_current: float = original_health.current
	var original_carry: C_Grabbable = (
		_recipe(parcel.component_resources, C_Grabbable) as C_Grabbable
	)
	var original_throw: float = original_carry.throw_velocity
	var plan: EntityBuildPlan = _compile(parcel)
	assert_true(plan.valid())
	var health: C_Health = _recipe(plan.component_recipes, C_Health) as C_Health
	var receiver: C_ImpactReceiver = (
		_recipe(plan.component_recipes, C_ImpactReceiver) as C_ImpactReceiver
	)
	var identity: C_Package = _recipe(plan.component_recipes, C_Package) as C_Package
	var tilt: C_LiquidTilt = _recipe(plan.component_recipes, C_LiquidTilt) as C_LiquidTilt
	assert_eq(health.current, 73.0)
	assert_eq(health.value, 73.0)
	assert_eq(health.base, 73.0)
	assert_same(receiver.profile, definition.impact_profile)
	assert_true(identity.condition_initialized)
	assert_not_null(_recipe(plan.component_recipes, C_PackageContents))
	assert_eq(tilt.maximum_angle_degrees, 35.0)
	assert_eq(tilt.duration_seconds, 4.0)
	assert_eq(tilt.damage_amount, 7.0)
	assert_eq(original_health.current, original_current)
	assert_eq((_recipe(plan.component_recipes, C_Grabbable) as C_Grabbable).throw_velocity, 5.5)
	assert_eq(original_carry.throw_velocity, original_throw)
	assert_true(parcel.components.is_empty())
	assert_eq(parcel.id, "")


## Same Template/Profile creates isolated mutable defaults for two physical package instances.
func test_two_package_builds_share_profile_and_isolate_health_and_liquid_state() -> void:
	var first: E_Package = autofree(_PACKAGE.instantiate()) as E_Package
	var second: E_Package = autofree(_PACKAGE.instantiate()) as E_Package
	var definition: DEF_Package = first.package_definition.duplicate() as DEF_Package
	definition.tags |= DEF_Package.Tag.LIQUID
	first.package_definition = definition
	second.package_definition = definition
	var first_plan: EntityBuildPlan = _compile(first)
	var second_plan: EntityBuildPlan = _compile(second)
	assert_true(first_plan.valid())
	assert_true(second_plan.valid())
	var first_health: C_Health = _recipe(first_plan.component_recipes, C_Health) as C_Health
	var second_health: C_Health = _recipe(second_plan.component_recipes, C_Health) as C_Health
	first_health.current = 3.0
	assert_eq(second_health.current, definition.maximum_health)
	assert_ne(first_health, second_health)
	var first_tilt: C_LiquidTilt = (
		_recipe(first_plan.component_recipes, C_LiquidTilt) as C_LiquidTilt
	)
	var second_tilt: C_LiquidTilt = (
		_recipe(second_plan.component_recipes, C_LiquidTilt) as C_LiquidTilt
	)
	first_tilt.unsafe_seconds = 2.0
	assert_eq(second_tilt.unsafe_seconds, 0.0)
	assert_same(
		(_recipe(first_plan.component_recipes, C_Package) as C_Package).definition,
		definition,
	)
	assert_same(
		(_recipe(second_plan.component_recipes, C_Package) as C_Package).definition,
		definition,
	)


## An authored duplicate conflicts with the production Trait rather than replacing its provider.
func test_authored_contents_and_production_trait_conflict_is_not_silently_overridden() -> void:
	var parcel: E_Package = autofree(_PACKAGE.instantiate()) as E_Package
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		parcel,
		null,
		"fixture/package/authored_conflict",
	)
	parcel.component_resources = parcel.component_resources.duplicate()
	parcel.component_resources.append(C_PackageContents.new())
	var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
	assert_false(plan.valid())
	assert_eq(plan.issues[0].code, &"duplicate_provider")
	assert_true(plan.component_recipes.is_empty())
	assert_true(parcel.components.is_empty())


## Native publication observes the complete Profile defaults and contributes each class once.
func test_native_package_registration_publishes_complete_profile_without_default_observer() -> void:
	var world: World = World.new()
	add_child(world)
	var parcel: E_Package = _PACKAGE.instantiate() as E_Package
	var definition: DEF_Package = parcel.package_definition.duplicate() as DEF_Package
	definition.maximum_health = 73.0
	definition.throw_velocity = 5.5
	definition.tags |= DEF_Package.Tag.LIQUID
	parcel.package_definition = definition
	parcel.package_id = "fixture/package/native"
	var delivered: Array[Script] = []
	var published_health: Array[float] = []
	var published_day: Array[int] = []
	var published_throw: Array[float] = []
	var published_supply: Array[StringName] = []
	parcel.component_added.connect(
		func(_actor: Entity, component: Component) -> void:
			delivered.append(component.get_script() as Script),
	)
	world.entity_added.connect(
		func(actor: Entity) -> void:
			published_health.append((actor.get_component(C_Health) as C_Health).current)
			published_throw.append((actor.get_component(C_Grabbable) as C_Grabbable).throw_velocity)
			var identity: C_Package = actor.get_component(C_Package) as C_Package
			published_day.append(identity.delivery_day)
			published_supply.append(identity.supply_key),
	)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		parcel,
		world,
		"fixture/package/native_actor",
	)
	context.initial_fields[C_Package as Script] = {
		&"delivery_day": 11,
		&"supply_key": &"fixture_supply",
	}
	assert_true(EntityCompositionService.try_register(context))
	assert_eq(world.entities.size(), 1)
	assert_eq(published_health, [73.0])
	assert_eq(published_throw, [5.5])
	assert_eq(published_day, [11])
	assert_eq(published_supply, [&"fixture_supply"])
	assert_eq(delivered.count(C_Health as Script), 1)
	assert_eq(delivered.count(C_PackageContents as Script), 1)
	assert_eq(delivered.count(C_LiquidTilt as Script), 1)
	assert_true((parcel.get_component(C_Package) as C_Package).condition_initialized)
	assert_same(
		(parcel.get_component(C_ImpactReceiver) as C_ImpactReceiver).profile,
		definition.impact_profile,
	)
	world.purge(false)
	world.free()
#endregion


#region Pure compilation fixture
func _compile(parcel: E_Package) -> EntityBuildPlan:
	parcel.package_id = "fixture/package"
	var authoring: E_TraitedEntity = (parcel as E_TraitedEntity)
	assert_eq(authoring.traits.size(), _TEMPLATE.traits.size())
	assert_eq(authoring.traits[0].trait_id, _TEMPLATE.traits[0].trait_id)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		parcel,
		null,
		"fixture/package/actor",
	)
	return EntityCompositionService.build_plan(context)


func _recipe(recipes: Array[Component], expected_script: Script) -> Component:
	for recipe: Component in recipes:
		if recipe.get_script() == expected_script:
			return recipe
	return null
#endregion


#region Receiving Profile inputs
## Factory input capture preserves scene prototypes; the common compiler owns carry defaults.
func test_receiving_profile_input_capture_does_not_rewrite_carry_recipe() -> void:
	var parcel: E_Package = autofree(_PACKAGE.instantiate()) as E_Package
	var carry: C_Grabbable = _recipe(parcel.component_resources, C_Grabbable) as C_Grabbable
	var original_throw: float = carry.throw_velocity
	var definition: DEF_Package = parcel.package_definition.duplicate() as DEF_Package
	definition.throw_velocity = 8.0
	definition.mass_kg = 2.5
	assert_true(ReceivingPackageFactory.configure_recipe(parcel, definition, "fixture/receiving"))
	assert_same(_recipe(parcel.component_resources, C_Grabbable), carry)
	assert_eq(carry.throw_velocity, original_throw)
	assert_eq((parcel as Node as RigidBody3D).mass, 2.5)
	var plan: EntityBuildPlan = _compile(parcel)
	assert_true(plan.valid())
	assert_eq((_recipe(plan.component_recipes, C_Grabbable) as C_Grabbable).throw_velocity, 8.0)
	assert_true(parcel.components.is_empty())


## Missing carry configuration rejects in the common compiler before native publication.
func test_package_profile_missing_carry_rejects_before_registration() -> void:
	var world: World = World.new()
	add_child(world)
	var parcel: E_Package = autofree(_PACKAGE.instantiate()) as E_Package
	var kept: Array[Component] = []
	for recipe: Component in parcel.component_resources:
		if not recipe is C_Grabbable:
			kept.append(recipe)
	parcel.component_resources = kept
	parcel.package_id = "fixture/receiving/missing_carry"
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		parcel,
		world,
		"fixture/receiving/missing_carry",
	)
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	assert_false(plan.valid())
	assert_false(EntityCompositionService.register_plan(context, plan))
	assert_true(world.entities.is_empty())
	assert_true(world.entity_id_registry.is_empty())
	assert_true(parcel.components.is_empty())
	assert_eq(parcel.id, "")
	world.free()
#endregion
