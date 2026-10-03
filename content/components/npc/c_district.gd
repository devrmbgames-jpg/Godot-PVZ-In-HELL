extends Component
## District session owns persons, calendar commits and replacement records.
class_name C_District

## Immutable district configuration.
@export var definition: DEF_District = null
## Full living and historical population.
@export var people: Array[NpcRecord] = []
## Derived lighting sources, rebuilt after scene creation; not saved.
var light_sources: Array[Light3D] = []
## Audible events awaiting the next perception batch; not saved.
var noises: Array[NpcNoise] = []
## Transient stimulus sequence.
var next_noise_sequence: int = 1
## Derived player footstep cadence; not saved.
var player_step_elapsed: float = 0.0
## Monotonic service appearance ordering, independent of archetype query order.
@export var next_service_order: int = 1
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
