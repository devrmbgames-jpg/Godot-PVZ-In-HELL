extends SceneTree
## Offline native authoring: bind canonical archetypes and preserve district participation roles.
## Run with the live project editor verified closed; project types load after autoload registration.

const PLAN_PATH: String = "res://.artifacts/r26_roster_binding_plan.json"
const DISTRICT_PATH: String = "res://content/domains/npc/definitions/def_district_default.tres"
const DISTRICT_UID: String = "uid://0japh62q4h57"
const DEFINITION_ROOT: String = "res://content/domains/npc/definitions/"
const LEGACY_FIXTURE_PATH: String = DEFINITION_ROOT + "def_district_legacy_fixture.tres"
const BINDINGS: Array[String] = [
	"night_hunter",
	"fire_elemental",
	"shy",
	"creepy",
	"brute",
	"hag",
	"weeping_angel",
	"lost",
	"chain_devil",
	"vampire",
]
const VISITOR_BASES: Array[String] = ["lost", "shy"]

var _phase: String = "bind"


#region Guarded offline authoring
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _verify_sources():
		quit(1)
		return
	if _phase == "finalize":
		_finalize_visitors()
		return
	var district: Resource = load(DISTRICT_PATH) as Resource
	if (
		district == null or StringName(district.get("key")) != &"hell_district"
		or (district.get("profiles") as Array).size() != 12
	):
		push_error("Roster migration requires the original twelve-slot district")
		quit(1)
		return
	var legacy_profiles: Array = (district.get("profiles") as Array).duplicate()
	var roster: Array = legacy_profiles.duplicate()
	roster.clear()
	for archetype_name: String in BINDINGS:
		var path: String = DEFINITION_ROOT + "def_npc_archetype_" + archetype_name + ".tres"
		var archetype: Resource = load(path) as Resource
		if not _valid_profile(archetype):
			push_error("Invalid canonical archetype: " + path)
			quit(1)
			return
		roster.append(archetype)
	if not bool((legacy_profiles[7] as Resource).get("merchant")):
		push_error("The placed merchant must retain roster slot eight")
		quit(1)
		return
	for slot: int in 12:
		if (
			not _valid_profile(legacy_profiles[slot] as Resource)
			or bool((legacy_profiles[slot] as Resource).get("resident")) != (slot < 8)
		):
			push_error("Unexpected authored residency in slot %d" % slot)
			quit(1)
			return
	if ResourceLoader.exists(LEGACY_FIXTURE_PATH):
		push_error("Legacy test fixture already exists; refusing replacement")
		quit(1)
		return
	for base_name: String in VISITOR_BASES:
		if ResourceLoader.exists(_visitor_path(base_name)):
			push_error("Visitor definition already exists; refusing replacement")
			quit(1)
			return

	# Preserve the old population as a native fixture for existing isolated contract tests.
	var legacy: Resource = district.duplicate(false) as Resource
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(LEGACY_FIXTURE_PATH.get_base_dir()),
	)
	if directory_error != OK or not _save(legacy, LEGACY_FIXTURE_PATH):
		quit(1)
		return

	for slot: int in BINDINGS.size():
		_copy_participation(roster[slot] as Resource, legacy_profiles[slot] as Resource)
		if not _save(roster[slot] as Resource, (roster[slot] as Resource).resource_path):
			quit(1)
			return
	for offset: int in VISITOR_BASES.size():
		var base_name: String = VISITOR_BASES[offset]
		var base: Resource = (
			load(DEFINITION_ROOT + "def_npc_archetype_" + base_name + ".tres") as Resource
		)
		var visitor: Resource = base.duplicate(false) as Resource
		visitor.set("key", StringName("archetype/" + base_name + "_visitor"))
		var schedule: Resource = (base.get("schedule") as Resource).duplicate(false)
		schedule.set("key", StringName("schedule/" + base_name + "_visitor"))
		visitor.set("schedule", schedule)
		_copy_participation(visitor, legacy_profiles[10 + offset] as Resource)
		if not _save(visitor, _visitor_path(base_name)):
			quit(1)
			return
		roster.append(visitor)
	district.set("profiles", roster)
	if not _save(district, DISTRICT_PATH) or not _preserve_district_uid():
		quit(1)
		return
	print(
		"R26 native roster authoring PASS: ten archetypes, twelve identities, "
		+ "eight residents, four visitors",
	)
	quit()
