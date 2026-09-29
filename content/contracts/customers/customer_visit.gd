extends Resource
## Persistent facts: no live Entity references. Live assignment uses R_AssignedTo.
class_name CustomerVisit

enum Actual { NOT_RESOLVED, DELIVERED, CUSTOMER_REFUSED, PLAYER_DENIED }
enum Declaration { NONE, TAKEN, REFUSED, LOST }
enum LossCause { NONE, DECLARED_LOST, MISSED_REGISTRATION }
enum Disposition { WAREHOUSE, DELIVERED, RETURNED, BOUGHT_OUT, LOST }
enum Reputation {
	NONE,
	PLAYER_DENIAL,
	LOST,
	CONFIRMED_REFUSAL,
	FRAUD,
	FALSE_COMPLAINT,
	DAMAGED_COMPLAINT,
}
enum Feedback { NONE, APPROVED }

@export var visit_id: StringName = &""
@export var customer_id: StringName = &""
@export var package_id: String = ""
## Hidden warehouse history identity; never shown as the customer order number.
@export var package_history_id: String = ""
## Default package-pickup visits wait for a registration record before spawning.
@export var requires_registered_package: bool = true
@export var arrival_day: int = 1
@export var definition: DEF_Customer = null
@export var accounting_value: int = 0
@export var payment: int = 0
@export var actual: Actual = Actual.NOT_RESOLVED
@export var declaration: Declaration = Declaration.NONE
## Why a LOST declaration exists. Keeps honest LOST distinct from ignored registration.
@export var loss_cause: LossCause = LossCause.NONE
@export var disposition: Disposition = Disposition.WAREHOUSE
@export var reputation: Reputation = Reputation.NONE
@export var satisfaction: int = 0
@export var dialogue_satisfaction_delta: int = 0
@export var last_dialogue_intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.Type.NONE
@export var applied_dialogue_intents: int = 0
@export var complaint_probability_delta: float = 0.0
@export var aggression_probability_delta: float = 0.0
@export var followup_probability_delta: float = 0.0
@export var riddle_wrong_answer_applied: bool = false
@export var riddle_solved: bool = false
@export var feedback: Feedback = Feedback.NONE
## Persistent delivery facts used by delayed complaint adjudication.
@export var package_damaged: bool = false
@export var package_opened: bool = false
@export var started: bool = false
@export var finished: bool = false
@export var finished_day: int = 0
@export var visit_count: int = 0
@export var followup_count: int = 0
@export var next_followup_day: int = 0
@export var last_visit_day: int = 0
@export var player_denial_count: int = 0
@export var customer_dead: bool = false
@export var defeated_by_player: bool = false
@export var settlement_committed: bool = false
@export var settlement_day: int = 0
@export var money_delta: int = 0
@export var complaint_roll: float = 1.0
@export var aggression_roll: float = 1.0
@export var aggressive: bool = false
@export var complaint: CustomerComplaint = null
