extends Resource
## One durable offer and its terminal receipt; it never stores live Entity references.
class_name SoulTradeRecord

## Closed receipt schema; missing fields reject without reconstructing confirmation history.
const SAVE_FIELDS: Array[String] = [
	"confirmation_key",
	"actor_id",
	"dealer_id",
	"strength_gain",
	"maximum_health_cost",
	"fatal_deal_count",
	"cooldown_ticks",
	"outcome",
	"next_offer_tick",
	"accepted_count",
	"fatal",
]

enum Outcome {
	OFFERED,
	ACCEPTED,
	DECLINED,
}

## Stable confirmation identity allocated once by the player's ledger.
@export var confirmation_key: StringName = &""
## Stable identity of the consenting player.
@export var actor_id: String = ""
## Stable identity of the offering NPC.
@export var dealer_id: StringName = &""
## Terms captured when the offer was issued, independent of later authored tuning.
@export var strength_gain: float = 1.0
## Captured maximum-Health reduction, in HP.
@export var maximum_health_cost: float = 10.0
## Captured total accepted-deal threshold for terminal forfeiture.
@export var fatal_deal_count: int = 3
## Captured simulation deadline interval, in microsecond ticks.
@export var cooldown_ticks: int = 0
## Authoritative result; terminal receipts cannot be applied again.
@export var outcome: Outcome = Outcome.OFFERED
## Simulation deadline for another offer from this dealer after resolution.
@export var next_offer_tick: int = 0
## Total accepted-deal count after resolution, retained as receipt history.
@export var accepted_count: int = 0
## Terminal receipt records whether this deal forfeited all remaining Health.
@export var fatal: bool = false
