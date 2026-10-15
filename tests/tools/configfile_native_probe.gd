extends SceneTree
## Bounded PVZ-B01 native API probe; isolated user:// files, no gameplay World or real save slots.

const DATA_PATH: String = "user://pvz_b01_configfile_native_probe.cfg"
const TEMP_PATH: String = "user://pvz_b01_configfile_native_probe.cfg.tmp"
const OBJECT_PATH: String = "user://pvz_b01_configfile_object_probe.cfg"


#region Native contract evidence
func _initialize() -> void:
	var report: Dictionary = { "engine": Engine.get_version_info().string }
	var snapshot: Dictionary = {
		"version": AutosaveStore.SCHEMA_VERSION,
		"text": "Юникод: \\\";[]\n\t",
		"native": [Vector3(1.25, -2.5, 3.0), Color(0.25, 0.5, 0.75, 1.0)],
		"names": { &"stable": PackedStringArray(["first", "второй"]) },
		"integer": 9007199254740993,
		"fraction": 0.625,
	}
	var written: ConfigFile = ConfigFile.new()
	written.set_value("save", "format", "pvz-configfile-probe")
	written.set_value("save", "snapshot", snapshot)
	written.set_value("save", "checksum", "probe-only")
	var text: String = written.encode_to_text()
	report["save_error"] = int(written.save(DATA_PATH))
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file != null:
		report["actual_file_bytes"] = file.get_length()
		file.close()
	report["encoded_utf8_bytes"] = text.to_utf8_buffer().size()
	var loaded: ConfigFile = ConfigFile.new()
	report["load_error"] = int(loaded.load(DATA_PATH))
	report["native_roundtrip"] = loaded.get_value("save", "snapshot", { }) == snapshot
	report["canonical_text_roundtrip"] = loaded.encode_to_text() == text

	var replacement: ConfigFile = ConfigFile.new()
	replacement.set_value("save", "replaced", true)
	report["temp_save_error"] = int(replacement.save(TEMP_PATH))
	report["replace_existing_error"] = int(
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(TEMP_PATH),
			ProjectSettings.globalize_path(DATA_PATH),
		)
	)
	var replaced: ConfigFile = ConfigFile.new()
	var replaced_error: Error = replaced.load(DATA_PATH)
	report["replace_readback"] = (
		replaced_error == OK and replaced.get_value("save", "replaced", false) == true
	)

	# Harmless RefCounted proves construction during parsing, before any schema/checksum gate.
	var object_file: ConfigFile = ConfigFile.new()
	object_file.set_value("save", "snapshot", { "unexpected": RefCounted.new() })
	report["object_fixture_save_error"] = int(object_file.save(OBJECT_PATH))
	var object_loaded: ConfigFile = ConfigFile.new()
	report["object_fixture_load_error"] = int(object_loaded.load(OBJECT_PATH))
	var object_snapshot: Dictionary = object_loaded.get_value("save", "snapshot", { }) as Dictionary
	var decoded: Variant = object_snapshot.get("unexpected")
	report["object_created_by_load"] = decoded is Object
	if decoded is Object:
		report["decoded_object_class"] = (decoded as Object).get_class()

	var methods: Array[Dictionary] = []
	for method: Dictionary in ClassDB.class_get_method_list(&"ConfigFile", true):
		if String(method.name) in ["load", "parse", "save", "encode_to_text"]:
			methods.append({ "name": method.name, "arguments": method.args })
	report["native_api"] = methods
	print("CONFIGFILE_NATIVE_PROBE ", JSON.stringify(report))
	for path: String in [DATA_PATH, TEMP_PATH, OBJECT_PATH]:
		if FileAccess.file_exists(path):
			var cleanup_error: Error = DirAccess.remove_absolute(
				ProjectSettings.globalize_path(path)
			)
			if cleanup_error != OK:
				push_error("Probe cleanup failed: %s (%d)" % [path, cleanup_error])
	quit()
#endregion
