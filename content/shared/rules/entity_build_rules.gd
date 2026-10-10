extends RefCounted
## Pure flat composition validation before registration, engine setup, saved overlay and ready.
class_name EntityBuildRules


#region Side-effect-free compilation
## Compiles optional Traits and scene/code providers without changing their inputs or World.
static func compile(
	authored_traits: Array[EntityTrait],
	scene_recipes: Array[Component],
	code_recipes: Array[Component],
	context: EntitySpawnContext,
) -> EntityBuildPlan:
	var plan: EntityBuildPlan = EntityBuildPlan.new()
	plan.built_actor = context.actor
	plan.built_world = context.world
	plan.built_actor_id = context.actor_id
	if context.actor == null or not is_instance_valid(context.actor):
		_issue(plan, context, &"missing_instance", "Build context requires a scene instance")
		return plan
	if context.actor_id.is_empty():
		_issue(plan, context, &"missing_identity", "Build boundary must supply instance identity")

	var providers: Dictionary[Script, Component] = { }
	var configured_fields: Dictionary[Script, Dictionary] = { }
	_contribute(plan, context, providers, scene_recipes, "scene")
	_contribute(plan, context, providers, code_recipes, "code")

	# Sort by declared capability ID; duplicate IDs/providers never become order-based overrides.
	var traits: Array[EntityTrait] = authored_traits.duplicate()
	traits.sort_custom(_trait_before)
	var seen_traits: Dictionary[StringName, bool] = { }
	var enabled_traits: Array[EntityTrait] = []
	for capability: EntityTrait in traits:
		_check_trait_identity(plan, context, capability, seen_traits)
		if capability == null:
			continue
		var source: String = _trait_source(capability)
		if not capability.enabled_for(context):
			continue
		enabled_traits.append(capability)
		for message: String in capability.configuration_issues(context):
			_issue(plan, context, &"invalid_configuration", message, capability)
		_validate_structure(plan, context, capability)
		_contribute(plan, context, providers, capability.recipes_for(context), source, capability)
		_contribute_fields(
			plan,
			context,
			configured_fields,
			capability.configuration_for(context),
			_trait_source(capability),
			capability,
		)

	# Requirements see the complete provider set, independent of declaration/order.
	var binding_providers: Dictionary[Script, Array] = { }
	for capability: EntityTrait in enabled_traits:
		for required_script: Script in capability.required_components:
			if required_script == null or not providers.has(required_script):
				_issue(
					plan,
					context,
					&"missing_component",
					"Required Component provider is absent",
					capability,
				)
		_validate_binding_recipes(
			plan,
			context,
			capability.initial_bindings,
			binding_providers,
			capability,
			_trait_source(capability),
		)
	_validate_binding_recipes(
		plan,
		context,
		context.initial_bindings,
		binding_providers,
		null,
		"context",
	)
	_contribute_instance_fields(plan, context, enabled_traits, configured_fields)
	_validate_fields(plan, context, providers, configured_fields)
	if not plan.valid():
		plan.bindings.clear()
		return plan

	var ordered_scripts: Array[Script] = []
	ordered_scripts.assign(providers.keys())
	ordered_scripts.sort_custom(_script_before)
	for component_script: Script in ordered_scripts:
		var recipe: Component = EntityRecipeRules.copy_component(providers[component_script])
		if configured_fields.has(component_script):
			var initial_fields: Dictionary = configured_fields[component_script]
			for field_name: StringName in initial_fields:
				recipe.set(field_name, initial_fields[field_name])
			# Field inputs may contain typed containers/records; isolate that final aggregate too.
			recipe = EntityRecipeRules.copy_component(recipe)
		plan.component_recipes.append(recipe)
	return plan
#endregion


