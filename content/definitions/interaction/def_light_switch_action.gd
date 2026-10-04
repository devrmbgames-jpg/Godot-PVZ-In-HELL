extends DEF_InteractionAction
## Переключает игровую световую цепь через доступный выключатель.
class_name DEF_LightSwitchAction


## Проверяет доступность участника, выключателя и световой цепи.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if not GrabService.holder_available(actor) or not EntityAvailability.contains(source, ECS.world):
		return false

	var interactable: C_Interactable = source.get_component(C_Interactable) as C_Interactable
	return (
		source.has_component(C_LightCircuit)
		and (interactable == null or interactable.enabled)
	)


## Повторно проверяет доступность и переключает цепь.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if is_available(actor, source, target):
		LightCircuitService.toggle(source)
