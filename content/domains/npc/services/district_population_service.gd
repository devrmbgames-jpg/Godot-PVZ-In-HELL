extends RefCounted
## Постоянное население; временный уход не создаёт другое тело личности.
class_name DistrictPopulationService

const ADDRESS_PREFAB: String = "res://content/domains/npc/entities/npc_address.tscn"


## Detached construction transaction; never retained as a second population model.
class PopulationBuild extends RefCounted:
	## Fresh unregistered nodes owned only until accepted commit or rejection cleanup.
	var instances: Array[Entity] = []
	## Explicit instance inputs for one whole registration preflight.
	var contexts: Array[EntitySpawnContext] = []
	## Compiler output consumed by the same synchronous transaction.
	var plans: Array[EntityBuildPlan] = []
	## Authored places for initial address label/pose synchronization.
	var address_places: Dictionary[Entity, DEF_DistrictPlace] = { }
	## Fresh or already registered bodies indexed only within this operation.
	var bodies: Dictionary[StringName, E_DistrictNpc] = { }


	## Releases only this transaction's rejected detached instances.
	func discard() -> void:
		for actor: Entity in instances:
			actor.free()
		instances.clear()
		contexts.clear()
		plans.clear()
		address_places.clear()
		bodies.clear()


#region Calendar reconciliation
## Coalesces one reconciliation receipt; O_DistrictLifecycle resolves it inline on PER_CALLBACK
## or later on the configured command-buffer flush. Already reconciled state may return null.
static func reconcile_calendar(world: World, session: Entity) -> DistrictCalendarReconcileRequest:
	var district: C_District = session.get_component(C_District) as C_District
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	var pending: DistrictCalendarReconcileRequest = (
		district.lifecycle_request.get_ref() as DistrictCalendarReconcileRequest
		if district.lifecycle_request != null else null
	)
	if district.lifecycle_day == cycle.day_index and district.lifecycle_phase == int(cycle.phase):
		return pending
	if pending != null and not pending.completed:
		return pending

	var request: DistrictCalendarReconcileRequest = DistrictCalendarReconcileRequest.new()
	request.district = district
	request.cycle = cycle
	request.day_index = cycle.day_index
	request.phase = cycle.phase
	district.lifecycle_request = weakref(request)
	world.emit_event(DistrictCalendarReconcileRequest.EVENT, session, request)
	return request
#endregion


#region Восстановление состояния движка
## Clears transient engine/AI participation before restore or explicit morning preparation.
static func reset_brain(body: E_DistrictNpc) -> void:
	NpcBrainService.set_participating(body, false)
	NpcCommunityService.cancel_activity(body)
	NpcDialogueService.end(body)
	body.request_role_cleanup(NpcRoleCleanupRequest.Kind.RESET_PREPARE)
	CombatService.end_combat(body)
	var motion: C_Motion = body.get_component(C_Motion) as C_Motion
	motion.control_speed_multiplier = 1.0
	NpcAttackExecutionService.cancel(body)
	NpcIntentService.stop(body)
	NpcBloodService.release(body)
	body.request_role_cleanup(NpcRoleCleanupRequest.Kind.RESET_RELEASE)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	awareness.reset_transient_state()
	decision.reset_transient_state()
	var route: C_NpcRoute = body.get_component(C_NpcRoute) as C_NpcRoute
	assert(route != null, "NPC brain reset requires its compiled route capability")
	route.reset_transient_state()
	var gaze: C_NpcGazeFreeze = body.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
	gaze.observed = false
	var pride: C_NpcPride = body.get_component(C_NpcPride) as C_NpcPride
	pride.exposed_toy_id = ""
	var stalking: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	stalking.reset_transient_state()
	var traffic: C_NpcTraffic = body.get_component(C_NpcTraffic) as C_NpcTraffic
	traffic.reset_transient_state()
	for encounter: Relationship in body.relationships.duplicate():
		if encounter.relation is R_NpcBlocking:
			body.remove_relationship(encounter)
	body.sync_gaze_constraint()

	var runner: BTPlayer = body.get_node_or_null("Brain") as BTPlayer
	if runner != null:
		runner.free()


