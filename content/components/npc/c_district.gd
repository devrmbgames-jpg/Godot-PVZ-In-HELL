extends Component
## District session owns persons, calendar commits and replacement records.
class_name C_District

## Immutable district configuration.
@export var definition: DEF_District = null
## Full living and historical population.
@export var people: Array[NpcRecord] = []
## Voluntary obligations including durable terminal results.
@export var home_deliveries: Array[NpcHomeDelivery] = []
## Derived lighting sources, rebuilt after scene creation; not saved.
var light_sources: Array[Light3D] = []
## Derived weak body lookup, validated against world membership; not a relationship.
var body_references: Dictionary[StringName, WeakRef] = {}
## Shared authored light inputs for the current physics frame; not saved.
var lighting_context: NpcLightingContext = null
## Physics frame in which authored light inputs were resolved.
var lighting_frame: int = -1
## World structural revision at which lamp/circuit bindings were captured.
var lighting_world_version: int = -1
## Audible events awaiting the next perception batch; not saved.
var noises: Array[NpcNoise] = []
## Transient stimulus sequence.
var next_noise_sequence: int = 1
## Transient monotonic aura request keys; live effects are rebuilt after loading.
var next_aura: int = 1
## Cached static graph edge paths, invalidated when the navigation map changes.
var route_edges: Dictionary[String, PackedVector3Array] = {}
## Navigation iteration for the edge cache.
var route_map_iteration: int = -1
## Fair route queue containing stable IDs only; cancelled entries are skipped.
var pending_routes: Array[StringName] = []
## Physics frame in which the planning allowance was last reset.
var route_planning_frame: int = -1
## Plans executed within this physics frame.
var route_plans_this_frame: int = 0
## Derived player footstep cadence; not saved.
var player_step_elapsed: float = 0.0
## Monotonic service appearance ordering, independent of archetype query order.
@export var next_service_order: int = 1
## Monotonic lifetime sequence for newly settled persons.
@export var next_person: int = 1
## Monotonic identity of committed social incidents.
@export var next_incident: int = 1
## Last committed morning prevents duplicate resettlement on save retries.
@export var prepared_morning: int = 0
## Earliest local resettlement morning; zero means no active wave.
@export var replacement_morning: int = 0
## Calendar key for ambient conflict budget.
@export var conflict_phase: StringName = &""
## Self-initiated conflicts already used in that phase.
@export var ambient_conflicts: int = 0
