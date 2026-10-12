@tool
extends Resource
## Authored night-presence audio and shadow blending; no sensing or gameplay rules.
class_name DEF_NpcNightPresentation

## Seconds for one native visual/audio transition.
@export_range(0.05, 2.0) var fade_seconds: float = 0.4
## Spatial music audibility radius in metres.
@export_range(1.0, 30.0) var music_distance: float = 8.0
## Quiet presence level in decibels.
@export_range(-60.0, 0.0) var presence_volume_db: float = -26.0
## Committed combat warning level in decibels.
@export_range(-60.0, 0.0) var hunting_volume_db: float = -18.0
## Projected shadow opacity during ordinary presence.
@export_range(0.0, 1.0) var presence_shadow_opacity: float = 0.25
## Projected shadow opacity during committed combat.
@export_range(0.0, 1.0) var hunting_shadow_opacity: float = 0.6
