extends RefCounted
## Presence/pose snapshot for explicitly identified native physics placements.
## Native body authority is overridden only at the explicit prevalidated reconstruction boundary.
class_name RawPhysicsSnapshot


#region Authoring recipes and coherent capture
## Returns the complete authored inventory, including disposed bodies; {} means invalid authoring.
static func capture(root: Node) -> Dictionary:
	var catalog: Dictionary = _catalog(root)
	if catalog.is_empty():
		return { }
	var records: Array[Dictionary] = []
	for identity: String in catalog.actors:
		var body: RigidBody3D = RawPhysicsActorService.find(root, identity)
		var record: Dictionary = { "actor_id": identity, "present": body != null }
		if body != null:
			record.pose = body.global_transform
			record.freeze = body.freeze
			record.freeze_mode = int(body.freeze_mode)
			record.can_sleep = body.can_sleep
			var proxy: Entity = PhysicsGrabTarget.handle_for(body, false)
			var grip: Relationship = GrabQueries.held_relationship(proxy) if proxy != null else null
			if grip != null:
				var held: R_HeldBy = grip.relation as R_HeldBy
				if held.lifecycle_applied:
					# Restore releases Carry; its temporary sleep veto is not durable body state.
					record.can_sleep = held.previous_can_sleep
		records.append(record)
	return { "actors": records }


## Prevalidates every ID, pose and native recipe without changing the live level.
## Catalog validation instantiates/frees detached native prefab probes; no World registration.
static func valid(records: Variant, root: Node) -> bool:
	if not records is Array:
		return false
	var catalog: Dictionary = _catalog(root)
	if catalog.is_empty() or (records as Array).size() != (catalog.actors as Dictionary).size():
		return false
	var seen: Dictionary[String, bool] = { }
	for value: Variant in records:
		if not value is Dictionary:
			return false
		var record: Dictionary = value as Dictionary
		if (
			not record.get("actor_id") is String or not record.get("present") is bool
			or not (catalog.actors as Dictionary).has(record.actor_id) or seen.has(record.actor_id)
		):
			return false
		seen[String(record.actor_id)] = true
		if record.present:
			if (
				not record.get("pose") is Transform3D
				or not (record.pose as Transform3D).is_finite() or not record.get("freeze") is bool
				or not record.get("can_sleep") is bool or not record.get("freeze_mode") is int
				or record.get("freeze_mode")
				not in [RigidBody3D.FREEZE_MODE_STATIC, RigidBody3D.FREEZE_MODE_KINEMATIC]
			):
				return false
	return true


## Rejects a removed journal entry paired with a restored body, or a pending missing body.
## Requires structurally validated records and decoded Components from the full snapshot preflight.
static func valid_receipts(records: Array, components: Dictionary[String, Dictionary]) -> bool:
	var presence: Dictionary[String, bool] = { }
	for record: Dictionary in records:
		presence[String(record.actor_id)] = bool(record.present)
	for types: Dictionary in components.values():
		var receiving: C_Receiving = types.get(C_Receiving) as C_Receiving
		if receiving == null:
			continue
		for receipt: TruckCargoReceipt in receiving.cargo_receipts:
			if receipt == null:
				return false
			if receipt.raw_actor_id.is_empty():
				continue
			if receipt.raw_actor_id.begins_with("placed/"):
				if not presence.has(receipt.raw_actor_id):
					return false
				if presence[receipt.raw_actor_id] == receipt.removed:
					return false
			elif not receipt.removed:
				# An ad-hoc runtime body has no authored reconstruction recipe.
				return false
	return true


