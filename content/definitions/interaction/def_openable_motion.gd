extends GameDefinition
## Authored local endpoints for a hinge or translating drawer. Physics owns application.
class_name DEF_OpenableMotion

@export var closed_transform: Transform3D = Transform3D.IDENTITY
@export var open_transform: Transform3D = Transform3D.IDENTITY
@export_range(0.01, 60.0, 0.01, "or_greater") var duration_seconds: float = 0.5
