extends DEF_InteractionAction
## Открывает торговую панель доступного торговца вне ночной фазы.
class_name DEF_TraderAction


## Проверяет участников, торговую роль, экономику и фазу.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var cycle: C_DayCycle = DayPhaseService.current()
	return GrabService.holder_available(actor) and GrabService.holder_available(source) and source.has_component(C_Trader) and cycle != null and cycle.phase != C_DayCycle.Phase.NIGHT and CommerceService.current() != null


## Повторно проверяет доступность и открывает торговую панель.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if is_available(actor, source, target):
		CommercePanelService.open(actor, source)
