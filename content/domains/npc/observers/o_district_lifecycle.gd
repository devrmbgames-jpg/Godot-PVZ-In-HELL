extends Observer
## Owns district calendar goals, preparation and completion reactions; physical operations stay explicit.
class_name O_DistrictLifecycle


#region Reactive boundaries
## Declares calendar, body-death and sole-handler planning/preparation/completion inputs.
func sub_observers() -> Array[Array]:
	return [
		[q.with_all([C_District, C_DayCycle]).on_event(DayPhaseChanged.EVENT), _on_day],
		[q.with_all([C_NpcIdentity, C_Death]).on_match(), _on_death],
		[q.with_all([C_District, C_DayCycle]).on_event(DistrictMorningPreparationRequest.EVENT), _on_morning],
		[q.with_all([C_NpcIdentity]).on_event(NpcPhasePlanRequest.EVENT), _on_plan],
		[q.with_all([C_NpcIdentity]).on_event(NpcScheduleCompletionRequest.EVENT), _on_completion],
	]


func _on_day(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var fact: DayPhaseChanged = payload as DayPhaseChanged
	assert(fact != null)
	var captured_district: C_District = session.get_component(C_District) as C_District
	var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	cmd.add_custom(_reconcile_day.bind(weakref(session), fact, captured_district, captured_cycle))


func _on_death(_event: Variant, body: Entity, _payload: Variant = null) -> void:
	cmd.add_custom(_reconcile_death.bind(weakref(body)))


func _on_morning(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var request: DistrictMorningPreparationRequest = payload as DistrictMorningPreparationRequest
	assert(request != null)
	cmd.add_custom(_prepare_morning.bind(weakref(session), request))


func _on_plan(_event: Variant, body: Entity, payload: Variant = null) -> void:
	var request: NpcPhasePlanRequest = payload as NpcPhasePlanRequest
	assert(request != null)
	cmd.add_custom(_execute_plan.bind(weakref(body), request))


func _on_completion(_event: Variant, body: Entity, payload: Variant = null) -> void:
	var request: NpcScheduleCompletionRequest = payload as NpcScheduleCompletionRequest
	assert(request != null)
	cmd.add_custom(_complete_phase.bind(weakref(body), request))
#endregion


#region Calendar and death reconciliation
func _reconcile_day(
	session_reference: WeakRef,
	fact: DayPhaseChanged,
	captured_district: C_District,
	captured_cycle: C_DayCycle,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) \
			or session.get_component(C_District) != captured_district \
			or session.get_component(C_DayCycle) != captured_cycle:
		return

	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if cycle.day_index != fact.day_index or cycle.phase != fact.phase:
		return
	var district: C_District = session.get_component(C_District) as C_District
	if district.lifecycle_day == fact.day_index and district.lifecycle_phase == int(fact.phase):
		return
	if district.definition != null and fact.phase != C_DayCycle.Phase.NIGHT:
		var phase_key: StringName = StringName("%d/%d" % [fact.day_index, fact.phase])
		if district.conflict_phase != phase_key:
			district.conflict_phase = phase_key
			district.ambient_conflicts = 0

		for person: NpcRecord in district.people.duplicate():
			var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
			if body == null or person.death_day != 0:
				continue
			if body.has_component(C_Death):
				DistrictPopulationService.mark_dead(person, body, fact.day_index)
			elif not body.has_active_role():
				_plan_phase(district, person, body, fact.day_index, fact.phase)

	district.lifecycle_day = fact.day_index
	district.lifecycle_phase = int(fact.phase)


func _reconcile_death(entity_reference: WeakRef) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not _retains_body(entity):
		return
	var cycle: C_DayCycle = DayPhaseQueries.current()
	# Night preserves the existing reconciliation boundary; morning entry handles its bodies.
	if cycle.phase == C_DayCycle.Phase.NIGHT:
		return
	var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	if person != null:
		DistrictPopulationService.mark_dead(person, entity as E_DistrictNpc, cycle.day_index)
#endregion


#region Explicit preparation and goal assignment
func _prepare_morning(
	session_reference: WeakRef,
	request: DistrictMorningPreparationRequest,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if request.completed:
		return
	if not EntityAvailability.contains(session, _world):
		request.rejection_reason = &"session_unavailable"
	elif request.day_index <= 0:
		request.rejection_reason = &"invalid_day"
	else:
		var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		if cycle.day_index != request.context_day or cycle.phase != request.context_phase:
			request.rejection_reason = &"stale_calendar"
			request.completed = true
			return

		var district: C_District = session.get_component(C_District) as C_District
		if district.prepared_morning < request.day_index:
			district.noises.clear()
			district.pending_routes.clear()
			district.lighting_context = null
			DistrictPopulationService.replace_vacancies(district, request.day_index)

			for person: NpcRecord in district.people:
				if person.death_day != 0:
					continue
				var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
				if body == null:
					continue
				DistrictPopulationService.reset_brain(body)
				NpcBrainService.bind_engine(body)
				_plan_phase(
					district,
					person,
					body,
					request.day_index,
					C_DayCycle.Phase.MORNING,
					true,
				)
			district.prepared_morning = request.day_index
			_world.emit_event(
				DistrictMorningPrepared.EVENT,
				session,
				DistrictMorningPrepared.new(district, cycle, request.day_index),
			)
		request.succeeded = true
	request.completed = true


func _execute_plan(entity_reference: WeakRef, request: NpcPhasePlanRequest) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if request.completed:
		return
	if not _retains_body(entity):
		request.rejection_reason = &"body_unavailable"
	else:
		var body: E_DistrictNpc = entity as E_DistrictNpc
		var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
		var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
		if person == null or person.death_day != 0 or body.has_component(C_Death):
			request.rejection_reason = &"npc_unavailable"
		elif person != request.record_identity:
			request.rejection_reason = &"stale_record"
		elif request.day_index <= 0:
			request.rejection_reason = &"invalid_day"
		elif request.phase not in C_DayCycle.Phase.values():
			request.rejection_reason = &"invalid_phase"
		else:
			_plan_phase(
				NpcPopulationQueries.current(),
				person,
				body,
				request.day_index,
				request.phase,
				request.synchronize,
				request.force,
			)
			request.succeeded = true
	request.completed = true


func _plan_phase(
	district: C_District,
	person: NpcRecord,
	body: E_DistrictNpc,
	day: int,
	phase: C_DayCycle.Phase,
	synchronize: bool = false,
	force: bool = false,
) -> void:
	var already_planned: bool = person.planned_day == day and person.planned_phase == int(phase)
	if person.death_day != 0:
		return
	if already_planned and not synchronize and not force:
		# Explicit retries reconcile a blocked arrival without assigning the obligation twice.
		_try_arrival(person, body, person.profile.schedule.location_for(day, phase))
		return

	# Commit the new macro goal and reset only phase-scoped reaction state.
	NpcScheduleActionService.cancel_schedule(body, &"obligation_replaced")
	person.planned_day = day
	person.planned_phase = int(phase)
	person.phase_complete = false
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null:
		awareness.called_out = false
		awareness.warned_rules.clear()
		awareness.reacted_rules.clear()
		awareness.rule_exposure.clear()

	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(day, phase)
	person.goal_id = NpcScheduleRules.goal_for(
		district.definition,
		person,
		location,
		GameTimeQueries.current().world_seed,
		day,
		phase,
	)
	NpcDecisionService.request_wake(body, &"obligation_changed", true)

	# Synchronization teleports at preparation; ordinary transitions preserve native travel.
	if synchronize:
		var preparation_position: Vector3 = NpcPopulationQueries.position_for(
			person.home_id if person.profile.resident else person.portal_id
		)
		var placement: NpcRecord.Placement = NpcRecord.Placement.STREET
		if location == DEF_NpcSchedule.Location.HOME:
			placement = NpcRecord.Placement.HOME
		elif location == DEF_NpcSchedule.Location.OUTSIDE:
			placement = NpcRecord.Placement.OUTSIDE
		DistrictPopulationService.set_placement(
			person,
			body,
			placement,
			&"phase_preparation",
			false,
			preparation_position,
		)
	else:
		_try_arrival(person, body, location)


func _try_arrival(
	person: NpcRecord,
	body: E_DistrictNpc,
	location: DEF_NpcSchedule.Location,
) -> void:
	if (
		location == DEF_NpcSchedule.Location.STREET
		and person.placement != NpcRecord.Placement.STREET
	):
		var arrival_position: Vector3 = NpcPopulationQueries.position_for(
			person.home_id if person.placement == NpcRecord.Placement.HOME else person.portal_id
		)
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"phase_arrival",
			false,
			arrival_position,
		)
#endregion


#region Captured goal completion
func _complete_phase(entity_reference: WeakRef, request: NpcScheduleCompletionRequest) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if request.completed:
		return
	if not _retains_body(entity):
		request.rejection_reason = &"body_unavailable"
	else:
		var body: E_DistrictNpc = entity as E_DistrictNpc
		var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
		var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
		var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
		if person == null or person.death_day != 0 or body.has_component(C_Death):
			request.rejection_reason = &"npc_unavailable"
		elif person != request.record_identity:
			request.rejection_reason = &"stale_record"
		elif body.has_active_role():
			request.rejection_reason = &"service_role_active"
		elif (
			request.action_generation != 0
			and (
				decision != request.decision_identity
				or decision.action_generation != request.action_generation
				or decision.action_status != C_NpcDecision.ActionStatus.RUNNING
			)
		):
			request.rejection_reason = &"stale_action"
		elif (
			request.decision_owner != C_NpcDecision.Owner.NONE
			and (decision == null or decision.intent_owner != request.decision_owner)
		):
			request.rejection_reason = &"decision_interrupted"
		elif request.placement == NpcRecord.Placement.DEAD:
			request.rejection_reason = &"invalid_placement"
		elif (
			person.planned_day != request.planned_day
			or person.planned_phase != request.planned_phase or person.goal_id != request.goal_id
		):
			request.rejection_reason = &"stale_goal"
		else:
			person.phase_complete = true
			if request.action_generation != 0:
				NpcScheduleActionService.finish_schedule(
					body,
					request.action_generation,
					true,
					&"obligation_completed",
				)
			if person.placement != request.placement:
				DistrictPopulationService.set_placement(person, body, request.placement)
			request.succeeded = true
		if (
			not request.succeeded and request.action_generation != 0
			and decision == request.decision_identity
		):
			NpcScheduleActionService.finish_schedule(
				body,
				request.action_generation,
				false,
				request.rejection_reason,
			)
	request.completed = true
#endregion


#region Queued body lifetime
func _retains_body(candidate: Variant) -> bool:
	# Goal assignment may reactivate a retained dormant body after the command boundary.
	if not is_instance_valid(candidate) or not candidate is E_DistrictNpc:
		return false
	var body: E_DistrictNpc = candidate as E_DistrictNpc
	return (
		body.is_inside_tree() and not body.is_queued_for_deletion() \
				and _world.entity_to_archetype.has(body)
		and body.has_component(C_NpcIdentity)
	)
#endregion
