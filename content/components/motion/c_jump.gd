extends Component
class_name C_Jump

## Upward impulse in N*s, applied once per accepted jump.
@export var jump_force: float = 8.0

## True during the physics tick in which a jump is accepted.
@export var active: bool = false

## Input history: holding the button must not cause repeated jumps.
var was_pressed: bool = false
