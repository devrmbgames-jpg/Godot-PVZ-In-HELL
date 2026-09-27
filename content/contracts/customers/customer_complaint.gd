extends Resource
class_name CustomerComplaint

enum Reason { NOT_DELIVERED, DAMAGED }
enum Outcome { PENDING, CONFIRMED, FALSE_CLAIM, WAIVED_PLAYER_DEFEAT, ALREADY_SETTLED, NO_LIVING_CLAIMANT }

@export var complaint_id: StringName = &""
@export var reason: Reason = Reason.NOT_DELIVERED
@export var created_day: int = 0
@export var resolve_day: int = 0
@export var outcome: Outcome = Outcome.PENDING
@export var resolved_day: int = 0
## Inclusive first day, exclusive end: exactly seven game days by default.
@export var retaliation_start_day: int = 0
@export var retaliation_end_day: int = 0
@export var money_delta: int = 0
