extends Resource
## Durable quest facts. Live issuer/parcel bindings belong to Relationships.
class_name RefusalQuestRecord

enum State { OFFERED, ACTIVE, COMPLETED, FAILED, IGNORED, EXPIRED }
@export var quest_id: StringName = &""
@export var issuer_key: StringName = &""
@export var package_id: String = ""
@export var visit_id: StringName = &""
@export var display_number: int = 0
@export var offered_day: int = 1
@export var deadline_day: int = 2
@export var state: State = State.OFFERED
@export var resolved_day: int = 0
@export var reward: int = 60
@export var reward_paid: bool = false
