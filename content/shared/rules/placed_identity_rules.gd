extends RefCounted
## Validates explicit scene identity and compiles immutable actor references before registration.
class_name PlacedIdentityRules

## Level-root authoring metadata containing its explicit world content token.
const WORLD_ID_META: StringName = &"persistent_world_id"
## Placed Entity authoring metadata containing its explicitly assigned local instance token.
const LOCAL_ID_META: StringName = &"persistent_local_id"

#region Authoring validation and compilation
## Validates the entire authored set before changing any recipe; duplicate/missing tokens reject it.
static func compile_for(root: Node) -> Array[String]:
	var actors: Array[Entity] = authored_actors(root)
	var issues: Array[String] = []
	if actors.is_empty():
		return issues

	var world_id: StringName = StringName(root.get_meta(WORLD_ID_META, &""))
	if not _valid_token(world_id):
		issues.append("Level requires explicit persistent_world_id authoring metadata")
	var local_ids: Dictionary[StringName, bool] = {}
	for actor: Entity in actors:
		var local_id: StringName = StringName(actor.get_meta(LOCAL_ID_META, &""))
		if not _valid_token(local_id):
			issues.append("%s requires explicit persistent_local_id" % root.get_path_to(actor))
		elif local_ids.has(local_id):
			issues.append("Duplicate placed identity %s/%s at %s"
				% [world_id, local_id, root.get_path_to(actor)])
		local_ids[local_id] = true
	if not issues.is_empty():
		return issues

	# This is authoring compilation, before GECS copies Components into registered state.
	# The metadata remains the authored input; runtime lookup reads the immutable Component.
	for actor: Entity in actors:
		var identity: C_AuthoredIdentity = component_for(actor)
		if identity == null:
			identity = C_AuthoredIdentity.new()
			actor.component_resources.append(identity)
		identity.world_id = world_id
		identity.local_id = StringName(actor.get_meta(LOCAL_ID_META))
	return issues


## Collects authored Entity nodes; runtime-spawned nodes with no scene owner are excluded.
static func authored_actors(root: Node) -> Array[Entity]:
	var actors: Array[Entity] = []
	for child: Node in root.find_children("*", "", true, false):
		var actor: Entity = child as Entity
		if actor != null and is_authored(actor, root):
			actors.append(actor)
	return actors


## Scene-owner ancestry must terminate at the level, excluding children of spawned prefab instances.
static func is_authored(actor: Entity, root: Node) -> bool:
	var scene_owner: Node = actor.owner
	while scene_owner != null:
		if scene_owner == root:
			return true
		scene_owner = scene_owner.owner
	return false
#endregion

#region Immutable reference lookup
## Reads registered state or an unregistered authored recipe without initializing it.
static func component_for(actor: Entity) -> C_AuthoredIdentity:
	var identity: C_AuthoredIdentity = actor.get_component(C_AuthoredIdentity) as C_AuthoredIdentity
	if identity != null:
		return identity
	for component: Component in actor.component_resources:
		if component is C_AuthoredIdentity:
			return component as C_AuthoredIdentity
	return null


## Derives lookup from immutable authored references; no alias map or mutable identity allocation.
static func resolver(root: Node) -> Dictionary[String, Entity]:
	var actors: Dictionary[String, Entity] = {}
	for actor: Entity in authored_actors(root):
		var identity: C_AuthoredIdentity = component_for(actor)
		if identity == null:
			var world_id: StringName = StringName(root.get_meta(WORLD_ID_META, &""))
			var local_id: StringName = StringName(actor.get_meta(LOCAL_ID_META, &""))
			if not _valid_token(world_id) or not _valid_token(local_id):
				return {}
			identity = C_AuthoredIdentity.new()
			identity.world_id = world_id
			identity.local_id = local_id
		if not _valid_token(identity.world_id) or not _valid_token(identity.local_id):
			return {}
		if actors.has(identity.actor_key()):
			return {}
		actors[identity.actor_key()] = actor
	return actors


static func _valid_token(token: StringName) -> bool:
	return not token.is_empty() and String(token).is_valid_identifier()
#endregion