#region Whole-set registration validation
## Validates the whole prepared set before any native registration; one rejection aborts every plan.
## This gate never assigns IDs, binds ECS.world, replaces registry entries or publishes readiness.
static func validate_registration_batch(
	contexts: Array[EntitySpawnContext],
	plans: Array[EntityBuildPlan],
) -> bool:
	assert(contexts.size() == plans.size(), "Every prepared actor requires one build plan")
	if contexts.is_empty():
		return true

	var expected_world: World = contexts[0].world
	var prepared_actors: Dictionary[Entity, bool] = { }
	var entity_ids: Dictionary[String, String] = { }
	var stable_ids: Dictionary[String, String] = { }
	if expected_world != null:
		for existing: Entity in expected_world.entities:
			var existing_recipes: Array[Component] = []
			existing_recipes.assign(existing.components.values())
			for actor_key: String in _stable_keys(existing_recipes):
				stable_ids[actor_key] = "registered Entity %s" % existing.id

	# All candidate identities are checked before any endpoint is accepted as prepared.
	for build_index: int in contexts.size():
		var context: EntitySpawnContext = contexts[build_index]
		var plan: EntityBuildPlan = plans[build_index]
		if plan.built_actor != context.actor or plan.built_world != context.world \
				or plan.built_actor_id != context.actor_id:
			_issue(
				plan,
				context,
				&"inconsistent_plan",
				"Build plan belongs to a different instance, World or captured identity",
			)
		if context.world != expected_world:
			_issue(plan, context, &"different_world", "Build set requires one explicit World")
		if context.actor == null or not is_instance_valid(context.actor):
			_issue(plan, context, &"missing_instance", "Prepared scene instance is absent")
			continue
		if not context.actor.components.is_empty():
			_issue(
				plan,
				context,
				&"preinstalled_components",
				"Native initialization requires uninstalled Component recipes",
			)
		if prepared_actors.has(context.actor):
			_issue(
				plan,
				context,
				&"duplicate_instance",
				"Scene instance appears twice in build set",
			)
		prepared_actors[context.actor] = true
		if context.actor_id.is_empty():
			_issue(
				plan,
				context,
				&"missing_identity",
				"Build boundary must supply instance identity",
			)
		elif entity_ids.has(context.actor_id):
			var existing_instance_path: String = entity_ids[context.actor_id]
			_issue(
				plan,
				context,
				&"duplicate_entity_id",
				"Entity ID %s also belongs to %s" % [context.actor_id, existing_instance_path],
			)
		else:
			entity_ids[context.actor_id] = context.instance_path
		if not context.actor.id.is_empty() and context.actor.id != context.actor_id:
			_issue(plan, context, &"identity_mismatch", "Context cannot silently rename Entity.id")
		if expected_world != null and expected_world.entity_id_registry.has(context.actor_id):
			_issue(plan, context, &"registered_entity_id", "Entity ID already exists in World")
		for actor_key: String in _stable_keys(plan.component_recipes):
			if stable_ids.has(actor_key):
				_issue(
					plan,
					context,
					&"duplicate_stable_id",
					"Actor key %s also belongs to %s" % [actor_key, stable_ids[actor_key]],
				)
			else:
				stable_ids[actor_key] = context.instance_path

	# A declared candidate endpoint must actually be in this accepted preparation set.
	var accepted: bool = true
	for build_index: int in contexts.size():
		var context: EntitySpawnContext = contexts[build_index]
		var plan: EntityBuildPlan = plans[build_index]
		for binding: EntityBuildPlan.Binding in plan.bindings:
			var target_registered: bool = expected_world != null \
					and expected_world.entities.has(binding.target)
			if not prepared_actors.has(binding.target) and not target_registered:
				_issue(plan, context, &"unprepared_binding", "Endpoint has no prepared build plan")
		accepted = accepted and plan.valid()
	if accepted:
		return true

	# No independently valid neighbour may accidentally register part of a rejected placed set.
	for build_index: int in plans.size():
		var plan: EntityBuildPlan = plans[build_index]
		if plan.valid():
			_issue(plan, contexts[build_index], &"batch_rejected", "Another build rejects this set")
		plan.component_recipes.clear()
		plan.bindings.clear()
	return false


