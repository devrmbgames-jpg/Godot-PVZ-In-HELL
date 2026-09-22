@tool
extends Entity
class_name E_Terminal

@onready var panel: TerminalPanel = $TerminalPanel


func define_components() -> Array:
	var actions: C_InteractionActions = C_InteractionActions.new()
	var use_terminal: TerminalAction = TerminalAction.new()
	use_terminal.slot = InteractionAction.Slot.USE
	use_terminal.action_id = &"open_terminal"
	use_terminal.caption = "Открыть реестр"
	actions.actions = [use_terminal]
	return [C_Interactable.new(), actions]
