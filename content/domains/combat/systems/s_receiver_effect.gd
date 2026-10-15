extends System
## Periodic artifact volumes use native overlap and the common committed damage/heal authority.
class_name S_ReceiverEffect


#region Scheduled native volumes
func query() -> QueryBuilder:
	return q.enabled().with_all([C_ReceiverEffect]).iterate([C_ReceiverEffect])


## Combines due intervals per source; queued execution resolves the source lifetime again.
## GamePlay seconds accumulate from zero; one dispatch per receiver combines all due intervals.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var sources: Array = components[0]
	for index: int in entities.size():
		var state: C_ReceiverEffect = sources[index] as C_ReceiverEffect
		var profile: DEF_ReceiverEffect = state.definition
		if not ReceiverEffectRules.valid(profile):
			continue
		state.tick_elapsed += delta
		var ticks: int = floori(state.tick_elapsed / profile.tick_seconds)
		if ticks <= 0:
			continue
		state.tick_elapsed -= float(ticks) * profile.tick_seconds
		cmd.add_custom(_apply.bind(weakref(entities[index]), state, profile, ticks))
#endregion


#region Queued effect dispatch
func _apply(
	reference: WeakRef,
	captured: C_ReceiverEffect,
	profile: DEF_ReceiverEffect,
	ticks: int,
) -> void:
	var source: Entity = reference.get_ref() as Entity
	if (
		not EntityAvailability.contains(source, _world)
		or source.get_component(C_ReceiverEffect) != captured or captured.definition != profile
	):
		return
	var area: Area3D = source.get_node(captured.area_path) as Area3D
	assert(area != null, "Receiver effects require an authored Area3D")
	# Collect identities before dispatch: a committed result may synchronously retire another body.
	var candidates: Array[WeakRef] = []
	var seen: Dictionary[int, bool] = { }
	for body: Node3D in area.get_overlapping_bodies():
		var target: Entity = HazardTargets.entity_for(body)
		if target == source or not EntityAvailability.contains(target, _world):
			continue
		var key: int = target.get_instance_id()
		if not seen.has(key):
			seen[key] = true
			candidates.append(weakref(target))
	for candidate: WeakRef in candidates:
		if (
			not EntityAvailability.contains(source, _world)
			or source.get_component(C_ReceiverEffect) != captured
		):
			return
		var target: Entity = candidate.get_ref() as Entity
		if not EntityAvailability.contains(target, _world) or not target.has_component(C_Health):
			continue
		var operation: int = ReceiverEffectRules.operation_for(target, profile.alignment)
		if operation == ReceiverEffectRules.EXCLUDED:
			continue
		var request: DamageRequest = DamageRequest.new()
		request.source = source
		request.target = target
		request.amount = profile.amount_per_tick * float(ticks)
		request.operation = operation as DamageRequest.Operation
		request.damage_type = (
			DamageRequest.Type.HOLY
			if profile.alignment == DEF_ReceiverEffect.Alignment.HOLY
			else DamageRequest.Type.UNHOLY
		)
		var grip: Relationship = GrabQueries.held_relationship(source)
		var thrown: Relationship = ThrowContext.relationship(source)
		if grip != null:
			request.instigator = grip.target as Entity
		elif thrown != null:
			request.instigator = thrown.target as Entity
		DamageRequestService.submit(request)
#endregion
