extends DEF_ItemAccessProvider
## Доступ к обеим рукам и Carry через единые авторитетные связи R_HeldBy.
class_name DEF_HeldItemAccess


#region Предметы физических рук
## Возвращает доступные предметы обеих рук и Carry по живым связям удержания.
func items(actor: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	for slot: int in [C_Grabbable.HoldSlot.LEFT_HAND, C_Grabbable.HoldSlot.RIGHT_HAND, C_Grabbable.HoldSlot.CARRY]:
		var item: Entity = GrabQueries.held_in_slot(actor, slot)
		if GrabQueries.entity_available(item):
			result.append(item)
	return result


## Проверяет доступного держателя и наличие предмета в его физических слотах.
func can_consume(actor: Entity, item: Entity) -> bool:
	return GrabQueries.holder_available(actor) and items(actor).has(item)


## Повторно проверяет удержание, освобождает хват и удаляет конкретный предмет из World.
func consume(actor: Entity, item: Entity) -> bool:
	if not can_consume(actor, item):
		return false

	GrabReleaseService.release(actor, item)
	ECS.world.remove_entity(item)
	return true

#endregion
