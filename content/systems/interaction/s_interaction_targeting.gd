extends System
## Selects the first-hit gameplay target and an optional generic rigid-body Carry target.
class_name S_InteractionTargeting

#region Highlight tuning
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.72, 0.12, 1.0)
const HIGHLIGHT_WIDTH: float = 0.035

var _highlight_material: StandardMaterial3D = null
var _previous_overlays: Dictionary[int, Material] = { }
#endregion


#region GECS
func query() -> QueryBuilder:
	return q.with_all([C_Interactor]).iterate([C_Interactor])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var interactors: Array = components[0]
	for entity_index: int in entities.size():
		var holder: Entity = entities[entity_index]
		var interactor: C_Interactor = interactors[entity_index]
		var previous_visual: Node = _visual_target(holder, interactor)

		var collider: Object = (
			_raycast_collider(holder, interactor) if S_Grab.holder_available(holder) else null
		)
		interactor.target = _interactable_entity(collider, holder)
		interactor.physics_target = collider_rigid_body(collider, holder)

		var next_visual: Node = _visual_target(holder, interactor)
		if previous_visual != next_visual:
			set_highlight(previous_visual, false)
			set_highlight(next_visual, true)
#endregion


#region Public API
## Returns only an enabled GECS interaction target. Raw physics is exposed separately.
static func find_target(holder: Entity, interactor: C_Interactor) -> Entity:
	return _interactable_entity(_raycast_collider(holder, interactor), holder)


## Returns the first rigid body hit by the interaction ray, regardless of GECS membership.
static func find_physics_target(holder: Entity, interactor: C_Interactor) -> RigidBody3D:
	return collider_rigid_body(_raycast_collider(holder, interactor), holder)


static func collider_entity(collider: Object) -> Entity:
	var candidate_node: Node = collider as Node
	while candidate_node != null:
		if candidate_node is Entity:
			return candidate_node as Entity
		candidate_node = candidate_node.get_parent()
	return null


static func collider_rigid_body(collider: Object, holder: Entity = null) -> RigidBody3D:
	var candidate_node: Node = collider as Node
	while candidate_node != null:
		var body: RigidBody3D = candidate_node as RigidBody3D
		if body != null:
			if is_instance_valid(holder) and body == (holder as Node as RigidBody3D):
				return null
			return body
		candidate_node = candidate_node.get_parent()
	return null


func set_highlight(target: Node, enabled: bool) -> void:
	if not is_instance_valid(target):
		return
	var material: StandardMaterial3D = _get_highlight_material()
	var descendants: Array[Node] = target.find_children("*", "MeshInstance3D", true, false)
	for descendant: Node in descendants:
		_set_mesh_highlight(descendant as MeshInstance3D, material, enabled)
#endregion


#region Private helpers
static func _raycast_collider(holder: Entity, interactor: C_Interactor) -> Object:
	var interaction_raycast: RayCast3D = S_Grab.interaction_raycast(holder)
	if (
		not is_instance_valid(interaction_raycast)
		or not interaction_raycast.is_inside_tree()
		or interactor == null
	):
		return null

	interaction_raycast.enabled = true
	interaction_raycast.target_position = (
		Vector3.FORWARD * maxf(interactor.interaction_distance, 0.1)
	)
	interaction_raycast.collision_mask = interactor.collision_mask
	interaction_raycast.clear_exceptions()

	var holder_body: CollisionObject3D = holder as Node as CollisionObject3D
	if holder_body != null:
		interaction_raycast.add_exception_rid(holder_body.get_rid())
	for slot_index: int in 3:
		var held: Entity = S_Grab.held_in_slot(holder, slot_index)
		var held_body: CollisionObject3D = PhysicsGrabTarget.body_for(held)
		if held_body != null:
			interaction_raycast.add_exception_rid(held_body.get_rid())

	interaction_raycast.force_raycast_update()
	return interaction_raycast.get_collider() if interaction_raycast.is_colliding() else null


static func _interactable_entity(collider: Object, holder: Entity) -> Entity:
	var candidate: Entity = collider_entity(collider)
	if not is_instance_valid(candidate) or candidate == holder or not candidate.enabled:
		return null
	var interactable: C_Interactable = candidate.get_component(C_Interactable) as C_Interactable
	return candidate if interactable != null and interactable.enabled else null


static func _visual_target(holder: Entity, interactor: C_Interactor) -> Node:
	if interactor == null:
		return null
	if is_instance_valid(interactor.target):
		return interactor.target as Node
	if not is_instance_valid(interactor.physics_target):
		return null
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	return (
		interactor.physics_target
		if control != null and control.can_carry_body(interactor.physics_target)
		else null
	)


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
#endregion
