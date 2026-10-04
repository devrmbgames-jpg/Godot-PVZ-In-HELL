extends RefCounted
class_name FloorChallengeService


static func synchronize(subject: Entity, state: C_Challenge, floor: C_FloorChallenge) -> void:
	if not EntityAvailability.contains(subject, ECS.world):
		return
	if state.phase != C_Challenge.Phase.ACTIVE:
		floor.touching_danger = false
		ChallengeEffectLifecycle.retire(subject)
		return
	if not ChallengeService.session_valid(subject):
		ChallengeService.cancel(subject)
		return

	var rule: DEF_FloorChallengeCondition = state.definition.condition as DEF_FloorChallengeCondition if state.definition != null else null
	if rule == null or floor.spawn_requested:
		return

	floor.spawn_requested = true
	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.origin = subject
	request.instigator = subject
	request.origin_id = subject.id
	request.instigator_id = subject.id
	request.request_id = "%s/challenge/%s" % [subject.id, state.definition.key]
	request.scene = rule.hazard_scene
	request.world_pose = Transform3D(Basis.IDENTITY, rule.world_position)
	if not HazardSpawnService.submit(request):
		ChallengeService.cancel(subject)


static func touches_surface(motion: C_Motion, pose: Transform3D, profile: DEF_FloorHazard) -> bool:
	if motion == null or not motion.is_on_floor or not motion.floor_body_rid.is_valid():
		return false

	var point: Vector3 = pose.affine_inverse() * motion.floor_contact_position
	return (
		absf(point.x) <= profile.size.x * 0.5
		and absf(point.z) <= profile.size.y * 0.5
		and absf(point.y) <= profile.contact_tolerance
	)


static func step(effect: E_FloorHazard, hazard: C_Hazard, floor_effect: C_FloorHazard, delta: float) -> void:
	var subject: Entity = ChallengeEffectLifecycle.owner_for(effect)
	if subject == null:
		HazardLifecycle.retire(effect, ECS.world)
		return

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if not ChallengeService.session_valid(subject):
		ChallengeService.cancel(subject)
		return
	if state.phase != C_Challenge.Phase.ACTIVE:
		ChallengeEffectLifecycle.retire(subject)
		return

	var actor: Entity = ChallengeService.actor_for(subject)
	var profile: DEF_FloorHazard = hazard.definition as DEF_FloorHazard
	var floor: C_FloorChallenge = subject.get_component(C_FloorChallenge) as C_FloorChallenge
	if actor == null or profile == null or floor == null or not is_finite(delta) or delta < 0.0:
		ChallengeService.cancel(subject)
		return

	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	floor.touching_danger = touches_surface(motion, (effect as Node as Node3D).global_transform, profile)
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
