extends DEF_InteractionAction
## Hammer PRIMARY action; the held tool remains the source and the ray target is anchored.
class_name DEF_AnchorAction


func _init() -> void:
	action_id = &"anchor"
	slot = Slot.PRIMARY
	caption = "Зафиксировать"


func is_available(actor: Entity, source: Entity, target: Entity) -> bool:
	return AnchoringService.can_anchor(actor, source, target)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	complete(actor, source, target)


func complete(actor: Entity, source: Entity, target: Entity) -> bool:
	var anchored: bool = AnchoringService.anchor(actor, source, target)
	if anchored:
		MeleeWeaponPresentation.play_tool_action(source)
	return anchored
