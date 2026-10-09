extends DEF_InteractionAction
## E/F выбирают сопоставленные основную/дополнительную руки через общий resolver ввода.
class_name DEF_PhysicalSlotAction

## Использовать сопоставленную дополнительную руку вместо основной.
@export var secondary_hand: bool = false
## Извлекать из слота в руку; false помещает предмет руки в слот.
@export var take: bool = false


#region Перенос между рукой и слотом
## Проверяет помещение или извлечение в сопоставленную руку, включая разрешение замены.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var storage: E_PhysicalSlot = source as E_PhysicalSlot
	if storage == null:
		return false

	var hand: int = GrabQueries.mapped_hand(actor, secondary_hand)
	if not take:
		return PhysicalSlotService.can_store(actor, storage, hand)

	var config: C_PhysicalSlot = storage.get_component(C_PhysicalSlot) as C_PhysicalSlot
	return config != null and GrabService.can_take_from_storage(actor, PhysicalSlotService.occupant(storage), hand, config.allow_hand_replacement)


## Передаёт исполнение в complete с повторной проверкой.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	complete(actor, source, target)


## Выполняет перенос руки/слота и возвращает фактический успех транзакции.
func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	if not is_available(actor, source, null):
		return false

	var storage: E_PhysicalSlot = source as E_PhysicalSlot
	var hand: int = GrabQueries.mapped_hand(actor, secondary_hand)
	if not take:
		return PhysicalSlotService.store(actor, storage, hand)

	var config: C_PhysicalSlot = storage.get_component(C_PhysicalSlot) as C_PhysicalSlot
	return GrabService.take_from_storage(actor, PhysicalSlotService.occupant(storage), hand, config.allow_hand_replacement)

#endregion
