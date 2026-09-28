extends RefCounted
## Ephemeral query result, never stored as authoritative ownership or authorization.
class_name AccessResult

enum Outcome { ALLOWED, ACTOR_UNAVAILABLE, ITEM_REQUIRED, CONSUMPTION_UNAVAILABLE, INVALID_REQUIREMENT }

var outcome: Outcome = Outcome.ITEM_REQUIRED
var item: Entity = null
var provider: DEF_ItemAccessProvider = null


func is_allowed() -> bool:
	return outcome == Outcome.ALLOWED
