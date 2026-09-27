extends Resource
## Authored post-depletion gameplay spawn; contains no runtime ownership.
class_name DEF_DepletionSpawn

## Stable semantic key for downstream domain reactions (for example &"debris").
@export var key: StringName = &""
## Scene spawned under the World, with a target-local offset.
@export var scene: PackedScene = null
@export var offset: Transform3D = Transform3D.IDENTITY
