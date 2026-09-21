@tool
extends EditorScenePostImport

# Главная функция, вызываемая Godot после импорта сцены
func _post_import(scene: Node) -> Object:
	var source_path: String = get_source_file()
	var base_name: String = source_path.get_file().get_basename()
	var base_dir: String = source_path.get_base_dir()

	print("[GLTF Auto Processor] Processing: ", source_path)

	# 1. Создаём папки
	var mesh_dir: String = base_dir.path_join(base_name + "_mesh")
	var animation_dir: String = base_dir.path_join(base_name + "_anim")
	var scene_dir: String = base_dir.path_join(base_name)
	_ensure_dir(mesh_dir)
	_ensure_dir(animation_dir)
	_ensure_dir(scene_dir)

	# 2. Собираем все MeshInstance3D и сохраняем меши как .res
	var mesh_map: Dictionary = {}  # node_path -> resource_path
	_extract_and_save_meshes(scene, scene, mesh_dir, base_name, mesh_map)

	# 3. Сохраняем Animation из всех AnimationPlayer как внешние .res
	var animation_map: Dictionary = {}  # node_path -> library -> animation -> resource_path
	var used_animation_paths: Dictionary = {}
	_extract_and_save_animations(
		scene,
		scene,
		animation_dir,
		animation_map,
		used_animation_paths
	)

	# 4. После сохранения ресурсов нужно дождаться, пока редактор их увидит.
	#    Поэтому создание сцен делаем через CallDeferred-подход:
	#    запоминаем данные и создаём сцены в отложенном вызове.
	#    Но EditorScenePostImport работает синхронно, поэтому используем
	#    EditorInterface через ResourceLoader + ResourceSaver напрямую.

	# Сохраняем дочерние сцены
	_create_variant_scenes(scene, scene_dir, base_name, mesh_map, animation_map)

	return scene


# --- Вспомогательные методы ---

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)


func _extract_and_save_meshes(
	node: Node,
	root: Node,
	mesh_dir: String,
	base_name: String,
	mesh_map: Dictionary
) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			# Уникальное имя меша: имя_файла + имя_узла
			var mesh_name: String = base_name + "_" + _sanitize(mi.name)
			var mesh_path: String = mesh_dir.path_join(mesh_name + ".res")

			# Сохраняем меш как внешний ресурс
			# FLAG_COMPRESS даёт меньший размер на диске и быстрее загрузку
			var err: int = ResourceSaver.save(
				mi.mesh,
				mesh_path,
				ResourceSaver.FLAG_COMPRESS
			)
			if err != OK:
				push_warning("[GLTF Auto Processor] Failed to save mesh: " + mesh_path)
			else:
				# Запоминаем путь от корня к этому узлу и куда сохранили меш
				var rel_path: NodePath = root.get_path_to(mi)
				mesh_map[rel_path] = mesh_path

	for child in node.get_children():
		_extract_and_save_meshes(child, root, mesh_dir, base_name, mesh_map)


func _extract_and_save_animations(
	node: Node,
	root: Node,
	animation_dir: String,
	animation_map: Dictionary,
	used_animation_paths: Dictionary
) -> void:
	if node is AnimationPlayer:
		var player: AnimationPlayer = node
		var player_map: Dictionary = {}

		for library_name: StringName in player.get_animation_library_list():
			var library: AnimationLibrary = player.get_animation_library(library_name)
			if library == null:
				continue

			var library_map: Dictionary = {}
			for animation_name: StringName in library.get_animation_list():
				var animation: Animation = library.get_animation(animation_name)
				if animation == null:
					continue

				var animation_path: String = _make_unique_animation_path(
					animation_dir,
					player.name,
					library_name,
					animation_name,
					used_animation_paths
				)
				var save_err: int = ResourceSaver.save(
					animation,
					animation_path,
					ResourceSaver.FLAG_COMPRESS
				)
				if save_err != OK:
					push_warning(
						"[GLTF Auto Processor] Failed to save animation: " + animation_path
					)
					continue

				library_map[animation_name] = animation_path
				print("[GLTF Auto Processor] Saved animation: ", animation_path)

			if not library_map.is_empty():
				player_map[library_name] = library_map

		if not player_map.is_empty():
			var rel_path: NodePath = root.get_path_to(player)
			animation_map[rel_path] = player_map

	for child in node.get_children():
		_extract_and_save_animations(
			child,
			root,
			animation_dir,
			animation_map,
			used_animation_paths
		)


