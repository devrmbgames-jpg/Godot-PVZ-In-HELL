extends Resource
## Data-only reaction of one Customer archetype to one player dialogue intent.
class_name DEF_CustomerDialogueReaction

@export var intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.Type.NONE
@export_range(-100, 100, 1) var satisfaction_delta: int = 0
@export_range(-1.0, 1.0, 0.05) var complaint_probability_delta: float = 0.0
@export_range(-1.0, 1.0, 0.05) var aggression_probability_delta: float = 0.0
@export_range(-1.0, 1.0, 0.05) var followup_probability_delta: float = 0.0