## Восстанавливает участие в движке и представление личности после снимка.
static func restore_participation() -> void:
	var district: C_District = NpcPopulationQueries.current()
	if district == null:
		return

	district.noises.clear()
	district.pending_routes.clear()
	district.decision_cursor = &""
	district.decisions_due = 0
	district.decisions_processed = 0
	district.decisions_deferred = 0
	district.decision_max_wait_ticks = 0
	district.lighting_context = null
	for person: NpcRecord in district.people:
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		if body == null:
			continue

		reset_brain(body)
		# Reused bodies need the same derived immutable tuning as freshly compiled bodies.
		var motion: C_Motion = body.get_component(C_Motion) as C_Motion
		motion.max_speed = person.profile.move_speed * person.variation.move_speed_multiplier
		var receiver: C_ReceiverTraits = body.get_component(C_ReceiverTraits) as C_ReceiverTraits
		receiver.traits = person.profile.receiver_traits
		var gaze: C_NpcGazeFreeze = body.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
		gaze.rule = NpcGazeQueries.selected_rule(person.rules_for())
		var pride: C_NpcPride = body.get_component(C_NpcPride) as C_NpcPride
		pride.rule = NpcPrideRules.selected_rule(person.rules_for())
		var stalking: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
		stalking.rule = NpcStalkingRules.selected_rule(person.rules_for())
		body.present_profile(person.profile)
		body.show_message(person.display_name)
		NpcBrainService.bind_engine(body)
		set_placement(person, body, person.placement, &"snapshot_restored", true)

#endregion


#region Создание населения
## Validates detached address/body recipes before native registration and roster mutation.
## False discards the rejected detached build; true may still have pending morning preparation
## under a deferred Observer flush policy. This is not a completed-calendar receipt.
static func initialize() -> bool:
	var district: C_District = NpcPopulationQueries.current()
	if district == null or district.definition == null:
		return true

	var complete: bool = district.prepared_morning > 0
	for person: NpcRecord in district.people:
		if NpcPopulationQueries.body_for(person.npc_id) == null:
			complete = false
	if complete:
		return true

	var fresh_roster: bool = district.people.is_empty()
	var people: Array[NpcRecord] = (
		NpcPopulationRules.initial_records(
			district.definition,
			district.next_person,
			GameTimeQueries.current().world_seed,
			DayPhaseQueries.current().day_index,
		)
		if fresh_roster
		else district.people
	)
	var build: PopulationBuild = PopulationBuild.new()
	_prepare_addresses(district, build)
	if not _prepare_bodies(district, people, build) or not _validate_build(build):
		build.discard()
		return false

	# Published NPC identities resolve to the accepted authoritative roster immediately.
	if fresh_roster:
		district.people = people
		district.next_person += people.size()
	_commit_build(build)
	_bind_bodies(people, build)
	prepare_morning(1)
	return true


static func _prepare_addresses(district: C_District, build: PopulationBuild) -> void:
	var prefab: PackedScene = load(ADDRESS_PREFAB) as PackedScene
	for place: DEF_DistrictPlace in district.definition.places:
		if place.kind != DEF_DistrictPlace.Kind.HOME:
			continue
		var address: Entity = prefab.instantiate() as Entity
		build.instances.append(address)
		build.address_places[address] = place
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			address,
			ECS.world,
			GECSIO.uuid(),
		)
		NpcConstructionService.configure_address(context, place)
		build.contexts.append(context)


