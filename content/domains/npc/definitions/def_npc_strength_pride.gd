@tool
extends DEF_NpcTrait
## Authored pride: respect demonstrated violence, hide toys and prefer private unpacking.
class_name DEF_NpcStrengthPride

## Minimum actually applied damage from a recognized actor that demonstrates strength, in HP.
@export_range(0.1, 1000.0) var respected_damage: float = 15.0
## Chance of opening a borrowed parcel in the existing private-inspection owner.
@export_range(0.0, 1.0) var private_unpack_probability: float = 1.0
## Solid collision layers that block the player's actual view of a physical toy.
@export_flags_3d_physics var toy_visibility_mask: int = 31


#region Authored capability validation
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	return (
		kind == Kind.CAPABILITY and is_finite(respected_damage) and respected_damage > 0.0
		and is_finite(private_unpack_probability) and private_unpack_probability >= 0.0
		and private_unpack_probability <= 1.0 and toy_visibility_mask > 0
	)
#endregion
