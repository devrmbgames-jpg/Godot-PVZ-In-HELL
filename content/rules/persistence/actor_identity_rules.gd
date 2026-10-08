extends RefCounted
## Resolves stable actor identity without serialization, allocation or mutable alias maps.
class_name ActorIdentityRules

#region Stable actor keys
## Uses generated domain identity first, then immutable placed identity, then allocated runtime identity.
static func key_for(entity: Entity, root: Node) -> String:
	var package: C_Package = entity.get_component(C_Package) as C_Package
	if package != null:
		return "package/" + package.package_id

	var identity: C_PersistentIdentity = entity.get_component(C_PersistentIdentity) as C_PersistentIdentity
	if identity != null:
		return identity.key
	if PlacedIdentityRules.is_authored(entity, root):
		var authored: C_AuthoredIdentity = PlacedIdentityRules.component_for(entity)
		assert(authored != null, "Placed actor requires compiled identity: %s" % root.get_path_to(entity))
		return authored.actor_key()
	return "runtime/" + entity.id
#endregion
