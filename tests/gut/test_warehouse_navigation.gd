extends GutTest
## Проверки покрытия ПВЗ и связности native navmesh; неполный путь между островами не считается успехом.

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
	counter_body.set_script(load("res://content/entities/stations/e_delivery_counter.gd"))
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
		vertices.append_array(PackedVector3Array([
			Vector3(tile.x, 0, -2), Vector3(tile.x, 0, 2),
			Vector3(tile.y, 0, 2), Vector3(tile.y, 0, -2),
		]))
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
