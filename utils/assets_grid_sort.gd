@tool
extends Node
## Редакторский инструмент размещения дочерних ассетов сеткой и создания trimesh-коллизий.
class_name ToolNodeGridSort

## Количество позиций в ряду; существующее имя экспортного свойства сохраняется.
@export_range(1, 100000) var collumn: int = 10
## Шаг сетки по X/Z в метрах; высота дочерних узлов сохраняется.
@export var interval := 5.0

## Редакторская кнопка раскладки дочерних Node3D.
@export_tool_button("SORT") var sort_apply := _sort
## Редакторская кнопка создания trimesh-коллизий дочерних MeshInstance3D.
@export_tool_button("CREATE SHAPES") var create_shape := _gen_mesh


#region Редакторские действия
func _sort() -> void :
	
	for i in get_child_count() :
		var x_idx := 0
		if i > 0 and collumn > 0 :
			x_idx = i / collumn
		
		var z_idx := 0
		if i > 0 and collumn > 0 :
			z_idx = i % collumn
		
		var node := get_child(i)
		if node is Node3D :
			node.position.x = x_idx * interval
			node.position.z = z_idx * interval


func _gen_mesh() -> void :
	for i in get_child_count() :
		var node := get_child(i)
		if node is MeshInstance3D :
			var mi := node as MeshInstance3D
			mi.create_trimesh_collision()

#endregion
