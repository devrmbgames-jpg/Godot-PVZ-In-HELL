extends System
## material_overlay is reserved for interaction feedback. Base materials remain untouched.
class_name S_InteractionHighlight

@export var available_material: Material = preload("res://content/materials/interaction/highlight_available.res")
@export var unavailable_material: Material = preload("res://content/materials/interaction/highlight_unavailable.res")
@export var busy_material: Material = preload("res://content/materials/interaction/highlight_busy.res")

var _previous_overlays: Dictionary[int, Material] = {}
var _applied_materials: Dictionary[int, Material] = {}
var _previous_targets: Dictionary[int, WeakRef] = {}
var _previous_meshes: Dictionary[int, WeakRef] = {}
var _holder_states: Dictionary[int, int] = {}


func setup() -> void:
	_world.entity_removed.connect(_entity_unavailable)
	_world.entity_disabled.connect(_entity_unavailable)
	_world.component_removed.connect(_component_removed)


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_InteractionTargeting]}


func query() -> QueryBuilder:
	return q.with_all([C_Interactor]).iterate([C_Interactor])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var interactors: Array = components[0]
	for index: int in entities.size():
		var holder: Entity = entities[index]
		var interactor: C_Interactor = interactors[index] as C_Interactor
		var key: int = holder.get_instance_id()
		var target: Node = InteractionTargetingService.visual_target(holder, interactor)
		if not GrabService.holder_available(holder) or holder.has_component(C_Death) or InteractionControlFocus.current(holder) >= InteractionControlFocus.Priority.MODAL:
			target = null
		if target == null:
			_previous_targets.erase(key)
			_holder_states.erase(key)
		else:
			_previous_targets[key] = weakref(target)
			_holder_states[key] = InteractionHighlightService.state_for(holder, target)
	_refresh_meshes()


func _exit_tree() -> void:
	for key: int in _previous_meshes.keys():
		_clear_mesh(key)
	_previous_targets.clear()
	_holder_states.clear()
	super._exit_tree()


func _clear_holder(key: int) -> void:
	_previous_targets.erase(key)
	_holder_states.erase(key)
	_refresh_meshes()


func _entity_unavailable(entity: Entity) -> void:
	var key: int = entity.get_instance_id()
	_previous_targets.erase(key)
	_holder_states.erase(key)
	for holder_key: int in _previous_targets.keys():
		if _previous_targets[holder_key].get_ref() == entity:
			_previous_targets.erase(holder_key)
			_holder_states.erase(holder_key)
	_refresh_meshes()


func _component_removed(entity: Entity, component: Variant) -> void:
	if component is C_Interactor:
		_clear_holder(entity.get_instance_id())


func _refresh_meshes() -> void:
	var meshes: Dictionary[int, MeshInstance3D] = {}
	var states: Dictionary[int, int] = {}
	for holder_key: int in _previous_targets.keys():
		var target: Node = _previous_targets[holder_key].get_ref() as Node
		if target == null:
			_previous_targets.erase(holder_key)
			_holder_states.erase(holder_key)
			continue

		var state: int = _holder_states[holder_key]
		for descendant: Node in target.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = descendant as MeshInstance3D
			if mesh is PackageMarksView:
				continue

			var mesh_key: int = mesh.get_instance_id()
			meshes[mesh_key] = mesh
			states[mesh_key] = maxi(states.get(mesh_key, InteractionHighlightService.State.UNAVAILABLE), state)
	for mesh_key: int in _previous_meshes.keys():
		if not meshes.has(mesh_key):
			_clear_mesh(mesh_key)
	for mesh_key: int in meshes:
		var mesh: MeshInstance3D = meshes[mesh_key]
		var material: Material = _material_for(states[mesh_key])
		if material == null:
			_clear_mesh(mesh_key)
			continue
		if _applied_materials.has(mesh_key) and mesh.material_overlay != _applied_materials[mesh_key]:
			# Another interaction writer replaced our feedback: yield until target is released.
			continue
		if not _previous_overlays.has(mesh_key):
			_previous_overlays[mesh_key] = mesh.material_overlay
			_previous_meshes[mesh_key] = weakref(mesh)
		mesh.material_overlay = material
		_applied_materials[mesh_key] = material


func _clear_mesh(key: int) -> void:
	var reference: WeakRef = _previous_meshes.get(key) as WeakRef
	var mesh: MeshInstance3D = reference.get_ref() as MeshInstance3D if reference != null else null
	if mesh != null and mesh.material_overlay == _applied_materials.get(key):
		mesh.material_overlay = _previous_overlays.get(key) as Material
	_previous_meshes.erase(key)
	_previous_overlays.erase(key)
	_applied_materials.erase(key)


func _material_for(state: int) -> Material:
	match state:
		InteractionHighlightService.State.AVAILABLE:
			return available_material

		InteractionHighlightService.State.BUSY:
			return busy_material
	return unavailable_material
