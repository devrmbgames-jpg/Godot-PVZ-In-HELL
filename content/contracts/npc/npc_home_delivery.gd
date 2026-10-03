extends Resource
## One voluntary real-box obligation; statuses and bonus commit survive save retries.
class_name NpcHomeDelivery

enum Status { ACCEPTED, DELIVERED, REFUSED, FAILED }

## Stable identity also used for the bonus money operation.
@export var job_id: StringName = &""
## Permanent recipient, independent of replacement at the address.
@export var npc_id: StringName = &""
## The ordinary parcel case owns all receipt and accounting facts.
@export var visit_id: StringName = &""
## Destination fixed when the player promises delivery.
@export var address_id: StringName = &""
## Registration number remembered for the job list after successful parcel departure.
@export var order_number: int = 0
## Deadline is sleep on this day, without a seconds timer.
@export var day_index: int = 1
## Durable completion or failure.
@export var status: Status = Status.ACCEPTED
## Whether the one base-payment bonus was committed.
@export var bonus_committed: bool = false
