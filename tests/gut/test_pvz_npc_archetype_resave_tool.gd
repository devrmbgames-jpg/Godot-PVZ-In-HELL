extends GutTest
## Fingerprints, native type/layout and Inspector ownership gate canonical resource saves.

const TOOL: Script = preload("res://addons/pvz_ai_tools/npc_archetype_resave_tool.gd")
const PROFILE: String = "res://content/domains/npc/definitions/def_npc_archetype_shy.tres"


func test_unsaved_trait_kind_cannot_bypass_disk_compatibility_or_change_cached_values() -> void:
	var rule_path: String = TOOL.ROOT + "def_npc_trait_0.tres"
	var checksum: String = FileAccess.get_sha256(PROFILE)
	var rule_checksum: String = FileAccess.get_sha256(rule_path)
	var cached_rule: DEF_NpcTrait = load(rule_path) as DEF_NpcTrait
	var original: DEF_NpcTrait.Kind = cached_rule.kind
	cached_rule.kind = DEF_NpcTrait.Kind.PROVOCATEUR
	var result: Dictionary = TOOL.preflight(
		{ PROFILE: checksum },
		null,
		{ },
		{ PROFILE: [rule_path] },
	)
	assert_true(result.has("error"), "Disk gaze trait conflicts even when cached kind differs")
	assert_eq(cached_rule.kind, DEF_NpcTrait.Kind.PROVOCATEUR)
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)
	assert_eq(FileAccess.get_sha256(rule_path), rule_checksum)
	cached_rule.kind = original


func test_trait_addition_prepares_complete_graph_and_refuses_duplicates_or_wrong_type() -> void:
	var trait_path: String = TOOL.ROOT + "def_npc_grudge.tres"
	var checksum: String = FileAccess.get_sha256(PROFILE)
	var cached: DEF_NpcArchetype = load(PROFILE) as DEF_NpcArchetype
	var original: Array[DEF_NpcTrait] = cached.rules.duplicate()
	var result: Dictionary = TOOL.preflight(
		{ PROFILE: checksum },
		null,
		{ },
		{ PROFILE: [trait_path] },
	)
	assert_false(result.has("error"))
	var prepared: DEF_NpcArchetype = result.resources[0] as DEF_NpcArchetype
	assert_eq(prepared.rules.size(), original.size() + 1)
	assert_is(prepared.rules.back(), DEF_NpcGrudge)
	assert_not_same(prepared.rules[0], original[0])
	assert_eq(prepared.rules[0].key, original[0].key)
	assert_eq(prepared.rules[0].kind, original[0].kind)
	assert_eq(cached.rules, original)
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)
	for paths: Array in [[], [trait_path, trait_path], [PROFILE], ["res://project.godot"]]:
		assert_true(TOOL.preflight({ PROFILE: checksum }, null, { }, { PROFILE: paths }).has(
				"error"
			))
	assert_true(TOOL.preflight({ PROFILE: checksum }, null, { }, {
			PROFILE: [original[0].resource_path]
		}).has("error"))
	var invalid_target: Dictionary = { "unfingerprinted": [trait_path] }
	assert_true(TOOL.preflight({ PROFILE: checksum }, null, { }, invalid_target).has("error"))
	assert_eq(cached.rules, original)
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)


func test_preflight_preserves_disk_and_loads_complete_separate_resource_graph() -> void:
	var checksum: String = FileAccess.get_sha256(PROFILE)
	var cached: DEF_NpcArchetype = load(PROFILE) as DEF_NpcArchetype
	var original: String = cached.display_name
	cached.display_name = "Unsaved cached edit"
	var result: Dictionary = TOOL.preflight({ PROFILE: checksum })
	assert_false(result.has("error"))
	var prepared: DEF_NpcArchetype = result.resources[0] as DEF_NpcArchetype
	assert_not_same(prepared, cached)
	assert_eq(prepared.display_name, original)
	assert_not_same(prepared.schedule, cached.schedule)
	assert_not_same(prepared.optional_traits[0], cached.optional_traits[0])
	assert_eq(prepared.schedule.key, cached.schedule.key)
	assert_not_same(prepared.optional_traits[0].rule, cached.optional_traits[0].rule)
	assert_eq(prepared.optional_traits[0].rule.key, cached.optional_traits[0].rule.key)
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)
	assert_eq(cached.display_name, "Unsaved cached edit")
	cached.display_name = original


