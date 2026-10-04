@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Идёт к стойке или к адресу действующей домашней встречи.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Прибытие получателя"):
		return FAILURE
	var visit: CustomerVisit = _visit()
	var door: Entity = NpcHomeDeliveryService.door_for(_actor)
	var destination: Vector3 = (door as Node as Node3D).global_position if door != null else CustomerFlowService.counter().waiting_position()
	_move(destination, visit.definition.arrival_distance)
	return RUNNING

#endregion
