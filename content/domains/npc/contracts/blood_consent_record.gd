extends Resource
## Durable blood offer and terminal receipt; personal district identity owns its lifetime.
class_name BloodConsentRecord

## Exact record schema; incomplete receipts reject before live restoration.
const SAVE_FIELDS: Array[String] = [
	"confirmation_key",
	"actor_id",
	"dealer_id",
	"percent",
	"cooldown_ticks",
	"outcome",
	"next_offer_tick",
	"previous_health",
	"applied_amount",
]

enum Outcome {
	OFFERED,
	ACCEPTED,
	DECLINED,
}

## Never-reused key allocated by this person's durable offer sequence.
@export var confirmation_key: StringName = &""
## Stable identity of the consenting player; live references are never saved.
@export var actor_id: String = ""
## Stable district identity of the offering person.
@export var dealer_id: StringName = &""
## Captured percentage of current HP at acceptance, within the authored 5..40 range.
@export var percent: int = 5
## Captured simulation cooldown in microsecond ticks.
@export var cooldown_ticks: int = 0
## Terminal receipts never repeat Health changes, including after save/load.
@export var outcome: Outcome = Outcome.OFFERED
## Simulation deadline for another resolved offer from this dealer.
@export var next_offer_tick: int = 0
## Authoritative current HP immediately before an accepted operation; zero for other outcomes.
@export var previous_health: float = 0.0
## Actual common Health reduction committed by acceptance; zero for refusal or pending offers.
@export var applied_amount: float = 0.0
