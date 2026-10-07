extends Observer
## Requests one authored autonomous floor effect after actual challenge activation, without polling.
class_name O_ChallengeFloorActivation

#region Committed activation reaction
## Selects floor-capable bodies receiving a committed activation fact.
func query() -> QueryBuilder:
	return q.with_all([C_Challenge, C_FloorChallenge]).on_event(ChallengeActivated.EVENT)


## Captures current session/capability identity and immutable Definition before deferred setup.
func each(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	var activated: ChallengeActivated = payload as ChallengeActivated
	assert(activated != null)
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	var floor: C_FloorChallenge = subject.get_component(C_FloorChallenge) as C_FloorChallenge
	cmd.add_custom(_prepare.bind(subject, state, floor, activated.definition))


func _prepare(subject: Entity, state: C_Challenge, floor: C_FloorChallenge, definition: DEF_Challenge) -> void:
	if not EntityAvailability.contains(subject, _world) or subject.get_component(C_Challenge) != state \
			or subject.get_component(C_FloorChallenge) != floor:
		return
	if state.phase != C_Challenge.Phase.ACTIVE or state.definition != definition:
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
	# Floor sessions/effects are transient; replacement must not accept an older queued factory result.
	floor.spawn_request_id = "%s/challenge/%s/%d" % [subject.id, state.definition.key, state.get_instance_id()]
	request.request_id = floor.spawn_request_id
	request.scene = rule.hazard_scene
	request.world_pose = Transform3D(Basis.IDENTITY, rule.world_position)
	if not HazardSpawnService.submit(request):
		ChallengeService.cancel(subject)


#endregion
