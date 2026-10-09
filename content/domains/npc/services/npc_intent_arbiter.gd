extends RefCounted
## Единственный владелец движения района; обычные NPC сохраняют существующий API намерений.
class_name NpcIntentArbiter


#region Владение намерением
## Получает приоритет на текущий такт решений, не отменяя выполняемую атаку.
static func acquire(actor: Entity, owner_kind: C_NpcDecision.Owner, behavior: String) -> bool:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision == null:
		return true
	if owner_kind > decision.intent_owner:
		return false

	if owner_kind < C_NpcDecision.Owner.SCHEDULE:
		NpcScheduleActionService.cancel_schedule(actor as E_DistrictNpc, &"priority_interrupted")
	decision.intent_owner = owner_kind
	decision.active_behavior = behavior
	return true


## Запрашивает движение к позиции без передачи скрытой актуальной цели навигации.
static func move_to(
	actor: Entity,
	world_position: Vector3,
	arrival_distance: float,
	owner_kind: C_NpcDecision.Owner,
) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision != null and decision.intent_owner != owner_kind:
		return

	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return
	if (
		intent.movement_active and not intent.move_uses_entity
		and intent.move_position.distance_squared_to(world_position) < 0.01
	):
		return

	NpcIntentService.move_to(actor, world_position, arrival_distance)
	NpcIntentService.look_along_movement(actor)


## Останавливает движение только текущего владельца намерения.
static func stop(actor: Entity, owner_kind: C_NpcDecision.Owner) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision == null or decision.intent_owner == owner_kind:
		NpcIntentService.stop(actor)
#endregion
