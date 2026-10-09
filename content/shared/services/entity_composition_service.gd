extends RefCounted
## Explicit construction operations shared by placed/factory boundaries; this service never ticks.
class_name EntityCompositionService

## Scene metadata stores optional authoring inputs on any native/project Entity without a new base.
const AUTHORING_META: StringName = &"entity_composition"
const _PREPARED_META: StringName = &"_entity_recipes_prepared"

#region Read-only authoring and context
## Reads the optional scene-owned authoring Resource, without allocating a Template or changing it.
static func authoring_for(actor: Entity) -> EntityAuthoring:
	if not actor.has_meta(AUTHORING_META):
		return null
	var authoring_input: Variant = actor.get_meta(AUTHORING_META)
	return authoring_input as EntityAuthoring if authoring_input is EntityAuthoring else null


## Captures explicit World/identity inputs without assigning Entity.id or binding ECS.world.
static func context_for(actor: Entity, world: World, actor_id: String,
		candidates: Array[Entity] = []) -> EntitySpawnContext:
	var context: EntitySpawnContext = EntitySpawnContext.new()
	context.world = world
	context.actor = actor
	context.actor_id = actor_id
	context.instance_path = String(actor.get_path()) if actor.is_inside_tree() else String(actor.name)
	context.candidate_actors = candidates.duplicate()
	var authoring: EntityAuthoring = authoring_for(actor)
	if authoring == null:
		return context
	context.definitions = authoring.definitions.duplicate()
	for endpoint_name: StringName in authoring.bindings:
		var endpoint_path: NodePath = authoring.bindings[endpoint_name]
		context.bindings[endpoint_name] = actor.get_node_or_null(endpoint_path) as Entity
	if not authoring.ancestor_entity_bindings.is_empty():
		var ancestor: Node = actor.get_parent()
		while ancestor != null and not ancestor is Entity:
			ancestor = ancestor.get_parent()
		for endpoint_name: String in authoring.ancestor_entity_bindings:
			context.bindings[StringName(endpoint_name)] = ancestor as Entity
	return context


## Reads the construction marker used by retained pure native code providers.
static func recipes_prepared(actor: Entity) -> bool:
	return bool(actor.get_meta(_PREPARED_META, false))
#endregion

#region Common recipe compilation
## Captures scene/intrinsic/optional Template inputs for the one pure compiler entry point.
## Runtime factories and placed preparation use this same operation before native registration.
static func build_plan(context: EntitySpawnContext) -> EntityBuildPlan:
	var actor: Entity = context.actor
	if actor == null or not is_instance_valid(actor):
		return EntityBuildRules.compile(null, [], [], context)
	if recipes_prepared(actor):
		var rejected: EntityBuildPlan = EntityBuildPlan.new()
		var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
		issue.code = &"already_prepared"
		issue.message = "Scene instance already has prepared native recipes"
		issue.instance_path = context.instance_path
		rejected.issues.append(issue)
		return rejected
	var authoring_input: Variant = actor.get_meta(AUTHORING_META) \
		if actor.has_meta(AUTHORING_META) else null
	if authoring_input != null and not authoring_input is EntityAuthoring:
		var rejected: EntityBuildPlan = EntityBuildPlan.new()
		var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
		issue.code = &"invalid_authoring"
		issue.message = "Scene composition metadata requires EntityAuthoring"
		issue.instance_path = context.instance_path
		issue.source = String(AUTHORING_META)
		rejected.issues.append(issue)
		return rejected

	var authoring: EntityAuthoring = authoring_input as EntityAuthoring
	if authoring != null:
		var seen_endpoints: Dictionary[StringName, bool] = {}
		for endpoint_name: String in authoring.ancestor_entity_bindings:
			var endpoint_key: StringName = StringName(endpoint_name)
			if endpoint_key.is_empty() or authoring.bindings.has(endpoint_key) \
					or seen_endpoints.has(endpoint_key):
				var rejected: EntityBuildPlan = EntityBuildPlan.new()
				var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
				issue.code = &"invalid_authoring"
				issue.message = "Scene endpoint names require one nonempty authoring provider"
				issue.instance_path = context.instance_path
				issue.source = String(AUTHORING_META)
				rejected.issues.append(issue)
				return rejected
			seen_endpoints[endpoint_key] = true
	var template: DEF_EntityTemplate = authoring.entity_template if authoring != null else null
	var code_recipes: Array[Component] = []
	code_recipes.assign(actor.define_components())
	return EntityBuildRules.compile(template, actor.component_resources, code_recipes, context)
#endregion

#region Runtime factory registration
## Compiles and validates a factory instance before one native add_entity call.
## False leaves rejected unregistered instances with their caller; no ownership/payment is committed.
static func try_register(context: EntitySpawnContext, add_to_tree: bool = true) -> bool:
	var plan: EntityBuildPlan = registration_plan(context)
	return register_plan(context, plan, add_to_tree)


## Validates complete recipes and IDs without registering or assigning identity.
## A transaction may inspect this transient plan before committing payment/ownership.
static func registration_plan(context: EntitySpawnContext) -> EntityBuildPlan:
	var plan: EntityBuildPlan = build_plan(context)
	if context.world == null:
		var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
		issue.code = &"missing_world"
		issue.message = "Native registration requires an explicit World"
		issue.instance_path = context.instance_path
		issue.source = "context"
		plan.issues.append(issue)
	EntityBuildRules.validate_registration_batch([context], [plan])
	return plan


## Commits a plan within its synchronous transaction, after the owner's accepted preflight.
## No World mutation or lifetime boundary may intervene between preflight and this operation.
static func register_plan(context: EntitySpawnContext, plan: EntityBuildPlan,
		add_to_tree: bool = true) -> bool:
	if not plan.valid() or context.world == null:
		return false
	if not EntityBuildRules.validate_registration_batch([context], [plan]):
		return false
	var actor: Entity = context.actor
	if not prepare(actor, plan):
		return false

	# Native collision replacement is unreachable after identity/endpoint preflight.
	actor.id = context.actor_id
	context.world.add_entity(actor, null, add_to_tree)
	for binding: EntityBuildPlan.Binding in plan.bindings:
		assert(context.world.entities.has(actor) and context.world.entities.has(binding.target),
			"Factory binding endpoints require completed registration")
		actor.add_relationship(Relationship.new(binding.relation, binding.target))
	return true
#endregion

#region Prepared native recipes
## Accepts validated recipes before registration; rejects live/previously prepared instances.
## The World/factory owner still validates identity, saved overlay, endpoints and readiness.
static func prepare(actor: Entity, plan: EntityBuildPlan) -> bool:
	if not plan.valid() or plan.built_actor != actor \
			or recipes_prepared(actor) or not actor.components.is_empty():
		return false
	actor.component_resources = plan.component_recipes
	actor.set_meta(_PREPARED_META, true)
	return true
#endregion
