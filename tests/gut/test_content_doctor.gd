extends GutTest
## Pure content diagnostics include real pinned compiler tokens without executing mutations.

const _AUTHORING_LEVEL: PackedScene = preload(
	"res://tests/fixtures/refactoring_v2/authoring_level.tscn"
)
const _NPC_PREFAB: PackedScene = preload("res://content/domains/npc/entities/npc_character.tscn")


## A declared action lets the fixture detect accidental context instantiation/execution.
class ContextProbe extends RefCounted:
	## Number of actual effects; static inspection must leave it zero.
	static var effects: int = 0


	#region Declared context
	func commit() -> bool:
		effects += 1
		return true


	func choose(_required: int, _optional: int = 2) -> bool:
		effects += 1
		return true
	#endregion


#region Definition diagnostics
func test_invalid_exported_range_has_source_and_field() -> void:
	var definition: DEF_TraderProfile = DEF_TraderProfile.new()
	definition.repeat_days = 0
	var issues: Array[ContentDoctorIssue] = ContentDoctorResourceRules.inspect(
		definition,
		"res://".path_join("broken/trader.tres"),
	)
	assert_eq(issues.size(), 1)
	assert_eq(issues[0].code, &"definition_range")
	assert_eq(issues[0].source, "res://".path_join("broken/trader.tres"))
	assert_eq(issues[0].field, "repeat_days")


func test_invalid_schedule_locations_and_weekdays_reject() -> void:
	var schedule: DEF_NpcSchedule = DEF_NpcSchedule.new()
	schedule.set("morning", 999)
	schedule.weekdays = PackedInt32Array([7])
	var issues: Array[ContentDoctorIssue] = ContentDoctorResourceRules.inspect(
		schedule,
		"res://".path_join("broken/schedule.tres"),
	)
	assert_eq(issues.size(), 2)
	assert_eq(issues[0].code, &"schedule_location")
	assert_eq(issues[1].code, &"schedule_weekday")


func test_base_action_is_not_an_executor() -> void:
	var issues: Array[ContentDoctorIssue] = ContentDoctorResourceRules.inspect(
		DEF_InteractionAction.new(),
		"res://".path_join("broken/action.tres"),
	)
	assert_eq(issues.size(), 1)
	assert_eq(issues[0].code, &"action_executor")


func test_missing_definition_scene_path_and_reversed_attack_range_reject() -> void:
	var profile: DEF_NpcProfile = DEF_NpcProfile.new()
	profile.schedule = DEF_NpcSchedule.new()
	profile.npc_scene_path = "res://".path_join("missing/doctor_npc.tscn")
	var issues: Array[ContentDoctorIssue] = ContentDoctorResourceRules.inspect(profile, "profile")
	assert_eq(issues.size(), 1)
	assert_eq(issues[0].code, &"resource_path")
	assert_eq(issues[0].field, "npc_scene_path")
	var attack: DEF_NpcAttack = DEF_NpcAttack.new()
	attack.minimum_range = attack.maximum_range + 1.0
	attack.windup_seconds = -1.0
	issues = ContentDoctorResourceRules.inspect(attack, "attack")
	assert_eq(issues.size(), 2)
	assert_eq(issues[0].field, "windup_seconds")
	assert_eq(issues[1].field, "minimum_range")


func test_duplicate_district_place_and_missing_route_key_have_fields() -> void:
	var district: DEF_District = DEF_District.new()
	var first: DEF_DistrictPlace = DEF_DistrictPlace.new()
	first.key = &"home"
	var second: DEF_DistrictPlace = DEF_DistrictPlace.new()
	second.key = first.key
	district.places = [first, second]
	district.shade_refuge = &"missing"
	var issues: Array[ContentDoctorIssue] = ContentDoctorResourceRules.inspect(district, "district")
	assert_eq(issues.size(), 2)
	assert_eq(issues[0].field, "places/1")
	assert_eq(issues[1].field, "shade_route/shade_refuge")
