extends DEF_ItemAccessProvider
## Доступ к конкретным предметам в слотах, закреплённых на акторе через Relationships.
class_name DEF_WornItemAccess


#region Предметы надетых слотов
## Возвращает реальные предметы в физических слотах на этом акторе.
func items(actor: Entity) -> Array[Entity]:
	return PhysicalSlotService.worn_items(actor)


## Проверяет принадлежность конкретного предмета одному из надетых слотов актора.
func can_consume(actor: Entity, item: Entity) -> bool:
	return items(actor).has(item)


## Повторно проверяет слот, освобождает крепление и удаляет предмет из World.
func consume(actor: Entity, item: Entity) -> bool:
	if not can_consume(actor, item):
		return false

	PhysicalSlotService.release(item)
	ECS.world.remove_entity(item)
	return true

#endregion