static func _prepare_bodies(
	district: C_District,
	people: Array[NpcRecord],
	build: PopulationBuild,
) -> bool:
	for person: NpcRecord in people:
		if build.bodies.has(person.npc_id):
			return false
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		if body != null:
			build.bodies[person.npc_id] = body
			continue

		# The declared Profile remains the sole scene selector; invalid roots are never published.
		if (
			person.profile == null
			or not ResourceLoader.exists(person.profile.npc_scene_path, "PackedScene")
		):
			return false
		var prefab: PackedScene = load(person.profile.npc_scene_path) as PackedScene
		var instance: Node = prefab.instantiate()
		body = instance as E_DistrictNpc
		if body == null:
			instance.free()
			return false
		build.instances.append(body)
		build.bodies[person.npc_id] = body
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			body,
			ECS.world,
			GECSIO.uuid(),
		)
		NpcConstructionService.configure_context(context, person, district.definition)
		build.contexts.append(context)
	return true


static func _validate_build(build: PopulationBuild) -> bool:
	# Endpoints and stable IDs are checked against the entire detached set plus the live World.
	for context: EntitySpawnContext in build.contexts:
		context.candidate_actors = build.instances.duplicate()
		build.plans.append(EntityCompositionService.build_plan(context))
	return EntityBuildRules.validate_registration_batch(build.contexts, build.plans)


static func _commit_build(build: PopulationBuild) -> void:
	for build_index: int in build.contexts.size():
		var context: EntitySpawnContext = build.contexts[build_index]
		var actor: Entity = context.actor
		ECS.world.get_parent().add_child(actor)
		if build.address_places.has(actor):
			var place: DEF_DistrictPlace = build.address_places[actor]
			NpcConstructionService.present_address(actor, place)
			(actor as Node as Node3D).global_position = NpcPopulationQueries.position_for(place.key)
		else:
			var identity_fields: Dictionary = context.initial_fields[C_NpcIdentity as Script]
			var person: NpcRecord = NpcPopulationQueries.person_for(identity_fields[&"npc_id"])
			var origin: StringName = person.home_id if person.profile.resident else person.portal_id
			(actor as E_DistrictNpc).place_at(NpcPopulationQueries.position_for(origin))
		var registered: bool = EntityCompositionService.register_plan(
			context,
			build.plans[build_index],
			false,
		)
		assert(registered, "Accepted synchronous population batch requires one native registration")


static func _bind_bodies(people: Array[NpcRecord], build: PopulationBuild) -> void:
	for person: NpcRecord in people:
		var body: E_DistrictNpc = build.bodies[person.npc_id]
		body.present_profile(person.profile)
		body.show_message(person.display_name)
		NpcBrainService.bind_engine(body)
#endregion


#region Календарь и участие в мире
## Requests one future morning; completed/succeeded distinguish dispatch from actual preparation.
## O_DistrictLifecycle may complete inline or on flush; an already prepared day is a no-op.
static func prepare_morning(morning_day: int) -> DistrictMorningPreparationRequest:
	var request: DistrictMorningPreparationRequest = DistrictMorningPreparationRequest.new()
	request.day_index = morning_day
	if morning_day <= 0:
		request.completed = true
		request.rejection_reason = &"invalid_day"
		return request

	var district: C_District = NpcPopulationQueries.current()
	if district == null or district.prepared_morning >= morning_day:
		request.completed = true
		request.succeeded = true
		return request
	var session: Entity = ECS.world.query.with_all([C_District, C_DayCycle]).execute_one()
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	request.context_day = cycle.day_index
	request.context_phase = cycle.phase
	ECS.world.emit_event(DistrictMorningPreparationRequest.EVENT, session, request)
	return request


## Captures one record identity and requests phase/placement work from O_DistrictLifecycle.
## Read completed/succeeded after inline execution or its configured flush; dispatch is not success.
static func request_phase(
	body: E_DistrictNpc,
	day_index: int,
	phase: C_DayCycle.Phase,
	synchronize: bool = false,
	force: bool = false,
) -> NpcPhasePlanRequest:
	var request: NpcPhasePlanRequest = NpcPhasePlanRequest.new()
	request.day_index = day_index
	request.phase = phase
	request.synchronize = synchronize
	request.force = force
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	request.record_identity = NpcPopulationQueries.person_for(identity.npc_id)
	ECS.world.emit_event(NpcPhasePlanRequest.EVENT, body, request)
	return request


