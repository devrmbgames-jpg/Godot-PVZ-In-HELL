@tool
extends Resource
## Immutable eligibility and executor recipe shared by input, AI, quests and dialogue callers.
class_name DEF_SmartAffordance

## Stable operation key within its definition.
@export var affordance_id: StringName = &""
## Exclusive service slot declared by the same definition.
@export var slot_id: StringName = &""
## Existing domain action; availability is pure and complete returns the actual effect result.
@export var executor: DEF_InteractionAction = null
## Required actor capabilities, checked again when the owning operation commits.
@export var required_actor_components: Array[Script] = []
