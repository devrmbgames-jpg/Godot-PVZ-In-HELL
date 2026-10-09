extends RefCounted
## Дешёвая оценка авторских зон света, независимая от рендера и лучей зрения.
class_name NpcLightingService

static var _observed_tree: SceneTree = null
static var _zone_revision: int = 0

#region Регистрация в сцене
static func _observe_tree(scene_tree: SceneTree) -> void:
	if _observed_tree == scene_tree:
		return

	# Native membership owns the zone list. These callbacks only invalidate a derived snapshot.
	if is_instance_valid(_observed_tree):
		_observed_tree.node_added.disconnect(_on_zone_lifecycle)
		_observed_tree.node_removed.disconnect(_on_zone_lifecycle)
	_observed_tree = scene_tree
	_observed_tree.node_added.connect(_on_zone_lifecycle)
	_observed_tree.node_removed.connect(_on_zone_lifecycle)
	_zone_revision += 1


static func _on_zone_lifecycle(subject: Node) -> void:
	if subject is NpcLightZone:
		_zone_revision += 1


## Обновляет состав зон только при входе или выходе зоны, а не при каждом измерении.
static func context_for(district: C_District) -> NpcLightingContext:
	_observe_tree(ECS.world.get_tree())
	if district.lighting_context != null and district.lighting_revision == _zone_revision:
		return district.lighting_context

	var context: NpcLightingContext = NpcLightingContext.new()
	var level: Node = ECS.world.get_parent()
	for subject: Node in _observed_tree.get_nodes_in_group(NpcLightZone.ZONE_GROUP):
		var zone: NpcLightZone = subject as NpcLightZone
		if level.is_ancestor_of(zone):
			context.zones.append(zone)
	district.lighting_context = context
	district.lighting_revision = _zone_revision
	return context
#endregion

#region Оценка освещённости
## Возвращает максимальную авторскую освещённость; перекрытие задаётся зонами и зрением.
## Аргумент исключений сохраняет совместимость; предметы в руках не перекрывают зоны света.
static func exposure_at(world_position: Vector3, _ignored_bodies: Array[RID] = [], context: NpcLightingContext = null, ignore_flicker: bool = false) -> float:
	var district: C_District = NpcPopulationQueries.current()
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