## Commits placement and native participation synchronously; restore uses the same boundary.
## activation_position is world metres; default INF keeps the pose. Normal activation checks space,
## reconcile_native bypasses that check. False after reentrant callbacks does not roll back history.
static func set_placement(
	person: NpcRecord,
	body: E_DistrictNpc,
	placement: NpcRecord.Placement,
	reason: StringName = &"placement_changed",
	reconcile_native: bool = false,
	activation_position: Vector3 = Vector3(INF, INF, INF),
) -> bool:
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	assert(decision != null, "NPC participation requires its constructed decision capability")
	# GECS reconnects signals after emit; reject nested native transitions until it finishes.
	if decision.participation_committing:
		return false
	var active: bool = placement == NpcRecord.Placement.STREET
	if active and (person.death_day != 0 or body.has_component(C_Death)):
		decision.participation_reason = &"dead_actor"
		return false
	var supplied_position: bool = activation_position != Vector3(INF, INF, INF)
	if supplied_position and not activation_position.is_finite():
		decision.participation_reason = &"invalid_activation_position"
		return false
	var changed: bool = person.placement != placement or body.enabled != active
	var relocating: bool = (
		activation_position.is_finite()
		and not body.global_position.is_equal_approx(activation_position)
	)
	if not changed and not reconcile_native and not relocating:
		return true
	var target_position: Vector3 = (
		body.global_position if not activation_position.is_finite() else activation_position
	)
	if (
		active and (not body.enabled or relocating) and not reconcile_native
		and not NpcActivationSolver.available(body, target_position)
	):
		decision.participation_reason = &"activation_blocked"
		return false

	# Invalidate captured work once before callbacks; repeated mode requests remain idempotent.
	decision.lifecycle_generation += 1
	decision.participation_generation += 1
	decision.scheduled_delta = 0.0
	decision.due_since_tick = -1
	decision.wake_requested = false
	decision.wake_urgent = false
	decision.wake_reason = &""
	decision.participation_reason = reason
	person.placement = placement
	var captured_generation: int = decision.participation_generation
	var captured_world: World = ECS.world
	decision.participation_committing = true
	if activation_position.is_finite():
		body.place_at(activation_position)
	if not active:
		body.request_role_cleanup(NpcRoleCleanupRequest.Kind.SUSPEND)
		NpcCommunityService.cancel_activity(body)
		NpcDialogueService.end(body)
		NpcIntentService.stop(body)
		NpcIntentService.look_along_movement(body)
		CombatService.end_combat(body)
		NpcBrainService.set_participating(body, false)
		if body.enabled:
			ECS.world.disable_entity(body)
	elif not body.enabled:
		ECS.world.enable_entity(body)

	# Native enable/disable signals may synchronously replace this transition.
	decision.participation_committing = false
	if (
		(
			not is_instance_valid(body) or not is_instance_valid(captured_world)
			or ECS.world != captured_world or body.is_queued_for_deletion()
		)
		or not captured_world.entity_to_archetype.has(body)
	):
		return false
	if (
		body.get_component(C_NpcDecision) != decision
		or decision.participation_generation != captured_generation or person.placement != placement
	):
		return false
	# A callback may commit death history while the nested native mode request is locked.
	if person.death_day != 0 and placement != NpcRecord.Placement.DEAD:
		set_placement(person, body, NpcRecord.Placement.DEAD, &"death_during_transition")
		return false
	if active and body.has_component(C_Death):
		mark_dead(person, body, DayPhaseQueries.current().day_index)
		return false
	NpcBrainService.set_participating(body, active)
	body.set_participating(active)
	if placement == NpcRecord.Placement.DEAD:
		body.sync_death_presentation()
	elif active:
		NpcDecisionService.request_wake(body, &"reactivated")
	return true


