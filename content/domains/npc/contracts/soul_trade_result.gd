extends RefCounted
## Committed soul outcome; replay returns its receipt without repeating gameplay effects.
class_name SoulTradeResult

const EVENT: StringName = &"soul_trade_resolved"

## Confirmation identity, including on rejection.
var confirmation_key: StringName = &""
## Durable terminal receipt when accepted or declined; null on rejection.
var receipt: SoulTradeRecord = null
## Rejection reason or committed outcome name.
var reason: StringName = &"invalid_request"
## True when an existing terminal receipt was returned.
var replayed: bool = false
