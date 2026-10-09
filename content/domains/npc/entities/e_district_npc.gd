@tool
extends E_NpcCharacter
## Презентация постоянного NPC и явные границы физического участия и телепортации.
class_name E_DistrictNpc

## Invokes higher-role cleanup at explicit native lifecycle boundaries, including passive restore.
signal role_cleanup_requested(request: NpcRoleCleanupRequest)
## Queries higher-role presence without importing that role's Component or implementation.
signal role_presence_requested(request: NpcRolePresenceRequest)
## Allows higher composition to supply its authored tree without a native-to-higher asset import.
signal brain_recipe_requested(request: NpcBrainRecipeRequest)

var _body_layer: int = 2
var _body_mask: int = 31
var _body_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT


#region Жизненный цикл движка
func _ready() -> void:
	super._ready()
	var body: RigidBody3D = self as Node as RigidBody3D
	_body_layer = body.collision_layer
	_body_mask = body.collision_mask
	_body_process_mode = process_mode
#endregion


#region Представление района
## Reads authored living collision policy while the dormant body's runtime mask is zero.
func participation_collision_mask() -> int:
	return _body_mask


## Изменяет физическое участие без удаления или сброса личности.
func set_participating(participating: bool) -> void:
	var body: RigidBody3D = self as Node as RigidBody3D
	# GECS stops root callbacks; the native mode also suspends inherited child animation work.
	process_mode = _body_process_mode if participating else Node.PROCESS_MODE_DISABLED
	body.freeze = not participating
	body.visible = participating
	body.collision_layer = _body_layer if participating else 0
	body.collision_mask = _body_mask if participating else 0
	if not participating:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	sync_navigation_lifecycle(participating)


## Разовая синхронизация при появлении, сне или загрузке; обычным движением владеет физика.
func place_at(world_position: Vector3) -> void:
	var body: RigidBody3D = self as Node as RigidBody3D
	var was_frozen: bool = body.freeze
	body.freeze = true
	body.global_position = world_position
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	body.freeze = was_frozen


## Показывает постоянную личность независимо от активного заказа.
func present_profile(profile: DEF_NpcProfile) -> void:
	show_message(profile.display_name)
	var skeleton_meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = profile.body_color
	for mesh_node: Node in skeleton_meshes:
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		mesh_instance.material_override = material
#endregion


#region Higher-role lifecycle boundary
## Publishes one synchronous lifecycle step without importing the higher role implementation.
func request_role_cleanup(kind: NpcRoleCleanupRequest.Kind, day_index: int = 0) -> void:
	role_cleanup_requested.emit(NpcRoleCleanupRequest.new(kind, day_index))
#endregion


#region Higher-role presence query
## Reads the optional installed role owner synchronously, including dormant/passive lifecycle use.
func has_active_role() -> bool:
	var request: NpcRolePresenceRequest = NpcRolePresenceRequest.new()
	role_presence_requested.emit(request)
	return request.active
#endregion


#region Authored decision recipe boundary
## Resolves an authored recipe; NpcBrainService binds and advances the single native runtime.
func decision_tree(native_tree: BehaviorTree) -> BehaviorTree:
	var request: NpcBrainRecipeRequest = NpcBrainRecipeRequest.new(native_tree)
	brain_recipe_requested.emit(request)
	assert(request.tree != null)
	return request.tree
#endregion