## Один раз фиксирует смерть; будущие заказы не используют погибшую личность.
static func mark_dead(person: NpcRecord, body: E_DistrictNpc, day_index: int) -> void:
	if person.death_day != 0:
		return

	NpcRemainsService.release(body)
	body.request_role_cleanup(NpcRoleCleanupRequest.Kind.DEATH, day_index)
	person.death_day = day_index
	person.phase_complete = true
	set_placement(person, body, NpcRecord.Placement.DEAD)
	var district: C_District = NpcPopulationQueries.current()
	var living_residents: int = 0
	for other: NpcRecord in district.people:
		if other.profile.resident and other.death_day == 0:
			living_residents += 1
	if (
		district.replacement_morning == 0
		and district.definition.resident_count - living_residents
		>= district.definition.replacement_threshold
	):
		district.replacement_morning = day_index + district.definition.replacement_delay_days


## Materializes one bounded replacement wave for an explicitly supplied future morning.
static func replace_vacancies(district: C_District, morning_day: int) -> void:
	var locals_alive: int = 0
	var outside_alive: int = 0
	var vacant: NpcRecord = null
	for person: NpcRecord in district.people:
		if person.death_day == 0:
			if person.profile.resident:
				locals_alive += 1
			else:
				outside_alive += 1
		elif person.profile.resident and not person.home_id.is_empty():
			if vacant == null or person.profile.merchant:
				vacant = person
	if (
		district.replacement_morning > 0 and morning_day >= district.replacement_morning
		and locals_alive < district.definition.resident_count and vacant != null
	):
		if _replace_person(district, vacant, morning_day):
			locals_alive += 1
			district.replacement_morning = (
				morning_day + 1 if locals_alive < district.definition.resident_count else 0
			)
	if outside_alive < district.definition.visitor_count:
		for person: NpcRecord in district.people:
			if (
				not person.profile.resident and person.death_day > 0
				and morning_day >= person.death_day + district.definition.replacement_delay_days
				and not person.portal_id.is_empty()
			):
				_replace_person(district, person, morning_day)
				break


static func _replace_person(district: C_District, deceased: NpcRecord, morning_day: int) -> bool:
	var replacement: NpcRecord = NpcRecord.new()
	replacement.npc_id = StringName("npc/%d" % district.next_person)
	var pool: Array[DEF_NpcArchetype] = []
	var initiators: int = 0
	for person: NpcRecord in district.people:
		if person.death_day == 0 and person.profile.resident and person.profile.initiates_conflicts:
			initiators += 1
	for candidate: DEF_NpcArchetype in district.definition.profiles:
		if (
			candidate.resident == deceased.profile.resident
			and candidate.merchant == deceased.profile.merchant and candidate.valid_rules()
			and (
				not candidate.initiates_conflicts
				or initiators < district.definition.maximum_conflict_initiators
			)
		):
			pool.append(candidate)
	replacement.profile = deceased.profile
	if not pool.is_empty():
		pool.sort_custom(
			func(a: DEF_NpcArchetype, b: DEF_NpcArchetype) -> bool:
				return String(a.key) < String(b.key),
		)
		var random: RandomNumberGenerator = GameTimeQueries.decision(
			String(replacement.npc_id),
			morning_day,
			"npc/replacement_profile",
		)
		replacement.profile = pool[random.randi_range(0, pool.size() - 1)]

	replacement.variation = NpcVariationRules.create(
		replacement.profile,
		GameTimeQueries.current().world_seed,
		replacement.npc_id,
		morning_day,
	)
	replacement.recipient_key = deceased.recipient_key
	replacement.home_id = deceased.home_id
	replacement.portal_id = deceased.portal_id
	replacement.exit_id = deceased.exit_id
	var build: PopulationBuild = PopulationBuild.new()
	if not _prepare_bodies(district, [replacement], build) or not _validate_build(build):
		build.discard()
		return false

	district.next_person += 1
	deceased.home_id = &""
	deceased.portal_id = &""
	district.people.append(replacement)
	_commit_build(build)
	_bind_bodies([replacement], build)
	return true

#endregion
