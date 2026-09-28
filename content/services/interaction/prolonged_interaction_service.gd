extends RefCounted
## Owns prolonged sessions and synchronous effect completion at the input command boundary.
class_name ProlongedInteractionService


static func session(actor: Entity) -> Relationship:
	if is_instance_valid(actor):
		for binding: Relationship in actor.relationships:
			if binding.relation is R_ProlongedOn:
				return binding
	return null


static func progress_for(target: Entity, action_id: StringName) -> ProlongedInteractionProgress:
	if not is_instance_valid(target):
		return null
	var state: C_ProlongedInteraction = target.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state != null:
		for progress: ProlongedInteractionProgress in state.actions:
			if progress.action_id == action_id:
				return progress
	return null


static func active_progress(actor: Entity) -> ProlongedInteractionProgress:
	var binding: Relationship = session(actor)
	if binding == null:
		return null
	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	return progress_for(binding.target as Entity, data.action.action_id)


static func begin(actor: Entity, choice: InteractionActionChoice, slot: DEF_InteractionAction.Slot) -> bool:
	if choice == null or choice.action == null or session(actor) != null:
		return false
	var action: DEF_InteractionAction = choice.action
	var target: Entity = choice.target if choice.target != null else choice.source
	if (
		not GrabService.holder_available(actor) or not GrabService.entity_available(target)
		or not GrabService.entity_available(choice.source) or action.action_id == &""
		or action.timing == null or not action.is_available(actor, choice.source, choice.target)
		or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PROLONGED
	):
		return false
	if not is_finite(action.timing.duration_seconds) or action.timing.duration_seconds <= 0.0:
		return false
	if (
		not is_finite(action.timing.decay_per_second) or action.timing.decay_per_second < 0.0
		or action.timing.reset_policy < DEF_ProlongedInteraction.ResetPolicy.DECAY
		or action.timing.reset_policy > DEF_ProlongedInteraction.ResetPolicy.NEVER
	):
		return false
	if not is_instance_valid(ECS.world):
		return false
	for other: Entity in ECS.world.entities:
		var occupied: Relationship = session(other)
		if occupied != null and occupied.target == target:
			return false
	var state: C_ProlongedInteraction = target.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state == null:
		state = C_ProlongedInteraction.new()
		target.add_component(state)
	var progress: ProlongedInteractionProgress = progress_for(target, action.action_id)
	if progress == null:
		progress = ProlongedInteractionProgress.new()
		progress.action_id = action.action_id
		progress.timing = action.timing
		state.actions.append(progress)
	if progress.timing != action.timing or progress.phase == ProlongedInteractionProgress.Phase.COMPLETED:
		return false
	var data: R_ProlongedOn = R_ProlongedOn.new()
	data.action = action
	data.input_slot = slot
	data.capture_token = InteractionControlFocus.acquire(actor, target, InteractionControlFocus.Priority.PROLONGED)
	if data.capture_token == 0:
		return false
	var binding: Relationship = Relationship.new(data, target)
	actor.add_relationship(binding)
	if choice.source != target:
		actor.add_relationship(Relationship.new(R_ProlongedUsing.new(), choice.source))
	var cleanup: Callable = _cancel_session.bind(actor, binding)
	for participant: Entity in [actor, target, choice.source]:
		if not participant.tree_exiting.is_connected(cleanup):
			participant.tree_exiting.connect(cleanup)
	return true


