@tool
extends Node3D
class_name ToolMultiMeshGenerator


@export var gen_collision := false
@export var remove_old := false
@export_range(1.0, 99999.0) var octan_size := 8.0
@export_tool_button("Apply") var gen := _generate

var _mesh_instances: Dictionary = {}
var _remove_list := []
var _shapes := []

func _parse_recursive(node: Node) -> void :
	for i in node.get_child_count() :
		var child := node.get_child(i)
		_parse_recursive(child)
	
	if node != self :
		if remove_old :
			_remove_list.append(node)
	
	if gen_collision :
		if node is CollisionShape3D :
			_shapes.append(node)
	
	if node is MeshInstance3D :
		var mesh := node.mesh as Mesh
		var mat := node.get_active_material(0) as Material
		
		var octan := Vector3i(node.global_position) / Vector3i(octan_size, octan_size, octan_size)
		var octan_dict := _mesh_instances.get_or_add(octan, {}) as Dictionary
		var mat_dict: Dictionary = octan_dict.get_or_add(mesh, {}) as Dictionary
		var arr := mat_dict.get_or_add(mat, []) as Array
		arr.append(node)



func _generate() -> void :
	_mesh_instances.clear()
	_shapes.clear()
	_remove_list.clear()
	
	_parse_recursive(self)
	
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	
	for octan_key in _mesh_instances :
		var octan := octan_key as Vector3i
		var global_pos_to_octan := octan * octan_size
		var mesh_dict := _mesh_instances[octan_key] as Dictionary
		for key_mesh in mesh_dict :
			var mesh := key_mesh as Mesh
			var mat_dict: Dictionary = mesh_dict[key_mesh] as Dictionary
			for key_mat in mat_dict :
				var mat := key_mat as Material
				var arr := mat_dict[key_mat] as Array
				
				var multimesh_instance := MultiMeshInstance3D.new()
				add_child(multimesh_instance)
				
				await get_tree().process_frame
				await get_tree().process_frame
				
				multimesh_instance.global_position = global_pos_to_octan
				multimesh_instance.name = "MMGen"
				multimesh_instance.owner = owner if owner else self
				multimesh_instance.material_override = mat
				
				
				var multimesh := MultiMesh.new()
				multimesh_instance.multimesh = multimesh
				
				multimesh_instance.multimesh.mesh = mesh
				multimesh_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh_instance.multimesh.instance_count = arr.size()
				
				var multimesh_global_transform := multimesh_instance.global_transform
				
				
				for idx in arr.size() :
					var mesh_instance := arr[idx] as MeshInstance3D
					var mesh_instance_global_transform := mesh_instance.global_transform
					var mesh_local_transform := multimesh_global_transform.affine_inverse() * mesh_instance_global_transform
					
					
					multimesh_instance.multimesh.set_instance_transform(idx, mesh_local_transform)
					
	
	
	await get_tree().process_frame
	if gen_collision :
		
		var static_body := StaticBody3D.new()
		add_child(static_body, true)
		static_body.owner = owner if owner else self
		
		await get_tree().process_frame
		
		for shape in _shapes :
			var exist_shape := shape as CollisionShape3D
			var new_shape := CollisionShape3D.new()
			new_shape.shape = exist_shape.shape
			
			var g_node_tr := exist_shape.global_transform
			var g_tr := static_body.global_transform
			var local_tr := g_tr.affine_inverse() * g_node_tr
			static_body.add_child(new_shape)
			new_shape.owner = owner if owner else self
			new_shape.name = "CShape"
			new_shape.transform = local_tr
	
	await get_tree().process_frame
	
	for val in _remove_list :
		val.queue_free()
	
