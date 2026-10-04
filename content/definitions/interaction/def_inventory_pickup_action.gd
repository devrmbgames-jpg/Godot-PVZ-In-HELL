extends DEF_InteractionAction
## Переносит доступный предмет с карты в инвентарь действующего участника.
class_name DEF_InventoryPickupAction


## Проверяет интерактивность и допустимость переноса в инвентарь.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var interactable: C_Interactable = source.get_component(C_Interactable) as C_Interactable if EntityAvailability.contains(source, ECS.world) else null
	return interactable != null and interactable.enabled and InventoryService.can_transfer(source, actor)


## Повторно проверяет предмет и передаёт перенос сервису инвентаря.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	if is_available(actor, source, null):
		InventoryService.transfer(source, actor)