#endregion


#region Real compiled dialogue diagnostics
func test_imported_customer_dialogue_uses_declared_context_without_execution() -> void:
	var dialogue: DialogueResource = load(CustomerDialogueService.DIALOGUE_PATH) as DialogueResource
	var issues: Array[ContentDoctorIssue] = ContentDoctorDialogueRules.inspect(
		dialogue,
		CustomerDialogueContext,
		PackedStringArray(["direct"]),
		PackedStringArray(["hon", "lie", "prs", "thr", "flr", "jok", "sub"]),
		CustomerDialogueService.DIALOGUE_PATH,
	)
	for issue: ContentDoctorIssue in issues:
		print(issue.data())
	assert_true(issues.is_empty())


func test_compiled_missing_method_is_rejected_and_declared_action_is_never_called() -> void:
	ContextProbe.effects = 0
	var dialogue: DialogueResource = _compile(
		"~ start\n$> ctx.commit()\n$> ctx.missing_method()\nSpeaker: Done.\n=> END",
	)
	var issues: Array[ContentDoctorIssue] = _inspect_probe(dialogue)
	assert_eq(issues.size(), 1)
	assert_eq(issues[0].code, &"dialogue_context_method")
	assert_true(issues[0].message.contains("missing_method"))
	assert_eq(ContextProbe.effects, 0)


func test_unsupported_dynamic_expression_requires_review_without_execution() -> void:
	var dialogue: DialogueResource = _compile(
		"~ start\n$> arbitrary_global()\nSpeaker: Done.\n=> END",
	)
	var issues: Array[ContentDoctorIssue] = _inspect_probe(dialogue)
	assert_eq(issues.size(), 1)
	assert_eq(issues[0].severity, ContentDoctorIssue.Severity.REVIEW_REQUIRED)
	assert_eq(issues[0].code, &"dialogue_dynamic_expression")


func test_missing_entry_cue_and_undeclared_tag_have_imported_line_context() -> void:
	var dialogue: DialogueResource = _compile(
		"~ other\nSpeaker: Choose.\n- Response. [#unknown] => END",
	)
	var issues: Array[ContentDoctorIssue] = _inspect_probe(dialogue)
	assert_eq(issues.size(), 2)
	assert_eq(issues[0].code, &"dialogue_cue")
	assert_eq(issues[1].code, &"dialogue_tag")
	assert_true(issues[1].field.begins_with("lines/"))


func test_native_context_arguments_validate_required_and_default_parameters_without_calls() -> void:
	ContextProbe.effects = 0
	var valid: DialogueResource = _compile(
		"~ start\n$> ctx.choose(1)\n$> ctx.choose(1, 2)\nSpeaker: Done.\n=> END",
	)
	assert_true(_inspect_probe(valid).is_empty())
	var invalid: DialogueResource = _compile(
		"~ start\n$> ctx.choose()\n$> ctx.choose(1, 2, 3)\nSpeaker: Done.\n=> END",
	)
	var issues: Array[ContentDoctorIssue] = _inspect_probe(invalid)
	assert_eq(issues.size(), 2)
	for issue: ContentDoctorIssue in issues:
		assert_eq(issue.code, &"dialogue_context_arguments")
	assert_eq(ContextProbe.effects, 0)


func test_broken_imported_response_concurrent_and_case_links_reject() -> void:
	var dialogue: DialogueResource = _compile("~ start\nSpeaker: Done.\n=> END")
	var first: Dictionary = dialogue.lines[dialogue.cues["start"]] as Dictionary
	first["responses"] = PackedStringArray(["missing_response"])
	first["concurrent_lines"] = PackedStringArray(["missing_concurrent"])
	first["cases"] = [{ "next_id": "missing_case" }]
	var issues: Array[ContentDoctorIssue] = _inspect_probe(dialogue)
	assert_eq(issues.size(), 3)
	for issue: ContentDoctorIssue in issues:
		assert_eq(issue.code, &"dialogue_link")


