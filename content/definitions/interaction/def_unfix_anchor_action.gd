extends DEF_InteractionAction
## Target-authored prolonged F action for player-anchored physical objects.
class_name DEF_UnfixAnchorAction


func _init() -> void:
	action_id = &"unfix_anchor"
	slot = Slot.USE
	caption = "Снять фиксацию"
	allow_interact_fallback = false
	timing = DEF_ProlongedInteraction.new()


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return AnchoringService.can_unfix(actor, source)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	AnchoringService.unfix(actor, source)


func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	return AnchoringService.unfix(actor, source)
