@tool
extends EditorScript

## Генерирует StandardMaterial3D из наборов BMP-текстур.
##
## Ожидаемая структура:
## collection/<category>/<number>/*_<map_name>.bmp
##
## Запуск: открыть скрипт в редакторе Godot и выбрать File > Run
## (Ctrl+Shift+X). Затем выбрать папку collection внутри res://.


class MaterialGeneratorController:
	extends Node

	const MATERIAL_PREFIX: String = "mat_"
	const MATERIAL_EXTENSION: String = ".tres"
	const DEFAULT_HEIGHTMAP_SCALE: float = 0.05
	const USE_EDGE_AS_RIM: bool = false

	const MAP_SUFFIXES: Dictionary = {
		"_ao.bmp": "ao",
		"_diffuseoriginal.bmp": "albedo",
		"_edge.bmp": "edge",
		"_height.bmp": "height",
		"_metallic.bmp": "metallic",
		"_normal.bmp": "normal",
		"_smoothness.bmp": "smoothness",
	}

	var _folder_dialog: FileDialog


	func open_folder_dialog() -> void:
		_folder_dialog = FileDialog.new()
		_folder_dialog.access = FileDialog.ACCESS_RESOURCES
		_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folder_dialog.mode_overrides_title = false
		_folder_dialog.title = "Выберите папку collection"
		_folder_dialog.current_dir = "res://"
		_folder_dialog.size = Vector2i(900, 600)
		_folder_dialog.dir_selected.connect(_on_collection_selected)
		_folder_dialog.canceled.connect(_on_selection_canceled)
		add_child(_folder_dialog)
		_folder_dialog.popup_centered()


	func _on_collection_selected(collection_path: String) -> void:
		_folder_dialog.queue_free()
		var stats: Dictionary = {
			"created": 0,
			"skipped": 0,
			"failed": 0,
		}
		var generated_paths: Dictionary = {}

		_scan_directory(collection_path, collection_path, generated_paths, stats)
		EditorInterface.get_resource_filesystem().scan()

		var message: String = (
			"Готово.\n\n"
			+ "Создано или обновлено материалов: " + str(stats["created"]) + "\n"
			+ "Пропущено каталогов: " + str(stats["skipped"]) + "\n"
			+ "Ошибок: " + str(stats["failed"]) + "\n\n"
			+ "Материалы сохранены в:\n" + collection_path
		)
		print("[Material Generator] ", message.replace("\n", " "))
		_show_result(message)


	func _on_selection_canceled() -> void:
		queue_free()


	func _scan_directory(
		directory_path: String,
		collection_path: String,
		generated_paths: Dictionary,
		stats: Dictionary
	) -> void:
		if directory_path != collection_path:
			var texture_set: Dictionary = _find_texture_set(directory_path)
			if not texture_set.is_empty():
				_create_material_for_directory(
					directory_path,
					collection_path,
					texture_set,
					generated_paths,
					stats
				)

		var subdirectories: PackedStringArray = DirAccess.get_directories_at(directory_path)
		subdirectories.sort()
		for directory_name: String in subdirectories:
			if directory_name.begins_with("."):
				continue
			_scan_directory(
				directory_path.path_join(directory_name),
				collection_path,
				generated_paths,
				stats
			)


	func _find_texture_set(directory_path: String) -> Dictionary:
		var groups: Dictionary = {}
		var file_names: PackedStringArray = DirAccess.get_files_at(directory_path)
		file_names.sort()

		for file_name: String in file_names:
			var match_data: Dictionary = _match_texture_file(file_name)
			if match_data.is_empty():
				continue

			var prefix: String = match_data["prefix"]
			var map_type: String = match_data["map_type"]
			if not groups.has(prefix):
				groups[prefix] = {}

			var group: Dictionary = groups[prefix]
			if group.has(map_type):
				push_warning(
					"[Material Generator] Duplicate map '" + map_type
					+ "' in " + directory_path + ". Using: " + group[map_type]
				)
				continue
			group[map_type] = directory_path.path_join(file_name)

		if groups.is_empty():
			return {}

		var prefixes: Array = groups.keys()
		prefixes.sort()
		var selected_prefix: String = ""
		var selected_map_count: int = -1
		for prefix_variant: Variant in prefixes:
			var prefix: String = prefix_variant
			var candidate: Dictionary = groups[prefix]
			if candidate.size() > selected_map_count:
				selected_prefix = prefix
				selected_map_count = candidate.size()

		if groups.size() > 1:
			push_warning(
				"[Material Generator] Several texture prefixes found in "
				+ directory_path + ". Using the most complete set: " + selected_prefix
			)

		return groups[selected_prefix]


	func _match_texture_file(file_name: String) -> Dictionary:
		var lower_name: String = file_name.to_lower()
		for suffix_variant: Variant in MAP_SUFFIXES:
			var suffix: String = suffix_variant
			if not lower_name.ends_with(suffix):
				continue

			var prefix_length: int = lower_name.length() - suffix.length()
			if prefix_length <= 0:
				return {}

			return {
				"prefix": lower_name.left(prefix_length),
				"map_type": MAP_SUFFIXES[suffix],
			}

		return {}


	func _create_material_for_directory(
		directory_path: String,
		collection_path: String,
		texture_set: Dictionary,
		generated_paths: Dictionary,
		stats: Dictionary
	) -> void:
		var number_name: String = directory_path.get_file()
		if not number_name.is_valid_int():
			stats["skipped"] += 1
			push_warning(
				"[Material Generator] Skipped texture directory with non-numeric name: "
				+ directory_path
			)
			return

		var category_name: String = directory_path.get_base_dir().get_file()
		var safe_category: String = _sanitize_name_part(category_name)
		var safe_number: String = _sanitize_name_part(number_name)
		var material_file_name: String = (
			MATERIAL_PREFIX + safe_category + "_" + safe_number + MATERIAL_EXTENSION
		)
		var output_path: String = collection_path.path_join(material_file_name)

		if generated_paths.has(output_path):
			stats["skipped"] += 1
			push_warning(
				"[Material Generator] Output name collision: " + output_path
				+ ". First source: " + generated_paths[output_path]
				+ ", skipped source: " + directory_path
			)
			return
		generated_paths[output_path] = directory_path

		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.resource_name = material_file_name.get_basename()
		material.heightmap_scale = DEFAULT_HEIGHTMAP_SCALE
		material.set_meta("source_directory", directory_path)

		_apply_texture_set(material, texture_set)

		var save_error: Error = ResourceSaver.save(material, output_path)
		if save_error != OK:
			stats["failed"] += 1
			push_error(
				"[Material Generator] Failed to save material: " + output_path
				+ " (error " + str(save_error) + ")"
			)
			return

		stats["created"] += 1
		print("[Material Generator] Saved: ", output_path)


	func _apply_texture_set(
		material: StandardMaterial3D,
		texture_set: Dictionary
	) -> void:
		if texture_set.has("albedo"):
			material.albedo_texture = _load_texture(texture_set["albedo"])

		if texture_set.has("normal"):
			var normal_texture: Texture2D = _load_texture(texture_set["normal"])
			if normal_texture != null:
				material.normal_enabled = true
				material.normal_texture = normal_texture

		if texture_set.has("metallic"):
			var metallic_texture: Texture2D = _load_texture(texture_set["metallic"])
			if metallic_texture != null:
				material.metallic = 1.0
				material.metallic_texture = metallic_texture

		if texture_set.has("ao"):
			var ao_texture: Texture2D = _load_texture(texture_set["ao"])
			if ao_texture != null:
				material.ao_enabled = true
				material.ao_texture = ao_texture

		if texture_set.has("height"):
			var height_texture: Texture2D = _load_texture(texture_set["height"])
			if height_texture != null:
				material.heightmap_enabled = true
				material.heightmap_texture = height_texture

		if texture_set.has("smoothness"):
			var smoothness_path: String = texture_set["smoothness"]
			var smoothness_texture: Texture2D = _load_texture(smoothness_path)
			var roughness_texture: Texture2D = _create_roughness_texture(
				smoothness_texture,
				smoothness_path
			)
			if roughness_texture != null:
				material.roughness = 1.0
				material.roughness_texture = roughness_texture
				material.set_meta("source_smoothness_texture", smoothness_path)

		if texture_set.has("edge"):
			var edge_path: String = texture_set["edge"]
			material.set_meta("source_edge_texture", edge_path)
			if USE_EDGE_AS_RIM:
				var edge_texture: Texture2D = _load_texture(edge_path)
				if edge_texture != null:
					material.rim_enabled = true
					material.rim_texture = edge_texture


	func _load_texture(texture_path: String) -> Texture2D:
		var texture: Texture2D = ResourceLoader.load(texture_path, "Texture2D") as Texture2D
		if texture == null:
			push_warning("[Material Generator] Failed to load texture: " + texture_path)
		return texture


	func _create_roughness_texture(
		smoothness_texture: Texture2D,
		source_path: String
	) -> Texture2D:
		if smoothness_texture == null:
			return null

		var source_image: Image = smoothness_texture.get_image()
		if source_image == null or source_image.is_empty():
			push_warning(
				"[Material Generator] Cannot read smoothness image: " + source_path
			)
			return null

		var roughness_image: Image = source_image.duplicate() as Image
		if roughness_image.is_compressed():
			var decompress_error: Error = roughness_image.decompress()
			if decompress_error != OK:
				push_warning(
					"[Material Generator] Cannot decompress smoothness image: " + source_path
				)
				return null

		roughness_image.convert(Image.FORMAT_RGBA8)
		var image_data: PackedByteArray = roughness_image.get_data()
		for byte_index: int in range(0, image_data.size(), 4):
			var roughness_value: int = 255 - image_data[byte_index]
			image_data[byte_index] = roughness_value
			image_data[byte_index + 1] = roughness_value
			image_data[byte_index + 2] = roughness_value
			image_data[byte_index + 3] = 255

		var inverted_image: Image = Image.create_from_data(
			roughness_image.get_width(),
			roughness_image.get_height(),
			roughness_image.has_mipmaps(),
			Image.FORMAT_RGBA8,
			image_data
		)
		var roughness_texture: ImageTexture = ImageTexture.create_from_image(inverted_image)
		roughness_texture.resource_name = source_path.get_file().get_basename() + "_roughness"

		# Сохраняем преобразованную карту отдельным бинарным ресурсом рядом с BMP.
		# Так данные изображения не раздувают текстовый файл материала .tres.
		var source_basename: String = source_path.get_file().get_basename()
		var smoothness_suffix: String = "_smoothness"
		var prefix_length: int = source_basename.length() - smoothness_suffix.length()
		var source_prefix: String = source_basename.left(maxi(prefix_length, 0))
		var roughness_path: String = source_path.get_base_dir().path_join(
			source_prefix + "_roughness.res"
		)
		var save_error: Error = ResourceSaver.save(
			roughness_texture,
			roughness_path,
			ResourceSaver.FLAG_CHANGE_PATH | ResourceSaver.FLAG_COMPRESS
		)
		if save_error != OK:
			push_warning(
				"[Material Generator] Cannot save generated roughness texture: "
				+ roughness_path + " (error " + str(save_error) + ")"
			)
			return null

		return roughness_texture


	func _sanitize_name_part(value: String) -> String:
		var regex: RegEx = RegEx.new()
		var compile_error: Error = regex.compile("[^a-z0-9_-]+")
		if compile_error != OK:
			return value.to_lower().replace(" ", "_")

		var sanitized: String = regex.sub(value.to_lower(), "_", true)
		while sanitized.contains("__"):
			sanitized = sanitized.replace("__", "_")
		sanitized = sanitized.trim_prefix("_").trim_suffix("_")
		return sanitized if not sanitized.is_empty() else "unnamed"


	func _show_result(message: String) -> void:
		var result_dialog: AcceptDialog = AcceptDialog.new()
		result_dialog.title = "Генерация материалов"
		result_dialog.dialog_text = message
		result_dialog.confirmed.connect(queue_free)
		result_dialog.close_requested.connect(queue_free)
		add_child(result_dialog)
		result_dialog.popup_centered()


func _run() -> void:
	# Контроллер является Node и остаётся в дереве редактора, пока открыты окна.
	# Это защищает асинхронный UI от уничтожения EditorScript (RefCounted).
	var controller: MaterialGeneratorController = MaterialGeneratorController.new()
	EditorInterface.get_base_control().add_child(controller)
	controller.open_folder_dialog()