func _compile(text: String) -> DialogueResource:
	var compiled: DMCompilerResult = DMCompiler.compile_string(
		text,
		"res://".path_join("broken/dialogue.dialogue"),
	)
	assert_true(compiled.errors.is_empty())
	var resource: DialogueResource = DialogueResource.new()
	resource.cues = compiled.cues
	resource.lines = compiled.lines
	return resource


func _inspect_probe(dialogue: DialogueResource) -> Array[ContentDoctorIssue]:
	return ContentDoctorDialogueRules.inspect(
		dialogue,
		ContextProbe,
		PackedStringArray(["start"]),
		PackedStringArray(),
		"res://".path_join("broken/dialogue.dialogue"),
	)
#endregion


#region Native compiler aggregation
func test_template_requirements_bindings_and_capabilities_keep_owner_diagnostics() -> void:
	var actor: Entity = autofree(Entity.new()) as Entity
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"broken_capability"
	capability.required_components = [C_Health]
	capability.required_root_class = &"RigidBody3D"
	capability.required_nodes = [NodePath("MissingShape")]
	var binding: EntityInitialBinding = EntityInitialBinding.new()
	binding.relation = R_CombatTarget.new()
	binding.endpoint = &"victim"
	capability.initial_bindings = [binding]
	_attach_traits(actor, [capability])
	var issues: Array[ContentDoctorIssue] = ContentDoctorSceneRules.inspect(actor, "broken_prefab")
	var codes: Array[StringName] = _codes(issues)
	assert_has(codes, &"missing_component")
	assert_has(codes, &"incompatible_root")
	assert_has(codes, &"missing_node")
	assert_has(codes, &"missing_binding")
	for issue: ContentDoctorIssue in issues:
		assert_eq(issue.source, "broken_prefab")
		assert_string_contains(issue.field, "trait:broken_capability")
	assert_eq(actor.ecs_id, 0)
	assert_false(actor.is_inside_tree())
	assert_true(actor.components.is_empty())
	assert_true(actor.relationships.is_empty())


func test_null_and_duplicate_traits_are_rejected_by_common_compiler() -> void:
	var actor: Entity = autofree(Entity.new()) as Entity
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"duplicate"
	_attach_traits(actor, [null, capability, capability])
	var issues: Array[ContentDoctorIssue] = ContentDoctorSceneRules.inspect(
		actor,
		"broken_template",
	)
	assert_has(_codes(issues), &"missing_trait")
	assert_has(_codes(issues), &"duplicate_trait")


func test_unused_template_still_validates_through_shared_declaration_provider() -> void:
	var template: DEF_EntityTemplate = DEF_EntityTemplate.new()
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"duplicate"
	template.traits = [null, capability, capability]
	var issues: Array[ContentDoctorIssue] = ContentDoctorResourceRules.inspect(
		template,
		"unused_template",
	)
	assert_eq(issues.size(), 2)
	assert_has(_codes(issues), &"missing_trait")
	assert_has(_codes(issues), &"duplicate_trait")
	assert_eq(template.traits.size(), 3)
	assert_null(template.traits[0])


func test_smart_object_missing_marker_slot_and_executor_reuse_owner_provider() -> void:
	var actor: Entity = autofree(Entity.new()) as Entity
	var definition: DEF_SmartObject = DEF_SmartObject.new()
	var slot: DEF_SmartSlot = DEF_SmartSlot.new()
	slot.slot_id = &"desk"
	slot.marker = NodePath("MissingMarker")
	definition.slots = [slot]
	var affordance: DEF_SmartAffordance = DEF_SmartAffordance.new()
	affordance.affordance_id = &"return"
	affordance.slot_id = &"other"
	definition.affordances = [affordance]
	var capability: ET_SmartObject = ET_SmartObject.new()
	capability.definition = definition
	_attach_traits(actor, [capability])
	var issues: Array[ContentDoctorIssue] = ContentDoctorSceneRules.inspect(
		actor,
		"broken_smart_object",
	)
	assert_eq(issues.size(), 3)
	var messages: String = JSON.stringify(
		issues.map(
			func(issue: ContentDoctorIssue) -> Dictionary:
				return issue.data(),
		)
	)
	assert_string_contains(messages, "Marker3D")
	assert_string_contains(messages, "missing slot other")
	assert_string_contains(messages, "concrete executor")


