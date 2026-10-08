@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Сравнивает расстояние только до видимого игрока с авторским радиусом засады.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	if _awareness == null or not _awareness.player_visible:
		return FAILURE
	var scenario: DEF_NpcDeliveryScenario = NpcDeliveryScenarioService.definition_for(NpcDeliveryScenarioService.armed_for(_actor))
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	var player_body: Node3D = player as Node as Node3D
	return SUCCESS if scenario != null and player_body != null and _actor.global_position.distance_to(player_body.global_position) <= scenario.ambush_radius else FAILURE
#endregion
