@tool
extends GameDefinition
## Immutable supernatural effect tuning; receiver capabilities decide damage or healing.
class_name DEF_ReceiverEffect

enum Alignment {
	HOLY,
	UNHOLY,
}

## Selects the semantic receiver rule and DamageRequest type.
@export var alignment: Alignment = Alignment.HOLY
## Positive finite health units per interval before damage resistance; healing is capped by Health.
@export_range(0.01, 1000.0) var amount_per_tick: float = 8.0
## Positive finite interval in GamePlay seconds; physical Area3D owns the authored volume.
@export_range(0.05, 60.0) var tick_seconds: float = 1.0