static func _stable_keys(recipes: Array[Component]) -> Array[String]:
	var actor_keys: Array[String] = []
	for recipe: Component in recipes:
		var actor_key: String = ""
		if recipe is C_AuthoredIdentity:
			actor_key = (recipe as C_AuthoredIdentity).actor_key()
		elif recipe is C_ActorIdentityReference:
			var reference: C_ActorIdentityReference = recipe as C_ActorIdentityReference
			if reference.actor_key_priority() != C_ActorIdentityReference.Specificity.NONE:
				actor_key = reference.actor_key()
		if not actor_key.is_empty() and not actor_keys.has(actor_key):
			actor_keys.append(actor_key)
	return actor_keys
#endregion


#region Explicit initial field configuration
static func _contribute_fields(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	configured_fields: Dictionary[Script, Dictionary],
	declarations: Dictionary[Script, Dictionary],
	source: String,
	capability: EntityTrait = null,
) -> void:
	for component_script: Script in declarations:
		if component_script == null:
			_issue(
				plan,
				context,
				&"invalid_configuration",
				"Field configuration requires a Script",
				capability,
				source,
			)
			continue
		if not configured_fields.has(component_script):
			configured_fields[component_script] = { }
			plan.field_provenance[component_script] = { }
		var initial_fields: Dictionary = configured_fields[component_script]
		var field_sources: Dictionary = plan.field_provenance[component_script]
		for declared_name: Variant in declarations[component_script]:
			if not declared_name is StringName and not declared_name is String:
				_issue(
					plan,
					context,
					&"invalid_initial_field",
					"Field name requires text",
					capability,
					source,
				)
				continue
			var field_name: StringName = StringName(declared_name)
			if initial_fields.has(field_name):
				_issue(
					plan,
					context,
					&"duplicate_initial_field",
					"%s.%s is configured by both %s and %s"
					% [
						component_script.resource_path,
						field_name,
						field_sources[field_name],
						source,
					],
					capability,
					source,
				)
				continue
			initial_fields[field_name] = declarations[component_script][declared_name]
			field_sources[field_name] = source


static func _contribute_instance_fields(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	capabilities: Array[EntityTrait],
	configured_fields: Dictionary[Script, Dictionary],
) -> void:
	var allowed: Dictionary[Script, Dictionary] = { }
	for capability: EntityTrait in capabilities:
		for component_script: Script in capability.initial_field_names:
			if component_script == null:
				_issue(
					plan,
					context,
					&"invalid_initial_field_policy",
					"Instance field policy requires a Component Script",
					capability,
				)
				continue
			if not allowed.has(component_script):
				allowed[component_script] = { }
			var field_owners: Dictionary = allowed[component_script]
			for field_name: String in capability.initial_field_names[component_script]:
				var field_key: StringName = StringName(field_name)
				if field_owners.has(field_key):
					_issue(
						plan,
						context,
						&"duplicate_initial_field_policy",
						"Instance field %s has two policy owners" % field_key,
						capability,
					)
				else:
					field_owners[field_key] = _trait_source(capability)

	# Reject arbitrary factory fields before the shared declaration/type/isolation pass.
	var declarations: Dictionary[Script, Dictionary] = { }
	for component_script: Script in context.initial_fields:
		for declared_name: Variant in context.initial_fields[component_script]:
			if not declared_name is String and not declared_name is StringName:
				_issue(
					plan,
					context,
					&"invalid_initial_field",
					"Field name requires text",
					null,
					"context:initial_fields",
				)
				continue
			var field_name: StringName = StringName(declared_name)
			if not allowed.has(component_script) or not allowed[component_script].has(field_name):
				_issue(
					plan,
					context,
					&"unauthorized_initial_field",
					"Instance field %s is not declared by an enabled Trait" % field_name,
					null,
					"context:initial_fields",
				)
				continue
			if not declarations.has(component_script):
				declarations[component_script] = { }
			var initial_value: Variant = context.initial_fields[component_script][declared_name]
			declarations[component_script][field_name] = initial_value
	_contribute_fields(plan, context, configured_fields, declarations, "context:initial_fields")


