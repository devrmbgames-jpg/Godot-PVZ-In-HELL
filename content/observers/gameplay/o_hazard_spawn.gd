extends Observer
## Sole generic hazard factory; idempotency is scoped to the World, never a global cooldown.
class_name O_HazardSpawn

var _accepted: Dictionary[String, bool] = { }


func query() -> QueryBuilder:
	return q.on_event(HazardSpawnRequest.EVENT)


func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var request: HazardSpawnRequest = payload as HazardSpawnRequest
	if request == null or _accepted.has(request.request_id):
		return

	_accepted[request.request_id] = true
	cmd.add_custom(_spawn.bind(request))


func _spawn(request: HazardSpawnRequest) -> void:
	if not is_instance_valid(_world) or request.definition == null:
		return

	var scene: PackedScene = request.definition.scene
	if scene == null:
		return

	var node: Node = scene.instantiate()
	var entity: Entity = node as Entity
	var spatial: Node3D = node as Node3D
	if entity == null or spatial == null or node is PhysicsBody3D:
		node.free()
		push_error("Hazard prefab requires a non-rigid Node3D Entity root")
		return

	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = request.definition
	hazard.request_id = request.request_id
	hazard.origin_id = request.origin_id
	hazard.instigator_id = request.instigator_id
	hazard.instigator = request.instigator if is_instance_valid(request.instigator) else null

	var lifetime: C_HazardLifetime = C_HazardLifetime.new()
	lifetime.remaining_seconds = request.definition.lifetime_seconds
	lifetime.persistent = request.definition.persistent

	var components: Array[Component] = [hazard, lifetime]
	var blocked: bool = request.damage_blocked
	if is_instance_valid(request.origin) and request.origin.has_component(C_NoDamage):
		blocked = true

	if blocked:
		components.append(C_NoDamage.new())

	if request.ownership == DEF_Hazard.Ownership.FollowOrigin:
		var owner_node: Node3D = null
		if is_instance_valid(request.origin):
			owner_node = request.origin as Node as Node3D
		if not EntityAvailability.contains(request.origin, _world) or owner_node == null:
			if request.owner_loss == DEF_Hazard.OwnerLoss.Despawn:
				node.free()
				return
		else:
			var follow: C_HazardFollow = C_HazardFollow.new()
			follow.origin = request.origin
			follow.on_loss = request.owner_loss
			follow.local_offset = owner_node.global_transform.affine_inverse() * request.world_pose
			components.append(follow)

	_world.add_child(node)
	spatial.global_transform = request.world_pose
	_world.add_entity(entity, components, false)

	var result: HazardSpawnResult = HazardSpawnResult.new()
	result.hazard = entity
	result.request_id = request.request_id
	result.origin_id = request.origin_id
	_world.emit_event(HazardSpawnResult.EVENT, entity, result)
