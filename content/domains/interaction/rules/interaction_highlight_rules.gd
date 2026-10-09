extends RefCounted
## Вычисляет состояние подсветки по реальным действиям, включая ограничения массы; мир не изменяет.
class_name InteractionHighlightRules

enum State { UNAVAILABLE, BUSY, AVAILABLE }


## Читает доступность, занятость или отказ текущей цели по существующим правилам действий.
static func state_for(actor: Entity, target: Node) -> State:
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death):
		return State.UNAVAILABLE

	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus >= InteractionControlFocus.Priority.PROLONGED:
		return State.BUSY

	var entity: Entity = target as Entity
	var body: RigidBody3D = target as RigidBody3D
	for slot: DEF_InteractionAction.Slot in [DEF_InteractionAction.Slot.INTERACT, DEF_InteractionAction.Slot.USE, DEF_InteractionAction.Slot.PRIMARY, DEF_InteractionAction.Slot.SECONDARY]:
		var choice: InteractionActionChoice = InteractionActionResolver.resolve(actor, slot)
		if choice == null:
			continue

		var grab: DEF_GrabAction = choice.action as DEF_GrabAction
		if grab != null:
			if grab.kind == DEF_GrabAction.Kind.PICKUP and (grab.physical_body == body or choice.source == entity):
				return State.AVAILABLE
		elif entity != null and (choice.source == entity or (choice.target == entity and choice.source != actor)):
			return State.AVAILABLE
	if entity != null and GrabQueries.held_relationship(entity) != null:
		return State.BUSY
	return State.UNAVAILABLE
