extends RefCounted
## Cheap authored light-volume exposure, independent of rendering and physical sight rays.
class_name NpcLightingService

static var _registered_zones: Array[NpcLightZone] = []
static var _zone_revision: int = 0

#region Scene registration
## Registers a static volume or a player-created moving light when it enters the scene.
static func register_zone(zone: NpcLightZone) -> void:
	if not _registered_zones.has(zone):
		_registered_zones.append(zone)
		_zone_revision += 1

## Removes transient bindings on exit, including scene replacement and carried lights.
static func unregister_zone(zone: NpcLightZone) -> void:
	_registered_zones.erase(zone)
	_zone_revision += 1

## Filters volume membership only when zones enter or leave, not on every sample/frame.
static func context_for(district: C_District) -> NpcLightingContext:
	if district.lighting_context != null and district.lighting_revision == _zone_revision:
		return district.lighting_context
	var context: NpcLightingContext = NpcLightingContext.new()
	var level: Node = ECS.world.get_parent()
	for zone: NpcLightZone in _registered_zones:
		if is_instance_valid(zone) and level.is_ancestor_of(zone):
			context.zones.append(zone)
	district.lighting_context = context
	district.lighting_revision = _zone_revision
	return context
#endregion

#region Illumination query
## Returns the strongest authored exposure; occlusion belongs to level markup and sight.
## The exclusion argument remains compatible with callers; held props do not mask light zones.
static func exposure_at(world_position: Vector3, _ignored_bodies: Array[RID] = [], context: NpcLightingContext = null) -> float:
	var district: C_District = DistrictPopulationService.current()
	if district == null or district.definition == null:
		return 1.0
	if context == null:
		context = context_for(district)
	var exposure: float = district.definition.ambient_light
	for zone: NpcLightZone in context.zones:
		if is_instance_valid(zone) and zone.contains_point(world_position) and zone.is_lit():
			exposure = maxf(exposure, zone.exposure)
	return clampf(exposure, 0.0, 1.0)
#endregion
