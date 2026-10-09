extends RefCounted
## Читает identity contracts владельцев без domain imports, allocation и mutable alias maps.
class_name ActorIdentityRules

#region Stable actor keys
## Reads generated domain identity, then immutable placed identity, then runtime identity.
static func key_for(entity: Entity, root: Node) -> String:
	var identity: C_ActorIdentityReference = _reference_for(entity, false)
	if identity != null:
		return identity.actor_key()
	if PlacedIdentityRules.is_authored(entity, root):
		var authored: C_AuthoredIdentity = PlacedIdentityRules.component_for(entity)
		assert(authored != null, "Placed actor requires compiled identity: %s" % root.get_path_to(entity))
		return authored.actor_key()
	return "runtime/" + entity.id


## Reads existing domain identity for diagnostics; an expired optional participant has no key.
static func trace_key_for(entity: Entity) -> String:
	if not is_instance_valid(entity):
		return ""
	var identity: C_ActorIdentityReference = _reference_for(entity, true)
	return identity.trace_key() if identity != null else entity.id


static func _reference_for(entity: Entity, diagnostic: bool) -> C_ActorIdentityReference:
	var selected: C_ActorIdentityReference = null
	var selected_priority: C_ActorIdentityReference.Specificity = (
		C_ActorIdentityReference.Specificity.NONE
	)
	# GECS indexes concrete classes; read their shared contract without duplicating keys.
	for component: Component in entity.components.values():
		var candidate: C_ActorIdentityReference = component as C_ActorIdentityReference
		if candidate == null:
			continue
		var priority: C_ActorIdentityReference.Specificity = (
			candidate.trace_key_priority() if diagnostic else candidate.actor_key_priority()
		)
		if priority > selected_priority:
			selected = candidate
			selected_priority = priority
	return selected
#endregion
