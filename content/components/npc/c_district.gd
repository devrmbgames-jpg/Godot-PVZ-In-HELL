extends Component
## District session owns persons, calendar commits and replacement records.
class_name C_District

## Immutable district configuration.
@export var definition: DEF_District = null
## Full living and historical population.
@export var people: Array[NpcRecord] = []
## Monotonic lifetime sequence for newly settled persons.
@export var next_person: int = 1
## Last committed morning prevents duplicate resettlement on save retries.
@export var prepared_morning: int = 0
## Earliest local resettlement morning; zero means no active wave.
@export var replacement_morning: int = 0
## Calendar key for ambient conflict budget.
@export var conflict_phase: StringName = &""
## Self-initiated conflicts already used in that phase.
@export var ambient_conflicts: int = 0
