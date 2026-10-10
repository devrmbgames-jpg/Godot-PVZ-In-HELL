extends RefCounted
## Проверяет покрытие/связность авторских точек ПВЗ и района на отдельной native-карте; runtime-граф
## не строит.

const POINT_TOLERANCE: float = 1.0
const MAX_SYNCHRONIZATION_FRAMES: int = 120
const WAREHOUSE_MARKERS: PackedStringArray = [
	"MainDoor",
	"BackDoor",
	"RoomClient",
	"RoomPrivate",
	"ReceivingZone",
	"TraderClientZone",
]


#region Покрытие авторских точек
## Асинхронно возвращает нарушения покрытия/маршрутов; временные RID освобождаются, авторская сетка
## не меняется.
static func failures(level: Node3D, region: NavigationRegion3D) -> Array[String]:
	var errors: Array[String] = []
	var mesh: NavigationMesh = region.navigation_mesh
	if mesh == null or mesh.get_polygon_count() == 0:
		errors.append("WarehouseNavigation has no baked polygons")
		return errors

	var map_rid: RID = NavigationServer3D.map_create()
	var region_rid: RID = NavigationServer3D.region_create()
	NavigationServer3D.map_set_cell_size(map_rid, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map_rid, mesh.cell_height)
	NavigationServer3D.map_set_active(map_rid, true)
	NavigationServer3D.region_set_map(region_rid, map_rid)
	NavigationServer3D.region_set_navigation_layers(region_rid, region.navigation_layers)
	NavigationServer3D.region_set_transform(region_rid, region.global_transform)
	NavigationServer3D.region_set_navigation_mesh(region_rid, mesh)
	# Первая итерация может быть пустой: ожидается завершение асинхронной пересборки региона.
	var probe: Vector3 = region.to_global(mesh.get_vertices()[0])
	var synchronized: bool = false
	for frame_index: int in MAX_SYNCHRONIZATION_FRAMES:
		await level.get_tree().physics_frame
		if (
			NavigationServer3D.map_get_iteration_id(map_rid) > 0
			and NavigationServer3D.map_get_closest_point_owner(map_rid, probe) == region_rid
		):
			synchronized = true
			break
	if not synchronized:
		NavigationServer3D.free_rid(region_rid)
		NavigationServer3D.free_rid(map_rid)
		errors.append("Navigation map did not synchronize within the bounded frame limit")
		return errors

	var points: Dictionary[String, Vector3] = { }
	var station: E_DeliveryCounter = (
		level.get_node_or_null("Entityes/DeliveryCounter") as E_DeliveryCounter
	)
	if station == null:
		errors.append("DeliveryCounter is missing")
	else:
		points["counter_waiting"] = station.waiting_position()
		points["counter_entry"] = station.entry_position()

	var markers: Node3D = level.get_node_or_null("DebugMarkers") as Node3D
	if markers != null:
		for marker_name: String in WAREHOUSE_MARKERS:
			var marker: Node3D = markers.get_node_or_null(NodePath(marker_name)) as Node3D
			if marker == null:
				errors.append("Missing warehouse marker: " + marker_name)
				continue

			var floor_point: Vector3 = marker.global_position
			floor_point.y = level.global_position.y
			points[marker_name] = floor_point

	var district: C_District = NpcPopulationQueries.current()
	if district != null:
		for place: DEF_DistrictPlace in district.definition.places:
			points[str(place.key)] = NpcPopulationQueries.position_for(place.key)
			if not place.activity_offset.is_zero_approx():
				points[str(place.key) + "/activity"] = NpcActivityService.destination(place)

	var checked_routes: int = 0
	var waiting: Vector3 = points.get("counter_waiting", Vector3.ZERO)
	for point_key: String in points:
		var target: Vector3 = points[point_key]
		var nearest: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, target)
		if nearest.distance_to(target) > POINT_TOLERANCE:
			errors.append(
				"%s is off mesh: distance=%.2f point=%s nearest=%s"
				% [point_key, nearest.distance_to(target), target, nearest]
			)
			continue
		if station == null or point_key == "counter_waiting":
			continue

		var path: PackedVector3Array = (
			NavigationServer3D.map_get_path(
				map_rid,
				waiting,
				target,
				true,
				region.navigation_layers,
			)
		)
		if (
			path.is_empty() or path[0].distance_to(waiting) > POINT_TOLERANCE
			or path[-1].distance_to(target) > POINT_TOLERANCE
		):
			errors.append("No complete counter route to " + point_key)
		else:
			checked_routes += 1

	if district != null:
		errors.append_array(shade_route_failures(
			district.definition, points, map_rid, region.navigation_layers,
		))

	NavigationServer3D.free_rid(region_rid)
	NavigationServer3D.free_rid(map_rid)
	print(
		"Navigation coverage: %d points, %d connected counter routes, %d failures"
		% [points.size(), checked_routes, errors.size()]
	)
	return errors
#endregion


#region Current authored route contract
## Validates the ordered shade passage used by NpcRouteSolver, including reverse traversal.
## Positions are resolved by the caller; an empty passage uses the already checked native mesh.
static func shade_route_failures(
	definition: DEF_District,
	positions: Dictionary[String, Vector3],
	map_rid: RID,
	navigation_layers: int,
) -> Array[String]:
	var errors: Array[String] = []
	for route_key: String in definition.shade_route:
		if definition.place_for(StringName(route_key)) == null or not positions.has(route_key):
			errors.append("Unknown shade-route point: " + route_key)
	if not errors.is_empty():
		return errors

	for index: int in range(1, definition.shade_route.size()):
		# Runtime may enter the authored passage from either end.
		for reverse: bool in [false, true]:
			var start_key: String = definition.shade_route[index if reverse else index - 1]
			var target_key: String = definition.shade_route[index - 1 if reverse else index]
			var start: Vector3 = positions[start_key]
			var target: Vector3 = positions[target_key]
			var path: PackedVector3Array = NavigationServer3D.map_get_path(
				map_rid, start, target, true, navigation_layers,
			)
			if (
				path.is_empty() or path[0].distance_to(start) > POINT_TOLERANCE
				or path[-1].distance_to(target) > POINT_TOLERANCE
			):
				errors.append("Unreachable shade-route segment: %s > %s" % [start_key, target_key])
	return errors
#endregion
