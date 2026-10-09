extends RefCounted
## На границе физического запроса сопоставляет дочерний collider с ближайшей Entity.
class_name HazardTargets


## Возвращает физический корень Entity либо ближайшего владельца дочернего тела.
static func entity_for(body: Node) -> Entity:
	var ancestor: Node = body
	while is_instance_valid(ancestor):
		if ancestor is Entity:
			return ancestor as Entity

		ancestor = ancestor.get_parent()

	return null
