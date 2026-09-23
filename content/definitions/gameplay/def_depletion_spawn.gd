extends Resource
## Authored post-depletion gameplay spawn; contains no runtime ownership.
class_name DEF_DepletionSpawn

## Scene spawned under the World, with a target-local offset.
@export var scene: PackedScene = null
@export var offset: Transform3D = Transform3D.IDENTITY
