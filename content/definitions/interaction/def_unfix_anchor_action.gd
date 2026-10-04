extends DEF_InteractionAction
## Авторское длительное действие F на предмете, ранее закреплённом игроком.
class_name DEF_UnfixAnchorAction


func _init() -> void:
	action_id = &"unfix_anchor"
	slot = Slot.USE
	caption = "Снять фиксацию"
	allow_interact_fallback = false
	timing = DEF_ProlongedInteraction.new()


## Проверяет возможность снять фиксацию с объекта source.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return AnchoringService.can_unfix(actor, source)


## Передаёт снятие фиксации сервису без собственного физического исполнения.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	AnchoringService.unfix(actor, source)


## Снимает фиксацию и возвращает результат для синхронного завершения длительного действия.
func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	return AnchoringService.unfix(actor, source)
