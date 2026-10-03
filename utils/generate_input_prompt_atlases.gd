extends SceneTree
## Генерирует отдельные binary AtlasTexture из всех XML Kenney и проверяет чтение ресурсов.

const Catalog: Script = preload("res://content/services/input/prompt_atlas_catalog.gd")


func _init() -> void:
	var count: int = 0
	var written: int = 0
	for family: String in Catalog.SHEETS:
		for scale: String in Catalog.SCALES:
			var entries: Dictionary[String, AtlasTexture] = Catalog.entries(family, scale)
			if entries.is_empty():
				push_error("Empty prompt sheet: %s/%s" % [family, scale])
				quit(1)
				return
			for name: String in entries:
				var path: String = Catalog.atlas_path(family, name, scale)
				var expected: AtlasTexture = entries[name]
				var existing: AtlasTexture = load(path) as AtlasTexture if ResourceLoader.exists(path) else null
				if existing == null or existing.region != expected.region or existing.atlas.resource_path != expected.atlas.resource_path:
					DirAccess.make_dir_recursive_absolute(path.get_base_dir())
					if ResourceSaver.save(expected, path) != OK:
						quit(1)
						return
					written += 1
				var saved: AtlasTexture = load(path) as AtlasTexture
				if saved == null or saved.region != expected.region or saved.atlas.resource_path != expected.atlas.resource_path:
					push_error("Prompt roundtrip failed: " + path)
					quit(1)
					return
				count += 1
	print("PASS input prompt atlases: %d resources, %d written" % [count, written])
	quit(0)
