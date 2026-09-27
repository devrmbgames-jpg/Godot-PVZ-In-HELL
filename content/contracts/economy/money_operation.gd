extends Resource
## Stable identity is supplied by the producer and must survive retries/save-load.
class_name MoneyOperation

enum Reason { PAYMENT, PURCHASE, VOLUNTARY_BUYOUT, LOST, PLAYER_REFUSAL, CONFIRMED_FRAUD }

@export var operation_id: StringName = &""
@export var reason: Reason = Reason.PAYMENT
@export var amount: int = 0
@export var day_index: int = 1
## Shipment/dispute outcome identity; required for package settlements.
@export var settlement_id: StringName = &""
