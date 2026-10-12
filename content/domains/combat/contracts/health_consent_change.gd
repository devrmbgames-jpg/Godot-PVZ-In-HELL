extends RefCounted
## Voluntary current-HP percentage; caller owns captured terms, confirmation and idempotency.
class_name HealthConsentChange

## Live receiver established by the synchronous caller.
var target: Entity = null
## Fraction of actual current HP at acceptance; strictly between zero and one.
var fraction: float = 0.0
## Stable consenting effect origin for ordinary Health result attribution.
var origin_id: String = ""
## Caller-owned stable confirmation identity.
var confirmation_key: StringName = &""
