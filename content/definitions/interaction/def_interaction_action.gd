extends GameDefinition
## Stateless authored availability and execution contract for contextual actions.
class_name DEF_InteractionAction

enum Slot {
	INTERACT,
	USE,
	PRIMARY,
	SECONDARY,
}

@export var action_id: StringName = &""
@export var slot: Slot = Slot.USE
@export var caption: String = "Использовать"
@export var priority: int = 0
@export var continuous: bool = false
@export var timing: DEF_ProlongedInteraction = null


## Implementations are stateless handlers. Mutable state belongs in Components.
func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return false


func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	pass


## Override when an effect can fail after availability validation.
func complete(actor: Entity, source: Entity, target: Entity) -> bool:
	if not is_available(actor, source, target):
		return false
	execute(actor, source, target)
	return true