## True reserves this entire input tick, including release and interruption.
static func tick(actor: Entity, delta: float) -> bool:
	var binding: Relationship = session(actor)
	if binding == null:
		return false
	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	if (
		controller == null or not _held(controller, data.input_slot) or controller.cancel_pressed
		or not GrabService.holder_available(actor)
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.PROLONGED
	):
		cancel(actor)
		return true
	var target: Entity = binding.target as Entity
	var source: Entity = _source(actor, target)
	var progress: ProlongedInteractionProgress = progress_for(target, data.action.action_id)
	if (
		progress == null or not GrabService.entity_available(target)
		or not GrabService.entity_available(source)
	):
		cancel(actor)
		return true
	# Re-resolve with only our token excluded: raycast, tool mapping and other captures
	# retain their ordinary authority. No temporary release/reacquire window.
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(actor, data.input_slot, data.capture_token)
	if (
		choice == null or choice.action != data.action or choice.source != source
		or (choice.target if choice.target != null else choice.source) != target
	):
		cancel(actor)
		return true
	if ProlongedProgressService.advance(progress, data.action.timing, delta, true):
		# Reentrant removal by the effect releases participation but must not reset
		# READY before the synchronous success result has been committed.
		data.finishing = true
		var success: bool = data.action.complete(actor, source, choice.target)
		data.finishing = false
		if success:
			ProlongedProgressService.commit_success(progress, data.action.timing)
		if not success or data.cleaned:
			ProlongedProgressService.interrupt(progress, data.action.timing)
			cancel(actor)
	return true


static func cancel(actor: Entity) -> void:
	var binding: Relationship = session(actor)
	if binding != null:
		# Cleanup first so relationship observers are safely idempotent.
		removed(actor, binding)
		actor.remove_relationship(binding)


static func removed(actor: Entity, binding: Relationship) -> void:
	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	if data == null or data.cleaned:
		return
	data.cleaned = true
	var target: Entity = binding.target as Entity
	var source: Entity = _source(actor, target)
	var cleanup: Callable = _cancel_session.bind(actor, binding)
	for participant: Entity in [actor, target, source]:
		if is_instance_valid(participant) and participant.tree_exiting.is_connected(cleanup):
			participant.tree_exiting.disconnect(cleanup)
	var progress: ProlongedInteractionProgress = progress_for(target, data.action.action_id)
	if progress != null and not data.finishing:
		ProlongedProgressService.interrupt(progress, data.action.timing)
	InteractionControlFocus.release(actor, data.capture_token)
	for relation: Relationship in actor.relationships.duplicate():
		if relation.relation is R_ProlongedUsing:
			actor.remove_relationship(relation)


static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(ECS.world):
		return
	cancel(entity)
	for actor: Entity in ECS.world.entities.duplicate():
		var binding: Relationship = session(actor)
		if binding != null and (binding.target == entity or _source(actor, binding.target as Entity) == entity):
			cancel(actor)


## GECS has already erased Using when this callback runs; its payload still owns
## the source needed to disconnect the old tree-exit callback.
static func source_removed(actor: Entity, source_binding: Relationship) -> void:
	var binding: Relationship = session(actor)
	if binding == null:
		return
	var source: Entity = source_binding.target as Entity
	var cleanup: Callable = _cancel_session.bind(actor, binding)
	if is_instance_valid(source) and source.tree_exiting.is_connected(cleanup):
		source.tree_exiting.disconnect(cleanup)
	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	if data.cleaned:
		return
	cancel(actor)


static func decay(state: C_ProlongedInteraction, delta: float) -> void:
	for progress: ProlongedInteractionProgress in state.actions:
		if progress.phase == ProlongedInteractionProgress.Phase.IDLE:
			ProlongedProgressService.advance(progress, progress.timing, delta, false)


static func _source(actor: Entity, target: Entity) -> Entity:
	for binding: Relationship in actor.relationships:
		if binding.relation is R_ProlongedUsing:
			return binding.target as Entity
	return target


static func _cancel_session(actor: Entity, binding: Relationship) -> void:
	if session(actor) == binding:
		cancel(actor)


static func _held(controller: C_Controller, slot: DEF_InteractionAction.Slot) -> bool:
	match slot:
		DEF_InteractionAction.Slot.INTERACT:
			return controller.interact_held
		DEF_InteractionAction.Slot.USE:
			return controller.use_held
		DEF_InteractionAction.Slot.PRIMARY:
			return controller.action_main
		DEF_InteractionAction.Slot.SECONDARY:
			return controller.action_second_held
	return false
