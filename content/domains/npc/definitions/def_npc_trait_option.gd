@tool
extends Resource
## One authored weighted candidate; selection commits a key, never this pool's mutable state.
class_name DEF_NpcTraitOption

## Reusable behavior definition offered by the archetype.
@export var rule: DEF_NpcTrait = null
## Relative finite positive weight among currently compatible candidates.
@export_range(0.01, 1000.0, 0.01) var weight: float = 1.0
