extends RefCounted
## Detached authoring diagnostics use the runtime compiler without entering a SceneTree or World.
class_name EntityAuthoringPreviewRules


#region Read-only scene compilation
## Inspects a caller-owned detached snapshot; identity recipes only change that disposable copy.
static func inspect_scene(scene_root: Node) -> Dictionary:
	assert(not scene_root.is_inside_tree(), "Preview must never run a live scene")
	var actors: Array[Entity] = []
	if scene_root is Entity:
		actors.append(scene_root as Entity)
	for child: Node in scene_root.find_children("*", "", true, false):
		if child is Entity:
			actors.append(child as Entity)
	var report: Dictionary = { "valid": true, "issues": [], "actors": [] }
	if not scene_root is Entity:
		for message: String in PlacedIdentityRules.compile_for(scene_root):
			(report.issues as Array).append(message)
			report.valid = false

	var contexts: Array[EntitySpawnContext] = []
	var plans: Array[EntityBuildPlan] = []
	for actor: Entity in actors:
		var actor_path: String = String(scene_root.get_path_to(actor))
		var actor_id: String = actor.id if not actor.id.is_empty() else "preview/%s" % actor_path
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			null,
			actor_id,
			actors,
		)
		context.instance_path = actor_path
		contexts.append(context)
	for message: String in NpcConstructionService.configure_placed(contexts):
		(report.issues as Array).append(message)
		report.valid = false
	for context: EntitySpawnContext in contexts:
		plans.append(EntityCompositionService.build_plan(context))
	if not EntityBuildRules.validate_registration_batch(contexts, plans):
		report.valid = false
	for index: int in actors.size():
		(report.actors as Array).append(_describe(contexts[index], plans[index]))
	return report


static func _describe(context: EntitySpawnContext, plan: EntityBuildPlan) -> Dictionary:
	var authoring: E_TraitedEntity = context.actor as E_TraitedEntity
	var authored_traits: Array[EntityTrait] = []
	if authoring != null:
		authored_traits.assign(authoring.traits)
	var traits: Array[String] = []
	for capability: EntityTrait in authored_traits:
		if capability != null:
			traits.append(String(capability.trait_id))
	var providers: Array[Dictionary] = []
	for component_script: Script in plan.provenance:
		var field_sources: Dictionary = plan.field_provenance.get(component_script, { }).duplicate()
		for field: Variant in field_sources:
			field_sources[field] = _source_for(String(field_sources[field]), authored_traits)
		providers.append(
			{
				"component": component_script.resource_path,
				"source": _source_for(plan.provenance[component_script], authored_traits),
				"fields": field_sources,
			}
		)
	var bindings: Array[Dictionary] = []
	for binding: EntityBuildPlan.Binding in plan.bindings:
		bindings.append(
			{
				"relationship": (binding.relation.get_script() as Script).resource_path,
				"target": String(context.actor.get_path_to(binding.target)),
				"source": _source_for(binding.source, authored_traits),
			}
		)
	var issues: Array[Dictionary] = []
	for issue: EntityBuildPlan.Issue in plan.issues:
		issues.append(
			{
				"code": String(issue.code),
				"message": _source_for(issue.message, authored_traits),
				"source": _source_for(issue.source, authored_traits),
				"trait": String(issue.trait_id),
			}
		)
	return {
		"path": context.instance_path,
		"valid": plan.valid(),
		"traits": traits,
		"authoring": "direct traits" if not authored_traits.is_empty() else "scene intrinsic",
		"instance_id": String(context.actor.get_meta(PlacedIdentityRules.LOCAL_ID_META, "")),
		"providers": providers,
		"bindings": bindings,
		"issues": issues,
	}


static func _source_for(source: String, authored_traits: Array[EntityTrait]) -> String:
	for capability: EntityTrait in authored_traits:
		if capability == null:
			continue
		var captured_source: String = "trait:%s:%s" % [
			capability.trait_id,
			capability.resource_path,
		]
		if captured_source in source:
			source = source.replace(
				captured_source,
				"trait:%s:%s"
				% [
					capability.trait_id,
					capability.get_meta(
						EntityAuthoringSnapshotRules.SOURCE_META,
						capability.resource_path,
					),
				],
			)
	return source
#endregion


#region Native asset dependency validation
## Rejects native resource cycles before ResourceLoader can instantiate a recursive scene graph.
static func dependency_issues(scene_path: String) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	_visit_resource(scene_path, [], { }, issues)
	return issues


static func _visit_resource(
	resource_path: String,
	ancestry: Array[String],
	visited: Dictionary[String, bool],
	issues: PackedStringArray,
) -> void:
	if ancestry.has(resource_path):
		issues.append(
			"Native authoring dependency cycle: %s -> %s" % [" -> ".join(ancestry), resource_path]
		)
		return
	if visited.has(resource_path):
		return
	visited[resource_path] = true
	var branch: Array[String] = ancestry.duplicate()
	branch.append(resource_path)
	for dependency: String in ResourceLoader.get_dependencies(resource_path):
		var target: String = dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if target.get_extension() in ["tscn", "tres", "scn", "res"]:
			_visit_resource(target, branch, visited, issues)
#endregion
