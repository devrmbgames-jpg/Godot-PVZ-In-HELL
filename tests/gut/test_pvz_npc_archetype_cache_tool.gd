extends GutTest
## Native cache refresh replaces stale scripted values while preserving authored files and UIDs.

const TOOL: Script = preload("res://addons/pvz_ai_tools/npc_archetype_cache_tool.gd")
const PROFILE: String = "res://content/domains/npc/definitions/def_npc_archetype_shy.tres"
const OTHER: String = "res://content/domains/npc/definitions/def_npc_archetype_fire_elemental.tres"


func test_refresh_replaces_stale_cache_without_changing_authored_files_or_uid() -> void:
	var checksum: String = FileAccess.get_md5(PROFILE)
	var uid: int = ResourceLoader.get_resource_uid(PROFILE)
	var stale: DEF_NpcProfile = DEF_NpcProfile.new()
	stale.display_name = "Stale fixture reference"
	stale.take_over_path(PROFILE)
	assert_same(ResourceLoader.load(PROFILE), stale)
	var result: Dictionary = TOOL.refresh_resources(PackedStringArray([PROFILE]))
	assert_false(result.has("error"))
	assert_false(result.data.files_changed)
	assert_true(result.data.cached_definitions_refreshed)
	assert_true(result.data.scene_reload_required)
	var fresh: Resource = ResourceLoader.load(PROFILE)
	assert_true(fresh is DEF_NpcArchetype)
	assert_eq(fresh.resource_path, PROFILE)
	assert_ne(fresh.get("display_name"), "Stale fixture reference")
	assert_eq(FileAccess.get_md5(PROFILE), checksum)
	assert_eq(ResourceLoader.get_resource_uid(PROFILE), uid)


func test_inspected_root_and_owned_subresources_block_refresh_without_losing_edits() -> void:
	var root_resource: DEF_NpcArchetype = ResourceLoader.load(PROFILE) as DEF_NpcArchetype
	var edited_resources: Array[Resource] = [
		root_resource,
		root_resource.schedule,
		root_resource.optional_traits[0],
	]
	var fields: Array[String] = ["display_name", "morning", "weight"]
	var changes: Array[Variant] = ["Inspected authoring edit", DEF_NpcSchedule.Location.HOME, 37.0]
	var checksum: String = FileAccess.get_md5(PROFILE)
	for index: int in edited_resources.size():
		var edited: Resource = edited_resources[index]
		assert_eq(edited.resource_path.get_slice("::", 0), PROFILE)
		var original: Variant = edited.get(fields[index])
		edited.set(fields[index], changes[index])
		var refused: Dictionary = TOOL.refresh_resources(PackedStringArray([PROFILE]), edited)
		assert_true(refused.has("error"))
		assert_eq(edited.get(fields[index]), changes[index], "Inspector edits remain in memory")
		assert_eq(FileAccess.get_md5(PROFILE), checksum)
		edited.set(fields[index], original)


func test_invalid_batch_rejects_before_replacing_any_cache_entry() -> void:
	var stale: DEF_NpcProfile = DEF_NpcProfile.new()
	stale.take_over_path(PROFILE)
	for paths: PackedStringArray in [
		PackedStringArray(),
		PackedStringArray([PROFILE, PROFILE]),
		PackedStringArray([PROFILE, "res://project.godot"]),
		PackedStringArray([PROFILE, PROFILE + "::Schedule"]),
		PackedStringArray([PROFILE, "res://content/domains/npc/definitions/../bad.tres"]),
	]:
		assert_true(TOOL.refresh_resources(paths).has("error"))
		assert_same(ResourceLoader.load(PROFILE), stale)
	# The second file exists, but is not an Archetype: full preflight rejects the first too.
	var wrong: String = "res://content/domains/npc/definitions/def_npc_trait_0.tres"
	assert_true(TOOL.refresh_resources(PackedStringArray([PROFILE, wrong])).has("error"))
	assert_same(ResourceLoader.load(PROFILE), stale)
	assert_false(TOOL.refresh_resources(PackedStringArray([PROFILE, OTHER])).has("error"))
