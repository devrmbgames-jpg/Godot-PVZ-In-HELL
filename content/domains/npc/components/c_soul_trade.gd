@tool
extends Component
## Player-owned soul ledger; SoulTradeService is its sole gameplay writer.
class_name C_SoulTrade

## Closed durable component schema.
const SAVE_FIELDS: Array[String] = ["next_sequence", "accepted_count", "offers"]

## Next never-reused confirmation sequence for this player.
@export var next_sequence: int = 1
## Total accepted offers before death; decline and session closure never reset this count.
@export var accepted_count: int = 0
## Durable offers and terminal receipts, including unresolved offers across session closure.
@export var offers: Array[SoulTradeRecord] = []
