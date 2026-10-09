extends RefCounted
## Immutable queued view of input values; never registered as a second runtime controller.
class_name InteractionInputSnapshot

const FIELDS: Array[StringName] = [
	&"input_tick", &"interact_pressed", &"interact_held", &"use_pressed", &"use_held",
	&"cancel_pressed", &"drop_pressed", &"drop_long_pressed", &"action_main_pressed", &"action_main",
	&"action_second_pressed", &"action_second_held", &"action_second", &"physical_override",
	&"rotate_held", &"look_delta", &"move_axis",
]

#region Immutable input capture
## Copies the closed input surface, including non-exported fields that Resource.duplicate omits.
static func capture(controller: C_Controller) -> C_Controller:
	var snapshot: C_Controller = C_Controller.new()
	for field: StringName in FIELDS:
		snapshot.set(field, controller.get(field))
	return snapshot
#endregion
