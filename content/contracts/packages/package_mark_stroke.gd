extends RefCounted
## One continuous ink stroke on one package face, entirely in package-local space.
class_name PackageMarkStroke

## Samples and outward face normal; no world-space position is persisted.
var points: PackedVector3Array = PackedVector3Array()
var normal: Vector3 = Vector3.UP
## Ink style copied from the marker when this stroke starts.
var width: float = 0.012
var color: Color = Color.BLACK
