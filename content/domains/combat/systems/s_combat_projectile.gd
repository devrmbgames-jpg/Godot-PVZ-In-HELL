extends System
## Owns nonphysical projectile flight, full-step collision and terminal retirement.
class_name S_CombatProjectile

#region Scheduling
## Advances after a native attack may launch the projectile.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcCombat]}


## Selects live launch state; the projectile factory fully initializes it synchronously.
func query() -> QueryBuilder:
	return q.with_all([C_CombatProjectile]).enabled()


## Captures exact flight state so queued work cannot move a replaced component.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for projectile: Entity in entities:
		var captured: C_CombatProjectile = projectile.get_component(C_CombatProjectile) as C_CombatProjectile
		cmd.add_custom(_advance.bind(weakref(projectile), captured, delta))
#endregion

#region Flight and retirement
func _advance(projectile_reference: WeakRef, captured: C_CombatProjectile, delta: float) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var projectile: Entity = projectile_reference.get_ref() as Entity

	if not EntityAvailability.contains(projectile, _world) or projectile.get_component(C_CombatProjectile) != captured:
		return
	_step(projectile, delta)


func _step(projectile: Entity, delta: float) -> void:
	var state: C_CombatProjectile = projectile.get_component(C_CombatProjectile) as C_CombatProjectile
	var node: Node3D = projectile as Node as Node3D
	assert(node != null, "Flight state requires the factory's nonphysical Node3D projectile")

	var travel_seconds: float = minf(maxf(0.0, delta), state.remaining_seconds)
	var destination: Vector3 = node.global_position + state.velocity * travel_seconds
	var actor: Entity = _source_for(projectile)
	var exclude: Array[RID] = []
	if actor != null:
		exclude = CombatGeometry.exclusions(actor)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(node.global_position, destination, state.collision_mask, exclude)
	var hit: Dictionary = node.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Entity = hit.get("collider") as Node as Entity
		if target != null and target != actor and target.has_component(C_Health):
			var request: DamageRequest = DamageRequest.new()
			request.source = projectile
			request.instigator = actor
			request.instigator_id = state.instigator_id
			request.target = target
			request.amount = state.damage
			request.damage_type = DamageRequest.Type.PROJECTILE
			request.combat_context = state.attribution
			DamageRequestService.submit(request)
		_retire(projectile)
		return

	node.global_position = destination
	state.remaining_seconds -= travel_seconds
	if state.remaining_seconds <= 0.0:
		_retire(projectile)


func _retire(projectile: Entity) -> void:
	# Damage publication may already remove the source before its terminal flight operation.
	if is_instance_valid(projectile) and _world.entity_to_archetype.has(projectile):
		_world.remove_entity(projectile)


func _source_for(projectile: Entity) -> Entity:
	for relation: Relationship in projectile.relationships:
		if relation.relation is R_ProjectileSource:
			return relation.target as Entity if is_instance_valid(relation.target) else null
	return null
#endregion
