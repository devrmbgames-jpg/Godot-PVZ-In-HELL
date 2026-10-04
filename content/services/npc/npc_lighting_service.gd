extends RefCounted
## Дешёвая оценка авторских зон света, независимая от рендера и лучей зрения.
class_name NpcLightingService

static var _registered_zones: Array[NpcLightZone] = []
static var _zone_revision: int = 0

#region Регистрация в сцене
## Регистрирует неподвижную зону или подвижный свет игрока при входе в сцену.
static func register_zone(zone: NpcLightZone) -> void:
	if not _registered_zones.has(zone):
		_registered_zones.append(zone)
		_zone_revision += 1

## Удаляет временные связи при выходе, включая замену сцены и переносной свет.
static func unregister_zone(zone: NpcLightZone) -> void:
	_registered_zones.erase(zone)
	_zone_revision += 1

## Обновляет состав зон только при входе или выходе зоны, а не при каждом измерении.
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

#region Оценка освещённости
## Возвращает максимальную авторскую освещённость; перекрытие задаётся зонами и зрением.
## Аргумент исключений сохраняет совместимость; предметы в руках не перекрывают зоны света.
static func exposure_at(world_position: Vector3, _ignored_bodies: Array[RID] = [], context: NpcLightingContext = null, ignore_flicker: bool = false) -> float:
	var district: C_District = DistrictPopulationService.current()
	if district == null or district.definition == null:
		return 1.0
	if context == null:
		context = context_for(district)
	var exposure: float = district.definition.ambient_light
	for zone: NpcLightZone in context.zones:
		if is_instance_valid(zone) and zone.contains_point(world_position) and (zone.is_logically_lit() if ignore_flicker else zone.is_lit()):
			exposure = maxf(exposure, zone.exposure)
	return clampf(exposure, 0.0, 1.0)
#endregion
