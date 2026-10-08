extends DEF_InteractionAction
## Открывает терминал склада через контекстное взаимодействие.
class_name DEF_TerminalAction


## Разрешает открытие терминала при существующем цикле вне ночи.
func is_available(_actor: Entity, source: Entity, _target: Entity) -> bool:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	return source is E_Terminal and cycle != null and cycle.phase != C_DayCycle.Phase.NIGHT


## Открывает терминал для действующего участника.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	var terminal: E_Terminal = source as E_Terminal
	if terminal != null:
		terminal.open_for(actor)
