extends RefCounted
## Common renderer interface; street and parcel contexts adapt their own domain services.
class_name NpcDialogueContext

#region Context interface
func _init(_actor: Entity = null, _interlocutor: Entity = null) -> void:
	pass

## Begins the concrete interaction after validation.
func begin() -> bool:
	return false

## Releases the concrete participants without owning modal input.
func end() -> void:
	pass

## Validates current participant and domain facts.
func is_valid() -> bool:
	return false

## Determines whether presentation may continue.
func can_continue() -> bool:
	return false

## Preserves authored text unless the concrete adapter changes player perception.
func perceived_text(actual_text: String) -> String:
	return actual_text

## Applies response meaning through the concrete gameplay adapter.
func apply_response_tags(_tags: PackedStringArray) -> bool:
	return false
#endregion
