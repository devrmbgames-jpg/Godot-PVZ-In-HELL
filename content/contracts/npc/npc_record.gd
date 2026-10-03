extends Resource
## Permanent person and phase history; active health and items remain on the body.
class_name NpcRecord

enum Placement { STREET, HOME, OUTSIDE, DEAD }

## Lifetime identity independent of visits and dates.
@export var npc_id: StringName = &""
## Immutable profile reference.
@export var profile: DEF_NpcProfile = null
## Stable home address; empty for outsiders.
@export var home_id: StringName = &""
## Current logical placement.
@export var placement: Placement = Placement.HOME
## Assigned entry and exit portal.
@export var portal_id: StringName = &""
## Phase goal place.
@export var goal_id: StringName = &""
## Last committed schedule day.
@export var planned_day: int = 0
## Last committed phase.
@export var planned_phase: int = -1
## Whether the mandatory phase task has completed.
@export var phase_complete: bool = false
## Remembered recognized social incidents.
@export var memories: Array[NpcMemory] = []
## Day of terminal death; zero while alive.
@export var death_day: int = 0
## Deterministic activity sequence prevents reroll on reload.
@export var activity_sequence: int = 0
