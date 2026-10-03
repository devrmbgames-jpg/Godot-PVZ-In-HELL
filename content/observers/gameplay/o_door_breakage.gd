extends Observer
## Door HP uses the shared damage pipeline; depletion unlocks only the padlock variant.
class_name O_DoorBreakage


func query() -> QueryBuilder:
	return q.with_all([C_BreakableDoor, C_Openable]).on_event(DamageResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
		return
	if result.request == null or result.request.target != entity:
		return
	cmd.add_custom(_break.bind(entity))


func _break(entity: Entity) -> void:
	if not EntityAvailability.contains(entity, _world):
		return
	var config: C_BreakableDoor = entity.get_component(C_BreakableDoor) as C_BreakableDoor
	if config.mode == C_BreakableDoor.Mode.PADLOCK:
		(entity.get_component(C_Openable) as C_Openable).locked = false
	var door: E_Door = entity as E_Door
	if door != null:
		door.sync_destruction_view()
