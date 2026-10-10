extends GutTest
## Проверки покрытия ПВЗ и связности native navmesh; неполный путь между островами не считается
## успехом.

const CHECKS: GDScript = preload("res://utils/warehouse_navigation_checks.gd")

var _level: Node3D = null
var _region: NavigationRegion3D = null
var _station: E_DeliveryCounter = null


#region Подготовка и очистка
## Создаёт минимальную стойку и регион без запуска районной симуляции.
func before_each() -> void:
	_level = Node3D.new()
	add_child(_level)
	var entities: Node3D = Node3D.new()
	entities.name = "Entityes"
	_level.add_child(entities)
	var counter_body: StaticBody3D = StaticBody3D.new()
	counter_body.set_script(load("res://content/domains/customers/entities/e_delivery_counter.gd"))
	_station = counter_body as Node as E_DeliveryCounter
	_station.name = "DeliveryCounter"
	entities.add_child(_station)
	for marker_name: String in ["Waiting", "Entry"]:
		var marker: Marker3D = Marker3D.new()
		marker.name = marker_name
		marker.position.x = -3.0 if marker_name == "Waiting" else 3.0
		_station.add_child(marker)
	_region = NavigationRegion3D.new()
	_level.add_child(_region)


## Освобождает стойку и native регион вместе с тестовым уровнем.
func after_each() -> void:
	_level.free()


func _mesh_for(tiles: Array[Vector2]) -> NavigationMesh:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.cell_height = 0.1
	var vertices: PackedVector3Array = []
	for tile: Vector2 in tiles:
		var offset: int = vertices.size()
		vertices.append_array(
			PackedVector3Array(
				[
					Vector3(tile.x, 0, -2),
					Vector3(tile.x, 0, 2),
					Vector3(tile.y, 0, 2),
					Vector3(tile.y, 0, -2),
				]
			)
		)
		mesh.add_polygon(PackedInt32Array([offset, offset + 1, offset + 2, offset + 3]))
	mesh.vertices = vertices
	return mesh
#endregion


#region Покрытие и связность навигации
## Перенос региона сохраняет полный путь между двумя точками стойки.
func test_connected_translated_region_passes() -> void:
	_region.position = Vector3(30, 0, -12)
	var counter_spatial: Node3D = _station as Node as Node3D
	counter_spatial.position = _region.position
	_region.navigation_mesh = _mesh_for([Vector2(-5, 5)])
	var errors: Array[String] = await CHECKS.failures(_level, _region)
	assert_true(errors.is_empty(), str(errors))


## Две покрытые точки на разных островах не подтверждают доступность стойки.
func test_disconnected_islands_fail_even_when_both_points_are_covered() -> void:
	_region.navigation_mesh = _mesh_for([Vector2(-5, -1), Vector2(1, 5)])
	var errors: Array[String] = await CHECKS.failures(_level, _region)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("No complete counter route to counter_entry"))


## Удалённые полигоны не скрывают отсутствие покрытия обеих точек ПВЗ.
func test_missing_warehouse_coverage_fails() -> void:
	_region.navigation_mesh = _mesh_for([Vector2(30, 40)])
	var errors: Array[String] = await CHECKS.failures(_level, _region)
	assert_eq(errors.size(), 2)
	assert_true(errors[0].contains("counter_waiting is off mesh"))
	assert_true(errors[1].contains("counter_entry is off mesh"))


## Пустой bake отклоняется до обращения к карте навигации.
func test_empty_mesh_fails() -> void:
	_region.navigation_mesh = NavigationMesh.new()
	var errors: Array[String] = await CHECKS.failures(_level, _region)
	assert_eq(errors, ["WarehouseNavigation has no baked polygons"])

#endregion


#region Current authored route acceptance
func test_unused_junctions_do_not_require_a_legacy_graph() -> void:
	var definition: DEF_District = _shade_definition()
	definition.shade_route.clear()
	for place: DEF_DistrictPlace in definition.places:
		place.kind = DEF_DistrictPlace.Kind.JUNCTION
	var positions: Dictionary[String, Vector3] = { }
	assert_true(CHECKS.shade_route_failures(definition, positions, RID(), 1).is_empty())


func test_unknown_shade_point_rejects_before_native_path_queries() -> void:
	var definition: DEF_District = _shade_definition()
	definition.shade_route.append("missing")
	var positions: Dictionary[String, Vector3] = {
		"west": Vector3(-3, 0, 0),
		"east": Vector3(3, 0, 0),
	}
	assert_eq(
		CHECKS.shade_route_failures(definition, positions, RID(), 1),
		["Unknown shade-route point: missing"],
	)


func test_connected_shade_passage_passes_in_both_directions() -> void:
	var errors: Array[String] = await _configured_route_errors([Vector2(-5, 5)])
	assert_true(errors.is_empty(), str(errors))


func test_disconnected_shade_passage_rejects_both_directions() -> void:
	var errors: Array[String] = await _configured_route_errors(
		[Vector2(-5, -1), Vector2(1, 5)],
	)
	assert_eq(errors.size(), 2)
	assert_true(errors.has("Unreachable shade-route segment: west > east"))
	assert_true(errors.has("Unreachable shade-route segment: east > west"))


func _shade_definition() -> DEF_District:
	var definition: DEF_District = DEF_District.new()
	for key: StringName in [&"west", &"east"]:
		var place: DEF_DistrictPlace = DEF_DistrictPlace.new()
		place.key = key
		definition.places.append(place)
	definition.shade_route = ["west", "east"]
	return definition


func _configured_route_errors(tiles: Array[Vector2]) -> Array[String]:
	_region.navigation_mesh = _mesh_for(tiles)
	var map_rid: RID = _region.get_navigation_map()
	var probe: Vector3 = _region.to_global(_region.navigation_mesh.vertices[0])
	var synchronized: bool = false
	for _frame: int in 120:
		await get_tree().physics_frame
		if (
			NavigationServer3D.map_get_iteration_id(map_rid) > 0
			and NavigationServer3D.map_get_closest_point_owner(map_rid, probe) == _region.get_rid()
		):
			synchronized = true
			break
	assert_true(synchronized, "The test's native navigation region synchronized")
	if not synchronized:
		return ["Test navigation region did not synchronize"]
	var positions: Dictionary[String, Vector3] = {
		"west": Vector3(-3, 0, 0),
		"east": Vector3(3, 0, 0),
	}
	return CHECKS.shade_route_failures(_shade_definition(), positions, map_rid, 1)
#endregion
