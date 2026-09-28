extends Resource
## Stateless adapter for authorized item sources. Ownership stays in Relationships.
class_name DEF_ItemAccessProvider


func items(_actor: Entity) -> Array[Entity]:
	return []


func can_consume(_actor: Entity, _item: Entity) -> bool:
	return false


## Must revalidate ownership and fail without side effects when consumption is refused.
func consume(_actor: Entity, _item: Entity) -> bool:
	return false