func test_duplicate_placed_identity_and_missing_native_animation_have_instance_context() -> void:
	var level: Node = autofree(_AUTHORING_LEVEL.instantiate()) as Node
	var resident: E_NpcCharacter = level.get_node("Resident") as E_NpcCharacter
	resident.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"trader")
	resident.walk_animation = &"MissingWalk"
	var issues: Array[ContentDoctorIssue] = ContentDoctorSceneRules.inspect(level, "broken_level")
	var messages: String = JSON.stringify(
		issues.map(
			func(issue: ContentDoctorIssue) -> Dictionary:
				return issue.data(),
		)
	)
	assert_string_contains(messages, "Duplicate placed identity")
	assert_string_contains(messages, "Resident/walk_animation")
	assert_string_contains(messages, "MissingWalk")
	assert_false(level.is_inside_tree())
	assert_eq(resident.ecs_id, 0)


func test_native_resource_cycle_blocks_before_scene_instantiation() -> void:
	var doctor: ContentDoctor = ContentDoctor.new()
	var report: Dictionary = doctor.scan_paths(
		PackedStringArray(["res://tests/fixtures/refactoring_v2/authoring_cycle_scene.tscn"])
	)
	assert_false(report.valid)
	assert_eq(report.scenes, 0)
	assert_eq(report.errors, 1)
	assert_eq(report.issues[0].code, "resource_cycle")
	assert_string_contains(report.issues[0].message, "authoring_cycle_scene")
	assert_string_contains(report.issues[0].field, "dependencies")


func test_existing_wrong_resource_type_keeps_declaring_definition_field_context() -> void:
	var path: String = "user://content_doctor_wrong_type.tres"
	var profile: DEF_NpcProfile = DEF_NpcProfile.new()
	profile.schedule = DEF_NpcSchedule.new()
	profile.npc_scene_path = "res://content/domains/commerce/definitions/def_trader_default.tres"
	assert_eq(ResourceSaver.save(profile, path), OK)
	var report: Dictionary = ContentDoctor.new().scan_paths(PackedStringArray([path]))
	assert_false(report.valid)
	var found_type_error: bool = false
	for issue: Dictionary in report.issues:
		if issue.code == "resource_type":
			found_type_error = true
			assert_eq(issue.source, path)
			assert_eq(issue.field, "npc_scene_path")
	assert_true(found_type_error)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func test_district_level_rejects_missing_home_and_wrong_type_portal_anchors() -> void:
	var level: Node3D = autofree(Node3D.new()) as Node3D
	level.name = "DoctorLevel"
	level.set_meta(PlacedIdentityRules.WORLD_ID_META, &"doctor_anchor_level")
	var session: Entity = Entity.new()
	session.name = "DistrictSession"
	level.add_child(session)
	session.owner = level
	session.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"district")
	var district: C_District = C_District.new()
	district.definition = DEF_District.new()
	var home: DEF_DistrictPlace = DEF_DistrictPlace.new()
	home.key = &"home"
	home.kind = DEF_DistrictPlace.Kind.HOME
	home.anchor_path = NodePath("HomeAnchor")
	var portal: DEF_DistrictPlace = DEF_DistrictPlace.new()
	portal.key = &"portal"
	portal.kind = DEF_DistrictPlace.Kind.PORTAL
	portal.anchor_path = NodePath("PortalAnchor")
	var coordinate_only: DEF_DistrictPlace = DEF_DistrictPlace.new()
	coordinate_only.key = &"coordinate"
	district.definition.places = [home, portal, coordinate_only]
	session.component_resources = [district]
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"district"
	capability.initial_field_names[C_District as Script] = PackedStringArray(
		["people", "next_person"]
	)
	_attach_traits(session, [capability])
	var wrong_portal: Node = Node.new()
	wrong_portal.name = "PortalAnchor"
	level.add_child(wrong_portal)
	var issues: Array[ContentDoctorIssue] = ContentDoctorSceneRules.inspect(level, "anchor_level")
	assert_eq(issues.size(), 2)
	if issues.size() != 2:
		return
	for issue: ContentDoctorIssue in issues:
		assert_eq(issue.code, &"district_anchor")
		assert_eq(issue.source, "anchor_level")
		assert_string_contains(issue.field, "DistrictSession/definition/places/")
	assert_false(level.is_inside_tree())
	assert_eq(session.ecs_id, 0)
	wrong_portal.free()
	for anchor_name: String in ["HomeAnchor", "PortalAnchor"]:
		var marker: Marker3D = Marker3D.new()
		marker.name = anchor_name
		level.add_child(marker)
	issues = ContentDoctorSceneRules.inspect(level, "anchor_level")
	assert_true(issues.is_empty())


