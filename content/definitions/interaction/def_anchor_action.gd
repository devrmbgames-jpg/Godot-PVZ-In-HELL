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
	AnchoringService.anchor(actor, source, target)


func complete(actor: Entity, source: Entity, target: Entity) -> bool:
	return AnchoringService.anchor(actor, source, target)
