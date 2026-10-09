extends Observer
## Общая фабрика опасностей; выбирает авторское определение запроса или сцены.
class_name O_HazardSpawn

var _accepted: Dictionary[String, bool] = { }


#region Приём запросов
## Подписывается на общие типизированные запросы создания опасности.
func query() -> QueryBuilder:
	return q.on_event(HazardSpawnRequest.EVENT)


## Запоминает ID до результата создания и ставит единственную попытку в CommandBuffer.
func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var request: HazardSpawnRequest = payload as HazardSpawnRequest
	if request == null:
		return
	if _accepted.has(request.request_id):
		BoundaryTrace.record(&"hazards.spawn", StringName(request.request_id),
			BoundaryTraceEntry.Stage.DUPLICATE, &"already_accepted", request.origin_id, request.request_id)
		return

	_accepted[request.request_id] = true
	cmd.add_custom(_spawn.bind(request))


#endregion

#region Создание автономного эффекта
func _spawn(request: HazardSpawnRequest) -> void:
	if not is_instance_valid(_world) or request.scene == null:
		_rejected(request, &"world_or_prefab_unavailable")
		return

	var node: Node = request.scene.instantiate()
	var entity: Entity = node as Entity
	var spatial: Node3D = node as Node3D
	var prefab: E_Hazard = node as E_Hazard
	if entity == null or spatial == null or prefab == null or node is PhysicsBody3D:
		node.free()
		push_error("Hazard prefab requires a non-rigid E_Hazard Node3D root")
		_rejected(request, &"invalid_prefab_root")
		return

	var definition: DEF_Hazard = request.definition if request.definition != null else prefab.definition
	prefab.definition = definition
	if (
		definition == null
		or not is_finite(definition.lifetime_seconds)
		or definition.lifetime_seconds <= 0.0
	):
		node.free()
		push_error("Hazard prefab requires a valid embedded DEF_Hazard definition")
		_rejected(request, &"invalid_definition")
		return

	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = definition
	hazard.origin = request.origin if is_instance_valid(request.origin) else null
	hazard.request_id = request.request_id
	hazard.origin_id = request.origin_id
	hazard.instigator_id = request.instigator_id
	hazard.instigator = request.instigator if is_instance_valid(request.instigator) else null

	var lifetime: C_HazardLifetime = C_HazardLifetime.new()
	lifetime.remaining_seconds = definition.lifetime_seconds
	lifetime.persistent = definition.persistent

	var components: Array[Component] = [hazard, lifetime]
	var blocked: bool = request.damage_blocked
	if is_instance_valid(request.origin) and request.origin.has_component(C_NoDamage):
		blocked = true
	if blocked:
		components.append(C_NoDamage.new())

	var follow: R_HazardFollow = null
	if definition.ownership == DEF_Hazard.Ownership.FollowOrigin:
		var owner_node: Node3D = null
		if is_instance_valid(request.origin):
			owner_node = request.origin as Node as Node3D
		if not EntityAvailability.contains(request.origin, _world) or owner_node == null:
			if definition.owner_loss == DEF_Hazard.OwnerLoss.Despawn:
				node.free()
				_rejected(request, &"required_owner_unavailable")
				return
		else:
			follow = R_HazardFollow.new()
			follow.on_loss = definition.owner_loss
			follow.local_offset = owner_node.global_transform.affine_inverse() * request.world_pose

	_world.add_child(node)
	spatial.global_transform = request.world_pose
	entity.component_resources = entity.component_resources.duplicate()
	entity.component_resources.append_array(components)
	var context: EntitySpawnContext = EntityCompositionService.context_for(entity, _world,
		entity.id if not entity.id.is_empty() else GECSIO.uuid())
	if follow != null:
		context.bindings[&"origin"] = request.origin
		var follow_intent: EntityInitialBinding = EntityInitialBinding.new()
		follow_intent.relation = follow
		follow_intent.endpoint = &"origin"
		context.initial_bindings = [follow_intent]
	if not EntityCompositionService.try_register(context, false):
		node.free()
		_rejected(request, &"invalid_composition")
		return
	if follow != null:
		HazardFollowService.bind_lifecycle(entity)

	var result: HazardSpawnResult = HazardSpawnResult.new()
	result.hazard = entity
	result.request_id = request.request_id
	result.origin_id = request.origin_id
	BoundaryTrace.record(&"hazards.spawn", StringName(request.request_id),
		BoundaryTraceEntry.Stage.COMPLETED, &"spawned", request.origin_id, request.request_id)
	_world.emit_event(HazardSpawnResult.EVENT, entity, result)

func _rejected(request: HazardSpawnRequest, reason: StringName) -> void:
	BoundaryTrace.record(&"hazards.spawn", StringName(request.request_id),
		BoundaryTraceEntry.Stage.REJECTED, reason, request.origin_id, request.request_id)


#endregion
