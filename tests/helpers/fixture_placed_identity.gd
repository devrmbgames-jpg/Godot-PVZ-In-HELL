extends RefCounted
## Assigns explicit fixture authoring tokens once; never changes identity during capture or restore.
class_name FixturePlacedIdentity

static var _next_instance: int = 1

#region Explicit fixture authoring
## Allocates a unique local fixture instance token at its authored construction point.
## Registers immutable identity directly if this fixture authored an already-registered Entity.
static func assign(root: Node, actor: Entity, role: StringName) -> void:
	var local_id: StringName = StringName("%s_%d" % [role, _next_instance])
	_next_instance += 1
	root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	_assign_one(actor, local_id)

	# These fixed prefab roles are explicit fixture contracts, not inferred actor identity.
	var child_roles: Dictionary[String, String] = {
		"BeltSlotLeft": "left_belt",
		"BeltSlotRight": "right_belt",
		"InspectionParcelSlot": "inspection_slot",
	}
	for child_path: String in child_roles:
		var child: Entity = actor.get_node_or_null(NodePath(child_path)) as Entity
		if child != null:
			_assign_one(child, StringName("%s_%s" % [local_id, child_roles[child_path]]))


static func _assign_one(actor: Entity, local_id: StringName) -> void:
	actor.set_meta(PlacedIdentityRules.LOCAL_ID_META, local_id)
	var identity: C_AuthoredIdentity = C_AuthoredIdentity.new()
	identity.world_id = &"fixture"
	identity.local_id = local_id
	if ECS.world.entity_to_archetype.has(actor):
		actor.add_component(identity)
	else:
		actor.component_resources.append(identity)
#endregion
