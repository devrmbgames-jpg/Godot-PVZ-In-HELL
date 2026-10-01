extends DEF_InteractionAction
class_name DEF_MeleeAction


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CombatService.can_strike(actor, source)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CombatService.start_strike(actor, source)
