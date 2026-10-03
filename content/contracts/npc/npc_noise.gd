extends RefCounted
## Short-lived audible event; position is audible but source identity must be recognized.
class_name NpcNoise

## Monotonic batch sequence for once-only hearing.
var sequence: int = 0
## Lifetime covering the complete staggered perception interval.
var remaining: float = 0.5
## Actual stimulus position at emission.
var position: Vector3 = Vector3.ZERO
## Audible radius before obstacle attenuation.
var radius: float = 8.0
## Optional live source, used only for an immediate perception check.
var source: Entity = null
