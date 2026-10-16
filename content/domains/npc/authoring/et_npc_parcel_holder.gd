@tool
extends EntityTrait
## Authored NPC carry data; common grab owners retain live ownership and body integration.
class_name ET_NpcParcelHolder

## Initial carry Strength; ordinary movement/throw scaling reads the resulting C_Strength.
@export_range(0.0, 100.0, 0.1) var carry_strength: float = 6.0
## Carry offset ahead of the native HandoffAnchor, in metres.
@export_range(0.1, 2.0, 0.05) var carry_distance_m: float = 0.35


#region Native capability contract
func _init() -> void:
	trait_id = &"npc_parcel_holder"
	required_root_class = &"RigidBody3D"
	required_components = [C_Controller, C_Motion]
	required_nodes = [NodePath("HandoffAnchor")]


func configuration_issues(_context: EntitySpawnContext) -> PackedStringArray:
	if not is_finite(carry_strength) or carry_strength < 0.0:
		return PackedStringArray(["NPC carry Strength must be finite and nonnegative"])
	if not is_finite(carry_distance_m) or carry_distance_m <= 0.0:
		return PackedStringArray(["NPC carry distance must be finite and positive"])
	return PackedStringArray()


func recipes_for(_context: EntitySpawnContext) -> Array[Component]:
	var control: C_GrabControl = C_GrabControl.new()
	control.hold_distance = carry_distance_m
	return [control, C_CarryLoad.new(), C_Strength.new(carry_strength)]
#endregion
