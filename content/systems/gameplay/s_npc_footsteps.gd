extends System
## Owns player and due-NPC footstep clocks; emits bounded anonymous noise before perception.
class_name S_NpcFootsteps

## Existing physical speed threshold below which a body emits no walking noise.
const MIN_WALKING_SPEED: float = 0.2
## Existing physical speed threshold selecting the authored running-noise radius.
const RUNNING_SPEED: float = 3.0

#region Scheduling
## All footstep noise is visible before the due sensor batch.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcCadence], Runs.Before: [S_NpcPerception]}


## Selects the district/calendar controlling both footstep cadence variants.
func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle])


## Queues the bounded player/due-actor sampling operation.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for session: Entity in entities:
		var captured_district: C_District = session.get_component(C_District) as C_District
		var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		cmd.add_custom(_sample.bind(weakref(session), delta, captured_district, captured_cycle))
#endregion

#region Footstep clocks
func _sample(session_reference: WeakRef, delta: float, captured_district: C_District, captured_cycle: C_DayCycle) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) \
			or session.get_component(C_District) != captured_district \
			or session.get_component(C_DayCycle) != captured_cycle:
		return

	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if cycle.phase == C_DayCycle.Phase.NIGHT:
		return
	var player: Entity = _world.query.with_all([C_PlayerInputController]).execute_one()
	if player != null:
		_advance_footsteps(player, delta)
	for entity: Entity in _world.query.with_all([C_NpcIdentity, C_NpcDecision, C_NpcAwareness]).enabled().execute():
		var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
		var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
		var decision: C_NpcDecision = entity.get_component(C_NpcDecision) as C_NpcDecision
		if NpcDecisionRules.matches_step(person, decision, cycle):
			_advance_footsteps(entity, decision.scheduled_delta)


func _advance_footsteps(actor: Entity, delta: float) -> void:
	var body: RigidBody3D = actor as Node as RigidBody3D
	if body == null or not actor.enabled:
		return

	var speed: float = Vector2(body.linear_velocity.x, body.linear_velocity.z).length()
	if speed < MIN_WALKING_SPEED:
		return

	var district: C_District = DistrictPopulationService.current()
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var elapsed: float = awareness.footstep_elapsed + delta if awareness != null else district.player_step_elapsed + delta
	if elapsed < district.definition.footstep_interval:
		if awareness != null:
			awareness.footstep_elapsed = elapsed
		else:
			district.player_step_elapsed = elapsed
		return
	if awareness != null:
		awareness.footstep_elapsed = 0.0
	else:
		district.player_step_elapsed = 0.0

	var crouch: C_Crouch = actor.get_component(C_Crouch) as C_Crouch
	var radius: float = district.definition.running_noise_radius if speed > RUNNING_SPEED else district.definition.walking_noise_radius
	if crouch != null and crouch.active:
		radius *= district.definition.crouching_noise_fraction
	NpcPerceptionService.emit_noise(actor, body.global_position + Vector3.UP * NpcPerceptionService.TORSO_HEIGHT, radius, actor.has_component(C_PlayerInputController))
#endregion