func test_cached_mandatory_trait_edits_do_not_enter_compatibility_or_prepared_graph() -> void:
	var checksum: String = FileAccess.get_sha256(PROFILE)
	var cached: DEF_NpcArchetype = load(PROFILE) as DEF_NpcArchetype
	var cached_rule: DEF_NpcTrait = cached.rules[0]
	var rule_checksum: String = FileAccess.get_sha256(cached_rule.resource_path)
	var original: DEF_NpcTrait.Kind = cached_rule.kind
	cached_rule.kind = DEF_NpcTrait.Kind.PROVOCATEUR
	var result: Dictionary = TOOL.preflight(
		{ PROFILE: checksum },
		null,
		{ },
		{ PROFILE: [TOOL.ROOT + "def_npc_grudge.tres"] },
	)
	assert_false(result.has("error"), "Compatibility uses the valid disk graph")
	if not result.has("error"):
		var prepared: DEF_NpcArchetype = result.resources[0] as DEF_NpcArchetype
		assert_not_same(prepared.rules[0], cached_rule)
		assert_eq(prepared.rules[0].kind, original)
		assert_true(prepared.valid_rules())
	assert_eq(cached_rule.kind, DEF_NpcTrait.Kind.PROVOCATEUR)
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)
	assert_eq(FileAccess.get_sha256(cached_rule.resource_path), rule_checksum)
	cached_rule.kind = original


func test_inspected_nested_resource_and_changed_fingerprint_refuse_the_batch() -> void:
	var checksum: String = FileAccess.get_sha256(PROFILE)
	var cached: DEF_NpcArchetype = load(PROFILE) as DEF_NpcArchetype
	assert_true(TOOL.preflight({ PROFILE: checksum }, cached.schedule).has("error"))
	assert_true(TOOL.preflight({ PROFILE: "stale checksum" }).has("error"))
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)


func test_invalid_paths_and_wrong_native_types_refuse_without_writing() -> void:
	var checksum: String = FileAccess.get_sha256(PROFILE)
	var wrong: String = TOOL.ROOT + "def_npc_trait_0.tres"
	for fingerprints: Dictionary in [
		{ },
		{ PROFILE + "::Schedule": checksum },
		{ "res://project.godot": checksum },
		{ wrong: FileAccess.get_sha256(wrong) },
	]:
		assert_true(TOOL.preflight(fingerprints).has("error"))
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)


func test_dialogue_pool_preflights_imports_and_changes_only_the_prepared_graph() -> void:
	var checksum: String = FileAccess.get_sha256(PROFILE)
	var cached: DEF_NpcArchetype = load(PROFILE) as DEF_NpcArchetype
	var original: PackedStringArray = cached.dialogue_variants.duplicate()
	var variants: Array = [
		"res://content/domains/npc/dialogue/archetypes/lost/variant_a.dialogue",
		"res://content/domains/npc/dialogue/archetypes/lost/variant_b.dialogue",
	]
	var result: Dictionary = TOOL.preflight({ PROFILE: checksum }, null, { PROFILE: variants })
	assert_false(result.has("error"))
	assert_eq(result.resources[0].get("dialogue_variants"), PackedStringArray(variants))
	assert_eq(cached.dialogue_variants, original)
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)
	for pool: Array in [[], [variants[0]], [variants[0], variants[0]], [variants[0], PROFILE]]:
		assert_true(TOOL.preflight({ PROFILE: checksum }, null, { PROFILE: pool }).has("error"))
	assert_true(TOOL.preflight({ PROFILE: checksum }, null, { "other": variants }).has("error"))
	assert_eq(cached.dialogue_variants, original)
	assert_eq(FileAccess.get_sha256(PROFILE), checksum)
