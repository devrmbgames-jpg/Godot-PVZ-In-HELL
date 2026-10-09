@tool
extends EntityTrait
## Compiles one district identity and immutable Profile tuning before native publication.
class_name ET_NpcIdentity


#region Identity contract
func _init() -> void:
	trait_id = &"npc_identity"
	required_root_class = &"RigidBody3D"
	required_components = [C_Motion]
	initial_field_names[C_NpcIdentity as Script] = PackedStringArray(["npc_id"])
	initial_field_names[C_PersistentIdentity as Script] = PackedStringArray(["key"])


## Requires a captured roster identity rather than allocating or consulting the current World.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	if not context.actor is E_DistrictNpc:
		return PackedStringArray(["District identity requires E_DistrictNpc"])
	var identity_fields: Dictionary = context.initial_fields.get(C_NpcIdentity as Script, { })
	var persistent_fields: Dictionary = context.initial_fields.get(
		C_PersistentIdentity as Script,
		{ },
	)
	var npc_id: String = String(identity_fields.get(&"npc_id", ""))
	if npc_id.is_empty() or String(persistent_fields.get(&"key", "")) != npc_id:
		return PackedStringArray(["District identity requires one matching roster/persistent key"])
	if not context.definitions.get(&"npc_profile") is DEF_NpcProfile:
		return PackedStringArray(["District identity requires the roster's NPC Profile"])
	return PackedStringArray()
#endregion


#region Pure recipes
## Supplies fresh identity records; the compiler applies the enumerated instance key fields.
func recipes_for(_context: EntitySpawnContext) -> Array[Component]:
	return [C_NpcIdentity.new(), C_PersistentIdentity.new()]


## Configures movement from the single immutable Profile; saved fields overlay after defaults.
func configuration_for(context: EntitySpawnContext) -> Dictionary[Script, Dictionary]:
	var profile: DEF_NpcProfile = context.definitions.get(&"npc_profile") as DEF_NpcProfile
	if profile == null:
		return { }
	return { C_Motion as Script: { &"max_speed": profile.move_speed } }
#endregion
