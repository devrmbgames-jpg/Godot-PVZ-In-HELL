@tool
extends DEF_Hazard
## Non-damaging blood stimulus; lifetime and spatial reach are authored independently of toxins.
class_name DEF_BloodArea

## Positive finite world radius in metres; bounds the perceived stimulus and native zone.
@export_range(0.1, 30.0) var radius: float = 3.0
## Other authored unclean receivers may react aggressively when perceiving this zone.
@export var provokes_unclean: bool = true
