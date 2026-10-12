extends RefCounted
## One explicit accept/decline intent tied to the durable offer displayed to the player.
class_name SoulTradeRequest

## Current player incarnation receiving the authoritative change.
var actor: Entity = null
## Current dealer incarnation; the offer verifies its stable identity.
var dealer: Entity = null
## Stable confirmation key obtained from the owning ledger, never a visible line ID.
var confirmation_key: StringName = &""
## True consents to the captured terms; false is an explicit decline.
var accept: bool = false