func _make_unique_animation_path(
	animation_dir: String,
	player_name: StringName,
	library_name: StringName,
	animation_name: StringName,
	used_animation_paths: Dictionary
) -> String:
	var safe_animation_name: String = _sanitize(String(animation_name))
	if safe_animation_name.is_empty():
		safe_animation_name = "animation"

	var animation_path: String = animation_dir.path_join(safe_animation_name + ".res")
	if not used_animation_paths.has(animation_path):
		used_animation_paths[animation_path] = true
		return animation_path

	# Если одинаковые имена встречаются в нескольких плеерах или библиотеках,
	# добавляем контекст, чтобы один ресурс не перезаписал другой.
	var safe_player_name: String = _sanitize(String(player_name))
	var safe_library_name: String = _sanitize(String(library_name))
	if safe_library_name.is_empty():
		safe_library_name = "default"

	var contextual_name: String = (
		safe_player_name + "_" + safe_library_name + "_" + safe_animation_name
	)
	animation_path = animation_dir.path_join(contextual_name + ".res")

	var suffix: int = 2
	while used_animation_paths.has(animation_path):
		animation_path = animation_dir.path_join(
			contextual_name + "_" + str(suffix) + ".res"
		)
		suffix += 1

	used_animation_paths[animation_path] = true
	return animation_path


