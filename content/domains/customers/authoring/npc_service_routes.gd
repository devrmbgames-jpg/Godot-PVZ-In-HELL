extends Node3D
## Явные маршруты ожидания клиентов; порядок Marker3D и ссылки редактируются в сцене.
class_name NpcServiceRoutes

## Упорядоченные точки первого ожидающего клиента, относительно этого узла.
@export var first_route: Array[NodePath] = []
## Упорядоченные точки второго ожидающего клиента, относительно этого узла.
@export var second_route: Array[NodePath] = []

#region Авторские точки
## Возвращает заданную точку маршрута без поиска путей и сканирования уровня.
func point_for(route_index: int, point_index: int) -> Node3D:
	var route: Array[NodePath] = first_route if route_index == 0 else second_route
	if route.is_empty():
		return null
	return get_node_or_null(route[posmod(point_index, route.size())]) as Node3D
#endregion
