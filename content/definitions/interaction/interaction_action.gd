extends Resource
class_name InteractionAction

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


## Implementations are stateless handlers. Mutable state belongs in Components.
func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return false


func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	pass
