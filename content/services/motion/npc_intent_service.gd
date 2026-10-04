extends RefCounted
## Discrete generic commands; no physics velocity/transform writes or customer dependency.
class_name NpcIntentService


#region Movement intents
## Requests a fixed world destination without changing the body's physical pose.
static func move_to(actor: Entity, position: Vector3, arrival_distance: float) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return

	_clear_target(actor, R_NpcMoveTarget)
	intent.move_uses_entity = false
	intent.move_position = position
	intent.arrival_distance = maxf(0.0, arrival_distance)
	intent.arrived = false
	intent.movement_active = true


## Follows a live entity bound through Relationships.
static func follow(actor: Entity, target: Entity, arrival_distance: float) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return

	_clear_target(actor, R_NpcMoveTarget)
	intent.move_uses_entity = true
	intent.arrival_distance = maxf(0.0, arrival_distance)
	intent.arrived = false
	intent.movement_active = is_instance_valid(target)
	if intent.movement_active:
		actor.add_relationship(Relationship.new(R_NpcMoveTarget.new(), target))


## Cancels movement and releases its live target.
static func stop(actor: Entity) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return

	_clear_target(actor, R_NpcMoveTarget)
	intent.movement_active = false
	intent.move_uses_entity = false
#endregion


#region Observation intents
## Watches a recognized entity through an authoritative live binding.
static func watch(actor: Entity, target: Entity, offset: Vector3 = Vector3.ZERO) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return

	_clear_target(actor, R_NpcLookTarget)
	intent.look_uses_entity = true
	intent.look_offset = offset
	intent.look_mode = C_NpcIntent.LookMode.TARGET
	if is_instance_valid(target):
		actor.add_relationship(Relationship.new(R_NpcLookTarget.new(), target))


## Watches an authored location without retaining a live hidden target.
static func look_at(actor: Entity, position: Vector3) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return

	_clear_target(actor, R_NpcLookTarget)
	intent.look_uses_entity = false
	intent.look_position = position
	intent.look_offset = Vector3.ZERO
	intent.look_mode = C_NpcIntent.LookMode.TARGET


## Releases the observation target and follows the movement direction.
static func look_along_movement(actor: Entity) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent == null:
		return

	_clear_target(actor, R_NpcLookTarget)
	intent.look_uses_entity = false
	intent.look_mode = C_NpcIntent.LookMode.MOVEMENT
#endregion


#region Binding cleanup
static func _clear_target(actor: Entity, relation_type: Script) -> void:
	for relation: Relationship in actor.relationships.duplicate():
		if relation.relation.get_script() == relation_type:
			actor.remove_relationship(relation)
#endregion