func test_placed_attack_clip_override_is_checked_against_actual_compiled_combat() -> void:
	var original: E_NpcCharacter = autofree(_NPC_PREFAB.instantiate()) as E_NpcCharacter
	_configure_attack_clip(original)
	assert_true(ContentDoctorSceneRules.inspect(original, "valid_prefab").is_empty())
	var level: Node = autofree(_AUTHORING_LEVEL.instantiate()) as Node
	var resident: E_NpcCharacter = level.get_node("Resident") as E_NpcCharacter
	_configure_attack_clip(resident)
	resident.animation_player.remove_animation_library(&"doctor")
	assert_false(resident.animation_player.has_animation_library(&"doctor"))
	var issues: Array[ContentDoctorIssue] = ContentDoctorSceneRules.inspect(level, "attack_level")
	assert_eq(issues.size(), 2)
	for issue: ContentDoctorIssue in issues:
		assert_eq(issue.code, &"animation_name")
		assert_eq(issue.source, "attack_level")
		assert_string_contains(issue.field, "Resident/attack/")
		assert_string_contains(issue.message, "doctor/")
	assert_true(original.animation_player.has_animation(&"doctor/strike"))
	assert_false(level.is_inside_tree())
	assert_eq(resident.ecs_id, 0)


func _configure_attack_clip(actor: E_NpcCharacter) -> void:
	var library: AnimationLibrary = AnimationLibrary.new()
	assert_eq(library.add_animation(&"strike", Animation.new()), OK)
	assert_eq(library.add_animation(&"throw", Animation.new()), OK)
	assert_eq(actor.animation_player.add_animation_library(&"doctor", library), OK)
	actor.component_resources = actor.component_resources.duplicate()
	for index: int in actor.component_resources.size():
		if actor.component_resources[index] is C_NpcCombat:
			var combat: C_NpcCombat = C_NpcCombat.new()
			var attack: DEF_NpcAttack = DEF_NpcAttack.new()
			attack.animation = &"doctor/strike"
			var ranged: DEF_NpcAttack = DEF_NpcAttack.new()
			ranged.animation = &"doctor/throw"
			combat.melee_attacks = [attack]
			combat.ranged_attacks = [ranged]
			actor.component_resources[index] = combat
			return
	assert_true(false, "Native NPC fixture must contain authored C_NpcCombat")


func _attach_traits(actor: Entity, traits: Array[EntityTrait]) -> void:
	var template: DEF_EntityTemplate = DEF_EntityTemplate.new()
	template.traits = traits
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = template
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)


func _codes(issues: Array[ContentDoctorIssue]) -> Array[StringName]:
	var codes: Array[StringName] = []
	for issue: ContentDoctorIssue in issues:
		codes.append(issue.code)
	return codes
#endregion
