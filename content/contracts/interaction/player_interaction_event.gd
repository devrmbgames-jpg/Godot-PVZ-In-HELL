extends RefCounted
## Committed player transitions, dispatched against the affected object.
class_name PlayerInteractionEvent

const EVENT: StringName = &"player_interaction"

enum Kind { TERMINAL_OPENED, TERMINAL_CLOSED, PARCEL_PICKED, PARCEL_PLACED, DOOR_OPENED, DOOR_CLOSED }

var kind: Kind = Kind.TERMINAL_OPENED
var actor: Entity = null
var object: Entity = null
var actor_id: String = ""
var object_id: String = ""
var package_id: String = ""

