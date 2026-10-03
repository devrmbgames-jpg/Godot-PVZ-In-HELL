extends RefCounted
## Native coverage and connected-route regression for authored warehouse and district destinations.

const POINT_TOLERANCE: float = 1.0
const MAX_SYNCHRONIZATION_FRAMES: int = 120
const WAREHOUSE_MARKERS: PackedStringArray = [
	"MainDoor", "BackDoor", "RoomClient", "RoomPrivate", "ReceivingZone", "TraderClientZone",
]

#region Native validation
## Returns failures without issuing gameplay commands or modifying the authored mesh.
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
	# An initial iteration can still be empty while the asynchronous region rebuild runs.
	var probe: Vector3 = region.to_global(mesh.get_vertices()[0])
	var synchronized: bool = false
	for frame_index: int in MAX_SYNCHRONIZATION_FRAMES:
		await level.get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map_rid) > 0 and NavigationServer3D.map_get_closest_point_owner(map_rid, probe) == region_rid:
			synchronized = true
			break
	if not synchronized:
		NavigationServer3D.free_rid(region_rid)
		NavigationServer3D.free_rid(map_rid)
		errors.append("Navigation map did not synchronize within the bounded frame limit")
		return errors

	var points: Dictionary[String, Vector3] = {}
	var station: E_DeliveryCounter = level.get_node_or_null("Entityes/DeliveryCounter") as E_DeliveryCounter
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

	var district: C_District = DistrictPopulationService.current()
	if district != null:
		for place: DEF_DistrictPlace in district.definition.places:
			points[str(place.key)] = DistrictPopulationService.position_for(place.key)
			if not place.activity_offset.is_zero_approx():
				points[str(place.key) + "/activity"] = NpcActivityService.destination(place)

	var checked_routes: int = 0
	var waiting: Vector3 = points.get("counter_waiting", Vector3.ZERO)
	for point_key: String in points:
		var target: Vector3 = points[point_key]
		var nearest: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, target)
		if nearest.distance_to(target) > POINT_TOLERANCE:
			errors.append("%s is off mesh: distance=%.2f point=%s nearest=%s" % [point_key, nearest.distance_to(target), target, nearest])
			continue
		if station == null or point_key == "counter_waiting":
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, waiting, target, true, region.navigation_layers)
		if path.is_empty() or path[0].distance_to(waiting) > POINT_TOLERANCE or path[-1].distance_to(target) > POINT_TOLERANCE:
			errors.append("No complete counter route to " + point_key)
		else:
			checked_routes += 1

	if district != null:
		errors.append_array(_graph_failures(district.definition, map_rid, region.navigation_layers))

	NavigationServer3D.free_rid(region_rid)
	NavigationServer3D.free_rid(map_rid)
	print("Navigation coverage: %d points, %d connected counter routes, %d failures" % [points.size(), checked_routes, errors.size()])
	return errors
#endregion

#region Hazard-route graph
static func _graph_failures(definition: DEF_District, map_rid: RID, navigation_layers: int) -> Array[String]:
	var errors: Array[String] = []
	var junctions: Dictionary[StringName, DEF_DistrictPlace] = {}
	for place: DEF_DistrictPlace in definition.places:
		if place.kind == DEF_DistrictPlace.Kind.JUNCTION:
			junctions[place.key] = place
	if junctions.is_empty():
		errors.append("District has no hazard-route junctions")
		return errors

	var connected_edges: int = 0
	for junction_key: StringName in junctions:
		var start: Vector3 = DistrictPopulationService.position_for(junction_key)
		for neighbour_key: String in junctions[junction_key].neighbours:
			var next_key: StringName = StringName(neighbour_key)
			if not junctions.has(next_key):
				continue
			var target: Vector3 = DistrictPopulationService.position_for(next_key)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, start, target, true, navigation_layers)
			if path.is_empty() or path[0].distance_to(start) > POINT_TOLERANCE or path[-1].distance_to(target) > POINT_TOLERANCE:
				errors.append("Unreachable hazard-route edge: %s > %s" % [junction_key, next_key])
			else:
				connected_edges += 1

	# Directed connectivity is required from every junction used as a route connector.
	for origin_key: StringName in junctions:
		var pending: Array[StringName] = [origin_key]
		var visited: Array[StringName] = []
		while not pending.is_empty():
			var current_key: StringName = pending.pop_back()
			if visited.has(current_key):
				continue
			visited.append(current_key)
			for neighbour_key: String in junctions[current_key].neighbours:
				var next_key: StringName = StringName(neighbour_key)
				if junctions.has(next_key) and not visited.has(next_key):
					pending.append(next_key)
		if visited.size() != junctions.size():
			errors.append("Hazard-route graph is disconnected from " + str(origin_key))
			break

	print("Navigation hazard graph: %d junctions, %d traversable directed edges" % [junctions.size(), connected_edges])
	return errors
#endregion
