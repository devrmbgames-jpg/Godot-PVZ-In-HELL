extends System
## Owns floor challenge support measurements and clipped periodic damage before challenge resolution.
class_name S_FloorHazard

#region Scheduling
## Activation owns setup; floor damage precedes challenge result and general hazard TTL.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_DayPhase], Runs.Before: [S_ChallengeRuntime, S_HazardLifetime]}


## Selects enabled autonomous floor effects with their launch/profile state.
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_FloorHazard]).enabled()


## Captures effect state identity before deferred measurement/damage work.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity: Entity in entities:
		var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
		var floor_effect: C_FloorHazard = entity.get_component(C_FloorHazard) as C_FloorHazard
		cmd.add_custom(_advance.bind(weakref(entity), hazard, floor_effect, delta))
#endregion

#region Support and damage clocks
func _advance(entity_reference: WeakRef, hazard: C_Hazard, floor_effect: C_FloorHazard, delta: float) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) or entity.get_component(C_Hazard) != hazard \
			or entity.get_component(C_FloorHazard) != floor_effect:
		return
	_step(entity as E_FloorHazard, hazard, floor_effect, delta)


func _step(effect: E_FloorHazard, hazard: C_Hazard, floor_effect: C_FloorHazard, delta: float) -> void:
	var subject: Entity = ChallengeEffectLifecycle.owner_for(effect)
	if subject == null:
		HazardLifecycle.retire(effect, ECS.world)
		return

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if not ChallengeService.session_valid(subject):
		ChallengeService.cancel(subject)
		return
	if state.phase != C_Challenge.Phase.ACTIVE:
		var inactive_floor: C_FloorChallenge = subject.get_component(C_FloorChallenge) as C_FloorChallenge
		if inactive_floor != null:
			inactive_floor.touching_danger = false
		ChallengeEffectLifecycle.retire(subject)
		return

	var actor: Entity = ChallengeService.actor_for(subject)
	var profile: DEF_FloorHazard = hazard.definition as DEF_FloorHazard
	var floor: C_FloorChallenge = subject.get_component(C_FloorChallenge) as C_FloorChallenge
	if actor == null or profile == null or floor == null or not is_finite(delta) or delta < 0.0:
		ChallengeService.cancel(subject)
		return

	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	floor.touching_danger = FloorContactGeometry.touches_surface(motion, (effect as Node as Node3D).global_transform, profile)
	state.condition_result = ChallengeResult.Type.NONE if floor.touching_danger else ChallengeResult.Type.SUCCESS
	var end_elapsed: float = minf(state.elapsed + delta, state.definition.timeout_seconds)
	var dangerous_delta: float = maxf(0.0, end_elapsed - maxf(state.elapsed, state.definition.preparation_seconds))
	effect.set_danger_active(end_elapsed > state.definition.preparation_seconds)
	if not floor.touching_danger:
		floor_effect.damage_elapsed = 0.0
		return

	dangerous_delta = minf(dangerous_delta, maxf(0.0, state.definition.violation_grace_seconds - state.violation_elapsed))
	floor_effect.damage_elapsed += dangerous_delta
	var ticks: int = int(floor_effect.damage_elapsed / profile.tick_seconds)
	if ticks > 0:
		floor_effect.damage_elapsed -= ticks * profile.tick_seconds
		HazardDamage.submit(effect, hazard, actor, profile.damage_per_tick * ticks, DamageRequest.Type.GENERIC)

#endregion
