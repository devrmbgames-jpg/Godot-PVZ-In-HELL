extends GameDefinition
## Copy/override this resource per NPC archetype; scenes must be physical inventory pickups.
class_name DEF_NpcRemains

const MAX_MEAT_PIECES: int = 12

@export var meat_scene: PackedScene = null
@export_range(1, MAX_MEAT_PIECES, 1) var meat_piece_count: int = 3
@export_range(0.2, 2.0, 0.05) var piece_spacing: float = 0.45
@export var loot_scene: PackedScene = null
@export_range(0.0, 1.0, 0.01) var loot_chance: float = 0.25
