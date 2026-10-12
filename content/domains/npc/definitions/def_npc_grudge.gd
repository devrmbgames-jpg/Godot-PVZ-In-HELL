@tool
extends DEF_NpcTrait
## Authored lasting resentment; the existing durable NpcMemory array owns remembered incidents.
class_name DEF_NpcGrudge

## Added attack probability against a personally remembered offender; bounded and non-stacking.
@export_range(0.0, 1.0) var attack_probability_bonus: float = 0.2


#region Authored capability validation
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	return (
		kind == Kind.CAPABILITY and is_finite(attack_probability_bonus)
		and attack_probability_bonus >= 0.0 and attack_probability_bonus <= 1.0
	)
#endregion
