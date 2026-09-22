extends RefCounted
class_name DamageResult

enum Outcome {
	REJECTED,
	APPLIED,
	DEFEATED,
	PACKAGE_DAMAGED,
	PACKAGE_DESTROYED,
}

var request: DamageRequest = null
var outcome: Outcome = Outcome.REJECTED
var previous_value: float = 0.0
var current_value: float = 0.0
var applied_amount: float = 0.0
