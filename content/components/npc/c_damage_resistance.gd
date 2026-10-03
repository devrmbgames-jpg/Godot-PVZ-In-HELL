extends Component
## Typed damage multipliers; zero is a real immunity shared by damage and route evaluation.
class_name C_DamageResistance

## Unspecified types use one; authored multipliers must be finite and nonnegative.
@export var multipliers: Dictionary[int, float] = {}
