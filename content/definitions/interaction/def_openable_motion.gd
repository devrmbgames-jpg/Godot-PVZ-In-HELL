extends GameDefinition
## Authored local endpoints for a hinge or translating drawer. Physics owns application.
class_name DEF_OpenableMotion

@export var closed_transform: Transform3D = Transform3D.IDENTITY
@export var open_transform: Transform3D = Transform3D.IDENTITY
@export_range(0.01, 60.0, 0.01, "or_greater") var duration_seconds: float = 0.5
## Bounded joint servo response (per second), never a physical transform override.
@export_range(0.1, 60.0) var motor_response: float = 8.0
@export_range(0.01, 100.0) var hinge_motor_max_impulse: float = 2.0
@export_range(1.0, 10000.0) var slide_motor_force_limit: float = 120.0
