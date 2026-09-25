extends System
## Presentation-only mesh highlight driven by authoritative C_Interactor target state.
class_name S_InteractionHighlight

const HIGHLIGHT_COLOR: Color = Color(1.0, 0.72, 0.12, 1.0)
const HIGHLIGHT_WIDTH: float = 0.035

var _highlight_material: StandardMaterial3D = null
var _previous_overlays: Dictionary[int, Material] = { }
var _previous_targets: Dictionary[int, WeakRef] = { }


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting] }


func query() -> QueryBuilder:
	return q.with_all([C_Interactor]).iterate([C_Interactor])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var interactors: Array = components[0]
	for index: int in entities.size():
		var holder: Entity = entities[index]
		var interactor: C_Interactor = interactors[index]
		var key: int = holder.get_instance_id()
		var previous_ref: WeakRef = _previous_targets.get(key) as WeakRef
		var previous: Node = previous_ref.get_ref() as Node if previous_ref != null else null
		var next: Node = InteractionTargetingService.visual_target(holder, interactor)
		if previous == next:
			continue
		_set_highlight(previous, false)
		_set_highlight(next, true)
		if next == null:
			_previous_targets.erase(key)
		else:
			_previous_targets[key] = weakref(next)


func _set_highlight(target: Node, enabled: bool) -> void:
	if not is_instance_valid(target):
		return
	var material: StandardMaterial3D = _get_highlight_material()
	for descendant: Node in target.find_children("*", "MeshInstance3D", true, false):
		_set_mesh_highlight(descendant as MeshInstance3D, material, enabled)


func _get_highlight_material() -> StandardMaterial3D:
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.resource_name = "InteractionHighlight"
		_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_material.albedo_color = HIGHLIGHT_COLOR
		_highlight_material.cull_mode = BaseMaterial3D.CULL_FRONT
		_highlight_material.grow = true
		_highlight_material.grow_amount = HIGHLIGHT_WIDTH
	return _highlight_material


func _set_mesh_highlight(
	mesh_instance: MeshInstance3D,
	material: StandardMaterial3D,
	enabled: bool,
) -> void:
	if mesh_instance == null or mesh_instance is PackageMarksView:
		return
	var instance_id: int = mesh_instance.get_instance_id()
	if enabled:
		if not _previous_overlays.has(instance_id):
			_previous_overlays[instance_id] = mesh_instance.material_overlay
		mesh_instance.material_overlay = material
	elif _previous_overlays.has(instance_id):
		if mesh_instance.material_overlay == material:
			mesh_instance.material_overlay = _previous_overlays[instance_id]
		_previous_overlays.erase(instance_id)
