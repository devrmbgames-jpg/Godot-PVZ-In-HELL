extends RefCounted
## Registers fixture instances through production recipe validation before native GECS initialization.
class_name EntityCompositionFixture

#region Explicit fixture construction
## Supplies package/actor IDs and commits one common native registration; rejects broken fixtures.
static func register(world: World, actor: Entity, add_to_tree: bool = true) -> void:
	if actor is E_Package:
		var parcel: E_Package = actor as E_Package
		if parcel.package_id.is_empty():
			parcel.package_id = GECSIO.uuid()
	var actor_id: String = actor.id if not actor.id.is_empty() else GECSIO.uuid()
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, world, actor_id)
	_register(context, add_to_tree)


## Compiles the selected visit policy and ID before native Customer fixture publication.
static func register_visit(world: World, actor: E_NpcCharacter, visit: CustomerVisit) -> void:
	var actor_id: String = actor.id if not actor.id.is_empty() else GECSIO.uuid()
	var context: EntitySpawnContext = EntityCompositionService.context_for(actor, world, actor_id)
	context.definitions[&"customer_policy"] = visit.definition
	context.initial_fields[C_CustomerAgent as Script] = {&"visit_id": visit.visit_id}
	_register(context, true)


static func _register(context: EntitySpawnContext, add_to_tree: bool) -> void:
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	var diagnostics: PackedStringArray = PackedStringArray()
	for issue: EntityBuildPlan.Issue in plan.issues:
		diagnostics.append("%s: %s (%s)" % [issue.code, issue.message, issue.source])
	assert(plan.valid(), "Invalid fixture composition: " + "; ".join(diagnostics))
	var registered: bool = EntityCompositionService.register_plan(context, plan, add_to_tree)
	assert(registered, "Fixture requires accepted entity composition before native registration")
#endregion
