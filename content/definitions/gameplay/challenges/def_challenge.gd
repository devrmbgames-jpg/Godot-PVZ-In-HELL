extends GameDefinition
class_name DEF_Challenge

enum Trigger { AFTER_DIALOGUE, ON_ARRIVAL }
enum Completion { ON_CONDITION, UNTIL_DEPARTURE, UNTIL_DEPARTURE_OR_FAILURE }

@export var trigger: Trigger = Trigger.AFTER_DIALOGUE
@export var completion: Completion = Completion.ON_CONDITION
@export var condition: DEF_ChallengeCondition = null
@export_multiline var rule_text: String = ""
@export_range(0.0, 600.0) var timeout_seconds: float = 20.0
@export_range(0.0, 30.0) var result_display_seconds: float = 3.0
@export var success_satisfaction_delta: int = 10
@export var failure_satisfaction_delta: int = -30
@export var escalation_on_failure: bool = true
@export_range(0.0, 120.0) var preparation_seconds: float = 0.0
@export_range(0.0, 30.0) var violation_grace_seconds: float = 1.0
@export var reset_violation_on_compliance: bool = true
