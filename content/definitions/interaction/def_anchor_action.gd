extends DEF_InteractionAction
## PRIMARY-действие молотка: удерживаемый инструмент — источник, фиксация применяется к цели луча.
class_name DEF_AnchorAction


func _init() -> void:
	action_id = &"anchor"
	slot = Slot.PRIMARY
	caption = "Зафиксировать"


## Проверяет молоток source и цель луча через AnchoringService.
func is_available(actor: Entity, source: Entity, target: Entity) -> bool:
	return AnchoringService.can_anchor(actor, source, target)


## Передаёт команду фиксации в complete с повторной проверкой.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	complete(actor, source, target)


## Фиксирует цель; только при успехе проигрывает действие инструмента и возвращает true.
func complete(actor: Entity, source: Entity, target: Entity) -> bool:
	var anchored: bool = AnchoringService.anchor(actor, source, target)
	if anchored:
		MeleeWeaponPresentation.play_tool_action(source)
	return anchored