#endregion


#region Source and native resource boundaries
func _verify_sources() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	if not parsed is Dictionary:
		push_error("Missing exact-source roster authoring plan")
		return false
	var plan: Dictionary = parsed as Dictionary
	_phase = String(plan.get("phase", "bind"))
	if _phase not in ["bind", "finalize"]:
		push_error("Unsupported native authoring phase")
		return false
	var fingerprints: Dictionary = plan.get("fingerprints", { }) as Dictionary
	var sources: Array[String] = [DISTRICT_PATH]
	if _phase == "bind":
		for archetype_name: String in BINDINGS:
			sources.append(DEFINITION_ROOT + "def_npc_archetype_" + archetype_name + ".tres")
		for person_number: int in range(1, 13):
			sources.append(DEFINITION_ROOT + "def_npc_profile_%d.tres" % person_number)
	else:
		for base_name: String in VISITOR_BASES:
			sources.append(_visitor_path(base_name))
	if fingerprints.size() != sources.size():
		push_error("Roster plan must pin every source in the selected authoring phase")
		return false
	for source_path: String in sources:
		if (
			not fingerprints.has(source_path)
			or FileAccess.get_sha256(source_path) != String(fingerprints[source_path])
		):
			push_error(
				"Roster source changed or is outside the bounded definitions: " + source_path,
			)
			return false
	return true


func _valid_profile(profile: Resource) -> bool:
	# Project definitions load after autoload initialization; the entry script uses native types.
	if profile == null:
		return false
	var profile_script: Script = profile.get_script() as Script
	var schedule: Resource = profile.get("schedule") as Resource
	return (
		profile_script != null and profile_script.get_global_name() == &"DEF_NpcArchetype"
		and schedule != null and bool(profile.call("valid_rules"))
	)


func _copy_participation(target: Resource, source: Resource) -> void:
	for field: String in ["resident", "merchant", "recipient_key"]:
		target.set(field, source.get(field))
	var target_schedule: Resource = target.get("schedule") as Resource
	var source_schedule: Resource = source.get("schedule") as Resource
	var weekdays: PackedInt32Array = source_schedule.get("weekdays") as PackedInt32Array
	target_schedule.set("weekdays", weekdays.duplicate())
	for field: String in ["morning", "day", "evening"]:
		target_schedule.set(field, int(source_schedule.get(field)))


func _visitor_path(base_name: String) -> String:
	return DEFINITION_ROOT + "def_npc_archetype_" + base_name + "_visitor.tres"


func _finalize_visitors() -> void:
	var district: Resource = load(DISTRICT_PATH) as Resource
	if district == null or (district.get("profiles") as Array).size() != 12:
		push_error("Visitor finalization requires the authored twelve-slot roster")
		quit(1)
		return
	var roster: Array = district.get("profiles") as Array
	for slot: int in BINDINGS.size():
		if StringName((roster[slot] as Resource).get("key")) != StringName(
			"archetype/" + BINDINGS[slot]
		):
			push_error("Unexpected canonical roster slot during finalization")
			quit(1)
			return
	for offset: int in VISITOR_BASES.size():
		var path: String = _visitor_path(VISITOR_BASES[offset])
		var visitor: Resource = load(path) as Resource
		if (
			not _valid_profile(visitor) or bool(visitor.get("resident"))
			or bool(visitor.get("merchant"))
		):
			push_error("Invalid external visitor definition: " + path)
			quit(1)
			return
		roster[10 + offset] = visitor
	if not _save(district, DISTRICT_PATH):
		quit(1)
		return
	if not _preserve_district_uid():
		quit(1)
		return
	print("R26 native visitor reference finalization PASS")
	quit()


func _preserve_district_uid() -> bool:
	# Plain headless ResourceSaver cannot infer the editor's resource UID registry.
	var expected_uid: int = ResourceUID.text_to_id(DISTRICT_UID)
	var error: Error = ResourceSaver.set_uid(DISTRICT_PATH, expected_uid)
	if error != OK or ResourceLoader.get_resource_uid(DISTRICT_PATH) != expected_uid:
		push_error("Native authoring did not preserve the district resource UID")
		return false
	return true


func _save(resource: Resource, path: String) -> bool:
	var error: Error = ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		push_error("Native resource save failed for %s: %s" % [path, error_string(error)])
		return false
	print("R26 authored ", path)
	return true
#endregion
