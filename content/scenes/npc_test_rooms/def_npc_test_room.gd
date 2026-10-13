@tool
extends Resource
## Immutable authored isolated-room preset; live state remains in native session Components.
class_name DEF_NpcTestRoom

## Canonical test-room key from GameSessionService's bounded destination catalog.
@export var room_key: StringName = &""
## Player-facing archetype name on the room and portal signs.
@export var display_name: String = ""
## Isolated population, places and original archetype capability definitions.
@export var district: DEF_District = null
## Native two-parcel-per-day supply and the corresponding service cases.
@export var schedule: DEF_CustomerSchedule = null
