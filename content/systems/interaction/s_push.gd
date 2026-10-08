extends System
## Owns scheduled push participation checks; Services commit bindings and native solvers own motion.
class_name S_Push


#region Scheduled push participation
## Checks Push after targeting and before generic hold forces.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting], Runs.Before: [S_Grab] }


## Выбирает акторов с вводом и производным кешем толкания.
func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_PushControl]).iterate([C_PushControl])


## Captures the current binding before deferred participation retirement.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for actor: Entity in entities:
		var cart: Entity = PushService.pushed_object(actor)
		if cart == null:
			continue
		var binding: Relationship = PushService.relationship(cart)
		cmd.add_custom(_validate_participation.bind(actor, cart, binding))


func _validate_participation(actor: Entity, cart: Entity, binding: Relationship) -> void:
	# A queued check belongs to this session, including when the same pair starts again.
	if not EntityAvailability.contains(actor, _world) or not EntityAvailability.contains(cart, _world):
		return
	if PushService.relationship(cart) != binding or binding.target != actor:
		return
	if not PushService.valid_pair(actor, cart):
		PushService.end(actor, cart)
#endregion
