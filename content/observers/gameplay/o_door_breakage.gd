extends Observer
## Истощение HP двери через общий урон снимает лишь навесной замок и обновляет представление.
class_name O_DoorBreakage


#region Наблюдение урона
## Слушает результаты урона разрушаемых открываемых дверей.
func query() -> QueryBuilder:
	return q.with_all([C_BreakableDoor, C_Openable]).on_event(DamageResult.EVENT)


## После принятого истощения HP ставит отложенную синхронизацию разрушения; повторно проверяет участие.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
		return
	if result.request == null or result.request.target != entity:
		return

	cmd.add_custom(_break.bind(entity))


#endregion

#region Применение разрушения
func _break(entity: Entity) -> void:
	if not EntityAvailability.contains(entity, _world):
		return

	var config: C_BreakableDoor = entity.get_component(C_BreakableDoor) as C_BreakableDoor
	if config.mode == C_BreakableDoor.Mode.PADLOCK:
		(entity.get_component(C_Openable) as C_Openable).locked = false
	var door: E_Door = entity as E_Door
	if door != null:
		door.sync_destruction_view()

#endregion