## Applies an already prevalidated snapshot inside the world's reconstruction boundary.
## Recreates/removes bodies and releases old hand bindings.
## Restores world pose/flags and zeroes velocity.
static func restore(records: Array, root: Node) -> void:
	var catalog: Dictionary = _catalog(root)
	for record: Dictionary in records:
		var body: RigidBody3D = RawPhysicsActorService.find(root, String(record.actor_id))
		if not record.present:
			if body != null:
				RawPhysicsActorService.remove(body)
			continue
		if body != null:
			# Old hand constraints cannot survive a load, even when retaining the same body.
			var proxy: Entity = PhysicsGrabTarget.handle_for(body, false)
			if proxy != null:
				var grip: Relationship = GrabQueries.held_relationship(proxy)
				if grip != null:
					GrabReleaseService.release(grip.target as Entity, proxy)
		else:
			var recipe: Dictionary = (catalog.actors as Dictionary)[record.actor_id]
			body = (recipe.prefab as PackedScene).instantiate() as RigidBody3D
			body.name = recipe.name as StringName
			for property: StringName in recipe.properties:
				body.set(property, (recipe.properties as Dictionary)[property])
			for group: String in recipe.groups:
				body.add_to_group(StringName(group), true)
			(recipe.parent as Node).add_child(body)
			body.owner = root
		body.global_transform = record.pose as Transform3D
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = bool(record.freeze)
		body.freeze_mode = int(record.freeze_mode) as RigidBody3D.FreezeMode
		body.can_sleep = bool(record.can_sleep)
#endregion


#region Trusted native definitions
static func _catalog(root: Node) -> Dictionary:
	var actors: Dictionary[String, Dictionary] = { }
	if root.scene_file_path.is_empty():
		return { "actors": actors }
	var packed: PackedScene = load(root.scene_file_path) as PackedScene
	if packed == null:
		return { }
	var state: SceneState = packed.get_state()
	for index: int in state.get_node_count():
		var identity: String = ""
		for group: String in state.get_node_groups(index):
			if not group.begins_with(RawPhysicsActorService.ID_GROUP_PREFIX):
				continue
			if not identity.is_empty():
				return { }
			identity = group.trim_prefix(RawPhysicsActorService.ID_GROUP_PREFIX)
		if identity.is_empty():
			continue
		if (
			not RawPhysicsActorService.valid_id(identity)
			or not identity.begins_with("placed/") or actors.has(identity)
		):
			return { }
		var prefab: PackedScene = state.get_node_instance(index)
		var parent: Node = root.get_node_or_null(state.get_node_path(index, true))
		if prefab == null or parent == null:
			return { }
		var probe: Node = prefab.instantiate()
		var compatible: bool = probe is RigidBody3D and probe.get_script() == null
		probe.free()
		if not compatible:
			return { }
		var properties: Dictionary[StringName, Variant] = { }
		for property_index: int in state.get_node_property_count(index):
			var property: StringName = state.get_node_property_name(index, property_index)
			var value: Variant = state.get_node_property_value(index, property_index)
			if property == &"script" and value != null:
				return { }
			properties[property] = value
		var present: Node = root.get_node_or_null(state.get_node_path(index))
		if present != null and not present.is_queued_for_deletion():
			if not present is RigidBody3D or present.get_script() != null:
				return { }
			if RawPhysicsActorService.actor_id(present as RigidBody3D) != identity:
				return { }
		actors[identity] = {
			"prefab": prefab,
			"parent": parent,
			"name": state.get_node_name(index),
			"properties": properties,
			"groups": state.get_node_groups(index),
		}
	var live_ids: Dictionary[String, bool] = { }
	for node: Node in root.find_children("*", "RigidBody3D", true, false):
		var body: RigidBody3D = node as RigidBody3D
		if body.is_queued_for_deletion():
			continue
		var identity: String = RawPhysicsActorService.actor_id(body)
		if (
			body.get_script() == null and body.owner != null
			and RawPhysicsActorService.is_standalone(body)
			and not body.is_in_group(GrabQueries.NO_CARRY_GROUP)
			and not body.freeze and not identity.begins_with("placed/")
		):
			return { }
		if not identity.begins_with("placed/"):
			continue
		if not actors.has(identity) or live_ids.has(identity) or body.get_script() != null:
			return { }
		live_ids[identity] = true
	return { "actors": actors }
#endregion
