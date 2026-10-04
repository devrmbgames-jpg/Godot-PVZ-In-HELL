extends RefCounted
## Scene-local authored light zones; switch and volume state remain live.
class_name NpcLightingContext

## Zones belonging to the current world's level, excluding other loaded scenes.
var zones: Array[NpcLightZone] = []