static func _validate_fields(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	providers: Dictionary[Script, Component],
	configured_fields: Dictionary[Script, Dictionary],
) -> void:
	for component_script: Script in configured_fields:
		var initial_fields: Dictionary = configured_fields[component_script]
		if not providers.has(component_script):
			_issue(
				plan,
				context,
				&"missing_configuration_provider",
				"Configured Component %s has no provider" % component_script.resource_path,
			)
			continue
		var descriptors: Dictionary[StringName, Dictionary] = { }
		for descriptor: Dictionary in providers[component_script].get_property_list():
			if int(descriptor.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				descriptors[StringName(descriptor.name)] = descriptor
		for field_name: StringName in initial_fields:
			var source: String = String(plan.field_provenance[component_script][field_name])
			# Runtime parent/private state and Resource engine bookkeeping are never configurable.
			if field_name == &"parent" or String(field_name).begins_with("_") \
					or not descriptors.has(field_name):
				_issue(
					plan,
					context,
					&"invalid_initial_field",
					"%s is not a public Component data field" % field_name,
					null,
					source,
				)
				continue
			if not _matches_field_type(
				initial_fields[field_name],
				descriptors[field_name],
				providers[component_script].get(field_name),
			):
				_issue(
					plan,
					context,
					&"incompatible_initial_field",
					"%s has incompatible initial value" % field_name,
					null,
					source,
				)


static func _matches_field_type(
	initial_value: Variant,
	descriptor: Dictionary,
	existing_value: Variant,
) -> bool:
	var expected_type: int = int(descriptor.type)
	if expected_type == TYPE_NIL:
		return true
	if initial_value == null:
		return expected_type == TYPE_OBJECT
	if expected_type == TYPE_FLOAT and initial_value is int:
		return true
	if typeof(initial_value) != expected_type:
		return false
	if expected_type == TYPE_ARRAY:
		return (existing_value as Array).is_same_typed(initial_value as Array)
	if expected_type == TYPE_DICTIONARY:
		return (existing_value as Dictionary).is_same_typed(initial_value as Dictionary)
	if expected_type != TYPE_OBJECT:
		return true
	var expected_class: StringName = StringName(descriptor.get("class_name", &""))
	var reference: Object = initial_value as Object
	if expected_class.is_empty() or reference.is_class(String(expected_class)):
		return true
	# Object.is_class recognizes engine classes; custom data contracts use the Script hierarchy.
	var object_script: Script = reference.get_script() as Script
	while object_script != null:
		if object_script.get_global_name() == expected_class:
			return true
		object_script = object_script.get_base_script()
	return false
#endregion


#region Provider and scene requirements
static func _contribute(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	providers: Dictionary[Script, Component],
	recipes: Array[Component],
	source: String,
	capability: EntityTrait = null,
) -> void:
	for recipe: Component in recipes:
		if recipe == null:
			_issue(
				plan,
				context,
				&"missing_recipe",
				"Provider contains an empty Component",
				capability,
				source,
			)
			continue
		var component_script: Script = recipe.get_script() as Script
		if component_script == null:
			_issue(
				plan,
				context,
				&"invalid_recipe",
				"Component requires a data Script",
				capability,
				source,
			)
			continue
		if providers.has(component_script):
			_issue(
				plan,
				context,
				&"duplicate_provider",
				"%s is supplied by both %s and %s"
				% [component_script.resource_path, plan.provenance[component_script], source],
				capability,
				source,
			)
			continue
		providers[component_script] = recipe
		plan.provenance[component_script] = source


static func _validate_structure(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	capability: EntityTrait,
) -> void:
	if not capability.required_root_class.is_empty() \
			and not context.actor.is_class(String(capability.required_root_class)):
		_issue(
			plan,
			context,
			&"incompatible_root",
			"Required scene root class is absent",
			capability,
		)
	for node_path: NodePath in capability.required_nodes:
		if context.actor.get_node_or_null(node_path) == null:
			_issue(
				plan,
				context,
				&"missing_node",
				"Required scene node %s is absent" % node_path,
				capability,
			)


static func _validate_binding_recipes(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	recipes: Array[EntityInitialBinding],
	binding_providers: Dictionary[Script, Array],
	capability: EntityTrait,
	source: String,
) -> void:
	for recipe: EntityInitialBinding in recipes:
		if recipe == null or recipe.relation == null or recipe.endpoint.is_empty():
			_issue(
				plan,
				context,
				&"invalid_binding",
				"Binding requires data and a named endpoint",
				capability,
				source,
			)
			continue
		var endpoint: Entity = context.bindings.get(recipe.endpoint) as Entity
		if endpoint == null or not is_instance_valid(endpoint):
			if not recipe.optional:
				_issue(
					plan,
					context,
					&"missing_binding",
					"Required binding %s is absent" % recipe.endpoint,
					capability,
					source,
				)
			continue
		var in_world: bool = context.world != null and is_instance_valid(context.world) \
				and context.world.entities.has(endpoint)
		if endpoint not in context.candidate_actors and not in_world:
			_issue(
				plan,
				context,
				&"foreign_binding",
				"Binding %s belongs to another World/set" % recipe.endpoint,
				capability,
				source,
			)
			continue
		# Multiple targets of one relation type are valid; the same pair has one provider.
		var relation_script: Script = recipe.relation.get_script() as Script
		if relation_script == null:
			_issue(
				plan,
				context,
				&"invalid_binding",
				"Relationship requires a data Script",
				capability,
				source,
			)
			continue
		if not binding_providers.has(relation_script):
			binding_providers[relation_script] = []
		var targets: Array = binding_providers[relation_script]
		if targets.has(endpoint):
			_issue(
				plan,
				context,
				&"duplicate_binding",
				"Relationship endpoint has two providers",
				capability,
				source,
			)
			continue
		targets.append(endpoint)

		var binding: EntityBuildPlan.Binding = EntityBuildPlan.Binding.new()
		binding.relation = EntityRecipeRules.copy_component(recipe.relation)
		binding.target = endpoint
		binding.source = source
		plan.bindings.append(binding)
#endregion


#region Deterministic provenance and diagnostics
## Checks unused authored Templates with the same declaration rules as runtime compilation.
static func template_issues(
	template: DEF_EntityTemplate,
	instance_path: String = "",
) -> Array[EntityBuildPlan.Issue]:
	var context: EntitySpawnContext = EntitySpawnContext.new()
	context.instance_path = instance_path
	var plan: EntityBuildPlan = EntityBuildPlan.new()
	var seen: Dictionary[StringName, bool] = { }
	var traits: Array[EntityTrait] = template.traits.duplicate()
	traits.sort_custom(_trait_before)
	for capability: EntityTrait in traits:
		_check_trait_identity(plan, context, capability, seen)
	return plan.issues


static func _check_trait_identity(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	capability: EntityTrait,
	seen: Dictionary[StringName, bool],
) -> void:
	if capability == null:
		_issue(plan, context, &"missing_trait", "Template contains an empty Trait")
		return
	if capability.trait_id.is_empty():
		_issue(
			plan,
			context,
			&"missing_trait_identity",
			"Trait requires a capability ID",
			capability,
		)
	elif seen.has(capability.trait_id):
		_issue(plan, context, &"duplicate_trait", "Duplicate capability ID", capability)
	seen[capability.trait_id] = true


static func _trait_before(first: EntityTrait, second: EntityTrait) -> bool:
	if first == null:
		return second != null
	if second == null:
		return false
	return String(first.trait_id) < String(second.trait_id)


static func _script_before(first: Script, second: Script) -> bool:
	return first.resource_path < second.resource_path


static func _trait_source(capability: EntityTrait) -> String:
	return "trait:%s:%s" % [capability.trait_id, capability.resource_path]


static func _issue(
	plan: EntityBuildPlan,
	context: EntitySpawnContext,
	code: StringName,
	message: String,
	capability: EntityTrait = null,
	source: String = "",
) -> void:
	var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
	issue.code = code
	issue.message = message
	issue.instance_path = context.instance_path
	issue.trait_id = capability.trait_id if capability != null else &""
	issue.source = _trait_source(capability) if capability != null and source.is_empty() else source
	plan.issues.append(issue)
#endregion
