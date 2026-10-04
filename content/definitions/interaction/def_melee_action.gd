extends DEF_InteractionAction
## Запрашивает начало удара; попадание и урон выполняет боевой контур.
class_name DEF_MeleeAction


## Проверяет возможность удара этим оружием.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CombatService.can_strike(actor, source)


## Начинает удар без прямого изменения здоровья цели.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CombatService.start_strike(actor, source)
