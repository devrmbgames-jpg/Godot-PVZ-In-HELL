extends RefCounted
## Resolves physical child colliders to their nearest gameplay Entity at the query boundary.
class_name HazardTargets


## Supports either an Entity physics root or a physical child under an Entity root.
static func entity_for(body: Node) -> Entity:
	var ancestor: Node = body
	while is_instance_valid(ancestor):
		if ancestor is Entity:
			return ancestor as Entity
		ancestor = ancestor.get_parent()

	return null
