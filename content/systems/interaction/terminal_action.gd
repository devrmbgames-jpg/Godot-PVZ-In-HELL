extends InteractionAction
class_name TerminalAction


func is_available(_actor: Entity, source: Entity, _target: Entity) -> bool:
	var cycle: C_DayCycle = S_DayPhase.current()
	return source is E_Terminal and cycle != null and cycle.phase != C_DayCycle.Phase.NIGHT


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	var terminal: E_Terminal = source as E_Terminal
	if terminal != null:
		terminal.panel.open_for(actor)
