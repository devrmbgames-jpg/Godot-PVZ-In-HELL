extends RefCounted
## Single branch ownership for district movement; ordinary actors keep the existing intent API.
class_name NpcIntentArbiter

#region Intent ownership
## Acquires priority for one decision batch without cancelling an executing attack.
static func acquire(actor: Entity, owner_kind: C_NpcDecision.Owner, behavior: String) -> bool:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision == null:
		return true
	if owner_kind > decision.intent_owner:
		return false

	decision.intent_owner = owner_kind
	decision.active_behavior = behavior
	return true

## Issues position movement without leaking a hidden live target into navigation.
static func move_to(actor: Entity, world_position: Vector3, arrival_distance: float, owner_kind: C_NpcDecision.Owner) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision != null and decision.intent_owner != owner_kind:
		return

	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return
	if intent.movement_active and not intent.move_uses_entity and intent.move_position.distance_squared_to(world_position) < 0.01:
		return

	NpcIntentService.move_to(actor, world_position, arrival_distance)
	NpcIntentService.look_along_movement(actor)

## Stops only the branch that currently owns movement.
static func stop(actor: Entity, owner_kind: C_NpcDecision.Owner) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision == null or decision.intent_owner == owner_kind:
		NpcIntentService.stop(actor)
#endregion
