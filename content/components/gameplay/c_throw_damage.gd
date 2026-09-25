extends Component
## Optional authored bonus for a deliberate throw.
class_name C_ThrowDamage

@export_range(0.0, 10000.0) var throw_damage: float = 10.0
@export_range(0.0, 30.0) var window_seconds: float = 3.0
## Active attribution/lifetime is represented only by R_ThrownBy.
