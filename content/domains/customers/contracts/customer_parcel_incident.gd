extends Resource
## Committed wrong-parcel choice; durable IDs/deadlines never retain an Entity or a live grip.
class_name CustomerParcelIncident

const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")

enum Phase {
	COMPLETED,
	HELD,
}

const SAVE_FIELDS: Array[String] = [
	"sequence",
	"npc_id",
	"package_id",
	"visit_id",
	"outcome",
	"created_tick",
	"next_eligible_tick",
	"phase",
	"demand_outcome",
	"demand_strength",
	"demand_roll",
	"demand_tick",
]

## Monotonic session decision identity; never reused after pruning an expired pair.
@export var sequence: int = 0
## Stable receiver identity, independent of appearance and brain/role incarnation.
@export var npc_id: StringName = &""
## Actual wrong parcel identity; legal assignment remains unchanged.
@export var package_id: String = ""
## Service contact that committed the reaction; not a live role reference.
@export var visit_id: StringName = &""
## Once-selected CustomerParcelReactionRules.Outcome, never rerolled during this incident.
@export var outcome: REACTIONS.Outcome = REACTIONS.Outcome.REFUSE
## Active gameplay microseconds at recognition.
@export var created_tick: int = 0
## Active gameplay deadline; release/return of a stolen parcel starts a fresh 180-second block.
@export var next_eligible_tick: int = 0
## HELD denotes actual NPC ownership requiring physical reconstruction after load.
@export var phase: Phase = Phase.COMPLETED
## Once-selected intimidation result; RETURN may still await a safe physical destination.
@export var demand_outcome: REACTIONS.DemandOutcome = REACTIONS.DemandOutcome.NONE
## Effective player Strength captured at demand acceptance; never resampled during this incident.
@export var demand_strength: float = 0.0
## Single captured native roll in [0, 1]; zero is also the canonical unattempted value.
@export var demand_roll: float = 0.0
## Active gameplay microseconds at demand acceptance; -1 means no demand was committed.
@export var demand_tick: int = -1
