extends RefCounted
## Detached native scene checks reuse the runtime compiler with explicit factory inputs.
class_name ContentDoctorSceneRules


#region Authored scene and factory compilation
## Optional factory inputs describe this root prefab's actual producer; no scene enters the tree.
static func inspect(
	scene_root: Node,
	source: String,
	person: NpcRecord = null,
	district_definition: DEF_District = null,
	address: DEF_DistrictPlace = null,
) -> Array[ContentDoctorIssue]:
	assert(not scene_root.is_inside_tree(), "Content Doctor must not execute a live scene")
	var issues: Array[ContentDoctorIssue] = []
	var candidates: Array[Node] = [scene_root]
	candidates.append_array(scene_root.find_children("*", "", true, false))
	for candidate: Node in candidates:
		if not candidate is Entity:
			continue
		for recipe: Component in (candidate as Entity).component_resources:
			if recipe is C_District and (recipe as C_District).definition != null:
				issues.append_array(
					ContentDoctorResourceRules.inspect(
						(recipe as C_District).definition,
						"%s:%s/definition" % [source, scene_root.get_path_to(candidate)],
					)
				)
	if not issues.is_empty():
		return issues
	if not scene_root is Entity:
		var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(scene_root)
		for message: String in report["issues"]:
			issues.append(ContentDoctorIssue.error(&"scene_identity", source, ".", message))
		for actor_report: Dictionary in report["actors"]:
			for issue: Dictionary in actor_report["issues"]:
				issues.append(
					ContentDoctorIssue.error(
						StringName(issue["code"]),
						source,
						"%s/%s" % [actor_report["path"], issue["source"]],
						String(issue["message"]),
					)
				)
	else:
		_compile_prefab(scene_root, source, person, district_definition, address, issues)
	_check_native_animations(scene_root, source, issues)
	return issues


static func _compile_prefab(
	scene_root: Node,
	source: String,
	person: NpcRecord,
	district_definition: DEF_District,
	address: DEF_DistrictPlace,
	issues: Array[ContentDoctorIssue],
) -> void:
	var actors: Array[Entity] = [scene_root as Entity]
	for child: Node in scene_root.find_children("*", "", true, false):
		if child is Entity:
			actors.append(child as Entity)
	var contexts: Array[EntitySpawnContext] = []
	var plans: Array[EntityBuildPlan] = []
	for actor: Entity in actors:
		var actor_path: String = String(scene_root.get_path_to(actor))
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			null,
			actor.id if not actor.id.is_empty() else "doctor/%s" % actor_path,
			actors,
		)
		context.instance_path = actor_path
		if actor == scene_root:
			if person != null:
				assert(district_definition != null, "NPC producer requires its district definition")
				NpcConstructionService.configure_context(context, person, district_definition)
			if address != null:
				NpcConstructionService.configure_address(context, address)
		contexts.append(context)
		plans.append(EntityCompositionService.build_plan(context))
	EntityBuildRules.validate_registration_batch(contexts, plans)
	for index: int in plans.size():
		for issue: EntityBuildPlan.Issue in plans[index].issues:
			issues.append(
				ContentDoctorIssue.error(
					issue.code,
					source,
					"%s/%s" % [contexts[index].instance_path, issue.source],
					issue.message,
				)
			)
		for recipe: Component in plans[index].component_recipes:
			if recipe is C_NpcCombat and contexts[index].actor is E_NpcCharacter:
				_check_attack_animations(
					contexts[index].actor as E_NpcCharacter,
					recipe as C_NpcCombat,
					source,
					contexts[index].instance_path,
					issues,
				)
#endregion


#region Native animation names
static func _check_attack_animations(
	actor: E_NpcCharacter,
	combat: C_NpcCombat,
	source: String,
	actor_path: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	var attacks: Array[DEF_NpcAttack] = combat.melee_attacks.duplicate()
	attacks.append_array(combat.ranged_attacks)
	for attack: DEF_NpcAttack in attacks:
		if attack == null or attack.animation.is_empty():
			continue
		if actor.animation_player == null or not actor.animation_player.has_animation(
				attack.animation
			):
			issues.append(
				ContentDoctorIssue.error(
					&"animation_name",
					source,
					"%s/attack/%s" % [actor_path, attack.resource_path],
					"Attack animation is unavailable: %s" % attack.animation,
				)
			)


static func _check_native_animations(
	scene_root: Node,
	source: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	var candidates: Array[Node] = [scene_root]
	candidates.append_array(scene_root.find_children("*", "", true, false))
	for candidate: Node in candidates:
		var character: E_NpcCharacter = candidate as E_NpcCharacter
		if character == null or character.animation_player == null:
			continue
		for field: StringName in [&"idle_animation", &"walk_animation"]:
			var animation: StringName = StringName(character.get(field))
			if not character.animation_player.has_animation(animation):
				issues.append(
					ContentDoctorIssue.error(
						&"animation_name",
						source,
						"%s/%s" % [scene_root.get_path_to(character), field],
						"AnimationPlayer has no authored animation: %s" % animation,
					)
				)
#endregion
