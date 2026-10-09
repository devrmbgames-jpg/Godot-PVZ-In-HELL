@tool
extends GameDefinition
## Flat scene-owned capability configuration; it has no inheritance or default-scene back-reference.
class_name DEF_EntityTemplate

## Reusable capability configuration; order never resolves conflicts or selects a last writer.
@export var traits: Array[EntityTrait] = []
