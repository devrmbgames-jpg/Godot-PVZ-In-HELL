extends RefCounted
## Directional impact evaluation before submitting the ordinary HP request.
class_name ImpactResult

const EVENT: StringName = &"physical_impact"
enum Severity {
	None,
	Weak,
	Medium,
	Strong,
}

## Source is the actual damaging Entity; null means physical environment.
var source: Entity = null
var target: Entity = null
var severity: Severity = Severity.None
var amount: float = 0.0
var transferred_energy: float = 0.0

## True when receiver protection suppressed the physical impact before HP submission.
var protected: bool = false

## Physical thresholds passed, even if receiver absorption reduces base HP damage to zero.
var qualifies: bool = false
