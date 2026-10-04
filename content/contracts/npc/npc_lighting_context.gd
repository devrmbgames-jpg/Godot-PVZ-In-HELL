extends RefCounted
## Derived inputs shared by illumination samples; live lamp and circuit values remain authoritative.
class_name NpcLightingContext

## Places whose ambient values are consulted at evaluation time.
var places: Array[DEF_DistrictPlace] = []
## World positions resolved once for these authored places.
var positions: PackedVector3Array = PackedVector3Array()
## Light nodes paired with optional circuit state below.
var sources: Array[Light3D] = []
## Circuit bindings resolved once, with enabled state read on every sample.
var circuits: Array[C_LightCircuit] = []
