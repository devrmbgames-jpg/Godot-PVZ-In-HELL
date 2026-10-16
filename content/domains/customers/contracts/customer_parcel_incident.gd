extends Resource
## Committed wrong-parcel choice; durable IDs/deadlines never retain an Entity or a live grip.
class_name CustomerParcelIncident

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
@export var outcome: CustomerParcelReactionRules.Outcome = CustomerParcelReactionRules \
		.Outcome \
		.REFUSE
## Active gameplay microseconds at recognition.
@export var created_tick: int = 0
## Active gameplay deadline; release/return of a stolen parcel starts a fresh 180-second block.
@export var next_eligible_tick: int = 0
## HELD denotes actual NPC ownership requiring physical reconstruction after load.
@export var phase: Phase = Phase.COMPLETED