func _sanitize(s: String) -> String:
	# Убираем символы, которые не подходят для имён файлов
	var result: String = s
	for ch in [" ", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(ch, "_")
	return result


func _create_variant_scenes(
	original: Node,
	scene_dir: String,
	base_name: String,
	mesh_map: Dictionary,
	animation_map: Dictionary
) -> void:
	# Базовая сцена — просто копия с внешними ссылками на меши, без коллизий
	_save_variant(
		original,
		scene_dir.path_join(base_name + ".tscn"),
		"none",
		mesh_map,
		animation_map
	)

	# Static — оборачиваем в StaticBody3D с триместными коллизиями
	_save_variant(
		original,
		scene_dir.path_join(base_name + "_static.tscn"),
		"static",
		mesh_map,
		animation_map
	)

	# Rigid — оборачиваем в RigidBody3D с выпуклыми коллизиями
	_save_variant(
		original,
		scene_dir.path_join(base_name + "_rigid.tscn"),
		"rigid",
		mesh_map,
		animation_map
	)


func _save_variant(
	original: Node,
	out_path: String,
	body_type: String,
	mesh_map: Dictionary,
	animation_map: Dictionary
) -> void:
	# Дублируем дерево
	var root: Node = original.duplicate()

	# Заменяем встроенные меши на ссылки на внешние .res файлы
	_relink_meshes(root, root, mesh_map)
	_relink_animations(root, root, animation_map)

	# Оборачиваем под нужный тип тела (если требуется)
	var final_root: Node = root
	match body_type:
		"static":
			final_root = _wrap_with_body(root, "StaticBody3D", base_name_from_path(out_path))
		"rigid":
			final_root = _wrap_with_body(root, "RigidBody3D", base_name_from_path(out_path))
		"none":
			final_root.name = base_name_from_path(out_path)

	# Все узлы должны принадлежать сцене (owner = root)
	_set_owner_recursive(final_root, final_root)

	# Упаковываем и сохраняем
	var packed: PackedScene = PackedScene.new()
	var pack_err: int = packed.pack(final_root)
	if pack_err != OK:
		push_warning("[GLTF Auto Processor] Failed to pack: " + out_path)
		return

	var save_err: int = ResourceSaver.save(packed, out_path)
	if save_err != OK:
		push_warning("[GLTF Auto Processor] Failed to save scene: " + out_path)
	else:
		print("[GLTF Auto Processor] Saved: ", out_path)


func base_name_from_path(p: String) -> String:
	return p.get_file().get_basename()


func _relink_meshes(node: Node, root: Node, mesh_map: Dictionary) -> void:
	if node is MeshInstance3D:
		var rel: NodePath = root.get_path_to(node)
		# В дублированном дереве пути относительно нового root те же,
		# что и в оригинале (структура идентична)
		if mesh_map.has(rel):
			var path: String = mesh_map[rel]
			var loaded: Resource = ResourceLoader.load(path, "Mesh")
			if loaded != null:
				(node as MeshInstance3D).mesh = loaded

	for child in node.get_children():
		_relink_meshes(child, root, mesh_map)


func _relink_animations(node: Node, root: Node, animation_map: Dictionary) -> void:
	if node is AnimationPlayer:
		var player: AnimationPlayer = node
		var rel_path: NodePath = root.get_path_to(player)
		if animation_map.has(rel_path):
			var player_map: Dictionary = animation_map[rel_path]
			for library_name: StringName in player_map:
				var source_library: AnimationLibrary = player.get_animation_library(library_name)
				if source_library == null:
					continue

				# Дублируем библиотеку, чтобы не изменить общий ресурс у original.
				var replacement_library: AnimationLibrary = (
					source_library.duplicate(true) as AnimationLibrary
				)
				var library_map: Dictionary = player_map[library_name]
				for animation_name: StringName in library_map:
					var animation_path: String = library_map[animation_name]
					var loaded_animation: Animation = (
						ResourceLoader.load(animation_path, "Animation") as Animation
					)
					if loaded_animation == null:
						push_warning(
							"[GLTF Auto Processor] Failed to load animation: "
							+ animation_path
						)
						continue

					if replacement_library.has_animation(animation_name):
						replacement_library.remove_animation(animation_name)
					var add_err: int = replacement_library.add_animation(
						animation_name,
						loaded_animation
					)
					if add_err != OK:
						push_warning(
							"[GLTF Auto Processor] Failed to relink animation: "
							+ animation_path
						)

				player.remove_animation_library(library_name)
				var library_err: int = player.add_animation_library(
					library_name,
					replacement_library
				)
				if library_err != OK:
					push_warning(
						"[GLTF Auto Processor] Failed to replace animation library: "
						+ String(library_name)
					)

	for child in node.get_children():
		_relink_animations(child, root, animation_map)


func _wrap_with_body(original_root: Node, body_class: String, new_name: String) -> Node:
	# Создаём корневое тело
	var body: Node3D = ClassDB.instantiate(body_class)
	body.name = new_name

	# Переносим трансформ оригинального корня в тело (если он Node3D)
	if original_root is Node3D:
		body.transform = (original_root as Node3D).transform
		(original_root as Node3D).transform = Transform3D.IDENTITY

	# Переподвешиваем детей оригинального корня под тело
	# (сам original_root остаётся как промежуточный узел, чтобы сохранить иерархию имён)
	original_root.name = new_name + "_visual"
	body.add_child(original_root)

	# Создаём коллизии для каждого MeshInstance3D
	_add_collisions(original_root, body, body_class)

	return body


func _add_collisions(node: Node, body_root: Node, body_class: String) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			var shape: Shape3D
			if body_class == "RigidBody3D":
				# Для динамических тел — выпуклая форма (быстрее, стабильнее)
				shape = mi.mesh.create_convex_shape()
			else:
				# Для статики — точная триместная форма
				shape = mi.mesh.create_trimesh_shape()

			if shape != null:
				var col: CollisionShape3D = CollisionShape3D.new()
				col.shape = shape
				col.name = mi.name + "_col"
				# Коллизию вешаем на body_root, но с трансформом MeshInstance3D
				body_root.add_child(col)
				col.global_transform = mi.global_transform if mi.is_inside_tree() else mi.transform

	for child in node.get_children():
		_add_collisions(child, body_root, body_class)


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child != owner:
			child.owner = owner
		_set_owner_recursive(child, owner)
