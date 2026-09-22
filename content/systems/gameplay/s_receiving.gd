extends System
class_name S_Receiving

const SPAWN_MARGIN: float = 0.03
const BLOCKED_RETRY_SECONDS: float = 0.25


#region GECS
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


func query() -> QueryBuilder:
	return q.with_all([C_Receiving]).iterate([C_Receiving])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var cycle: C_DayCycle = S_DayPhase.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING:
		return
	var states: Array = components[0]
	for entity_index: int in entities.size():
		var zone: E_ReceivingZone = entities[entity_index] as E_ReceivingZone
		var receiving: C_Receiving = states[entity_index]
		receiving.retry_remaining = maxf(0.0, receiving.retry_remaining - delta)
		if receiving.retry_remaining > 0.0:
			continue
		if zone != null:
			cmd.add_custom(_deliver_one.bind(zone, receiving, cycle.day_index))
#endregion


#region Delivery
func _deliver_one(zone: E_ReceivingZone, receiving: C_Receiving, day_index: int) -> void:
	if not is_instance_valid(zone) or zone.supply == null or zone.package_scene == null:
		return
	if receiving.last_started_day < day_index:
		var batch: DeliveryBatch = DeliveryBatch.new()
		batch.day_index = day_index
		receiving.pending.append(batch)
		receiving.last_started_day = day_index
	if receiving.pending.is_empty():
		return
	# Let physics register the previous body before checking another free slot.
	if receiving.last_spawn_tick == Engine.get_physics_frames():
		return
	var active_batch: DeliveryBatch = receiving.pending[0]
	if active_batch.next_package >= zone.supply.packages.size():
		receiving.pending.pop_front()
		receiving.blocked = false
		return
	var definition: DEF_Package = zone.supply.packages[active_batch.next_package]
	var package_id: String = "%s:%d:%s" % [zone.supply.key, active_batch.day_index, definition.key]
	# Also guard restored world state: existing parcels are never moved or recreated.
	for existing: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = existing.get_component(C_Package) as C_Package
		if identity.package_id == package_id:
			_advance(receiving, active_batch)
			return
	var parcel: E_Package = zone.package_scene.instantiate() as E_Package
	var body: RigidBody3D = parcel as Node as RigidBody3D
	var collision: CollisionShape3D = parcel.get_node("CollisionShape3D") as CollisionShape3D
	var query_parameters: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query_parameters.shape = collision.shape
	query_parameters.margin = SPAWN_MARGIN
	query_parameters.collision_mask = body.collision_mask | body.collision_layer
	var zone_node: Node3D = zone as Node as Node3D
	var space: PhysicsDirectSpaceState3D = zone_node.get_world_3d().direct_space_state
	for marker: Node in zone.spawn_points.get_children():
		var spawn_marker: Node3D = marker as Node3D
		query_parameters.transform = spawn_marker.global_transform * collision.transform
		if not space.intersect_shape(query_parameters, 1).is_empty():
			continue
		parcel.package_id = package_id
		parcel.package_definition = definition
		parcel.name = "Parcel_%03d_%02d" % [active_batch.day_index, active_batch.next_package + 1]
		body.mass = definition.mass_kg
		var component_resources: Array[Component] = parcel.component_resources.duplicate()
		var carry: C_Grabbable = null
		for component_index: int in component_resources.size():
			var component: Component = component_resources[component_index]
			if component is C_Grabbable:
				carry = component.duplicate() as C_Grabbable
				component_resources[component_index] = carry
				break
		if carry == null:
			parcel.free()
			return
		carry.movement_speed_multiplier = definition.carry_speed
		carry.movement_acceleration_multiplier = definition.carry_acceleration
		carry.throw_velocity = definition.throw_velocity
		parcel.component_resources = component_resources
		zone.package_parent.add_child(parcel)
		body.global_transform = spawn_marker.global_transform
		ECS.world.add_entity(parcel, null, false)
		receiving.last_spawn_tick = Engine.get_physics_frames()
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		identity.delivery_day = active_batch.day_index
		identity.supply_key = zone.supply.key
		var integrity: C_PackageIntegrity = parcel.get_component(C_PackageIntegrity)
		integrity.maximum = definition.maximum_integrity
		integrity.remaining = definition.maximum_integrity
		_advance(receiving, active_batch)
		return
	parcel.free()
	receiving.blocked = true
	receiving.retry_remaining = BLOCKED_RETRY_SECONDS


func _advance(receiving: C_Receiving, batch: DeliveryBatch) -> void:
	batch.next_package += 1
	receiving.delivered_counts[batch.day_index] = batch.next_package
	receiving.blocked = false
#endregion
