extends RefCounted
## Явная идентичность и удаление обычного тела; grab-proxy остаётся временным мостом.
class_name RawPhysicsActorService

## Persistent native group; suffix is an explicit placed/runtime UUID, never a NodePath.
const ID_GROUP_PREFIX: String = "raw_actor/"


#region Identity and lifetime
## Native bodies inside an Entity are parts of that actor, not independent free cargo.
static func is_standalone(body: RigidBody3D) -> bool:
	var parent: Node = body.get_parent()
	while parent != null:
		if parent is Entity:
			return false
		parent = parent.get_parent()
	return true


## Reads the body's single explicit identity; malformed/ambiguous groups fail closed.
static func actor_id(body: RigidBody3D) -> String:
	var result: String = ""
	for group: StringName in body.get_groups():
		var name: String = String(group)
		if not name.begins_with(ID_GROUP_PREFIX):
			continue
		var candidate: String = name.trim_prefix(ID_GROUP_PREFIX)
		if not result.is_empty() or not valid_id(candidate):
			return ""
		result = candidate
	return result


## Checks the closed stable-ID shape used by authored groups and cargo records.
static func valid_id(value: String) -> bool:
	var parts: PackedStringArray = value.split("/")
	return (
		parts.size() == 2 and parts[0] in ["placed", "runtime"]
		and parts[1].length() == 32 and parts[1].is_valid_hex_number(false)
	)


## Gives an untagged runtime body an opaque ID for an explicit cargo transaction.
static func identify(body: RigidBody3D) -> String:
	var identity: String = actor_id(body)
	if body.owner != null and not identity.begins_with("placed/"):
		# Placed bodies declare their identity in the scene before departure.
		return ""
	if not identity.is_empty():
		return identity
	for group: StringName in body.get_groups():
		if String(group).begins_with(ID_GROUP_PREFIX):
			return ""
	identity = "runtime/" + Crypto.new().generate_random_bytes(16).hex_encode()
	body.add_to_group(StringName(ID_GROUP_PREFIX + identity))
	return identity


## Resolves one live body by identity; duplicate IDs never select an arbitrary actor.
static func find(root: Node, identity: String) -> RigidBody3D:
	var result: RigidBody3D = null
	for node: Node in root.find_children("*", "RigidBody3D", true, false):
		var body: RigidBody3D = node as RigidBody3D
		if body.is_queued_for_deletion() or actor_id(body) != identity:
			continue
		if result != null:
			return null
		result = body
	return result


## Detaches the real body synchronously and releases its transient GECS bridge once.
static func remove(body: RigidBody3D) -> void:
	var proxy: Entity = PhysicsGrabTarget.handle_for(body, false)
	if proxy != null:
		var grip: Relationship = GrabQueries.held_relationship(proxy)
		if grip != null:
			GrabReleaseService.release(grip.target as Entity, proxy)
		GrabReleaseService.entity_unavailable(proxy)
		ECS.world.remove_entity(proxy)
	body.get_parent().remove_child(body)
	body.queue_free()
#endregion
