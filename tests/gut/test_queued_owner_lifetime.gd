extends GutTest
## Exercises real queued owners after free, replacement, and expired optional command ownership.

var _world: World

#region Buffered World fixtures
## Keeps production command buffers pending until the test's explicit lifetime boundary.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world


## Releases the isolated World and global lookup without leaving pending work.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _entity(components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.component_resources = components
	_world.add_entity(entity)
	return entity


func _owner(owner_type: Script) -> System:
	var queued_owner: System = owner_type.new() as System
	queued_owner.group = "lifetime_fixture"
	queued_owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(queued_owner)
	return queued_owner


func _free_before_flush(owner_type: Script, components: Array[Component]) -> void:
	var subject: Entity = _entity(components)
	var queued_owner: System = _owner(owner_type)
	_world.process(0.1, queued_owner.group)
	assert_eq(queued_owner.cmd.size(), 1, "Production query/process must actually queue one operation")

	_world.remove_entity(subject)
	subject.free()
	_world.flush_command_buffers()
	assert_false(queued_owner.has_pending_commands(), "Freed queued_owner must be consumed without an engine argument error")
	_world.remove_system(queued_owner)
	queued_owner.free()


func _observer(observer_type: Script) -> Observer:
	var queued_owner: Observer = observer_type.new() as Observer
	queued_owner.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(queued_owner)
	return queued_owner
#endregion

#region Scheduled queued_owner lifetime
## Runs the production query and enqueue paths for combat, challenge and interaction owners.
func test_scheduled_combat_challenge_and_input_owners_survive_free_before_flush() -> void:
	_free_before_flush(S_ChallengeRuntime, [C_Challenge.new()])
	_free_before_flush(S_CombatProjectile, [C_CombatProjectile.new()])
	_free_before_flush(S_NpcCombat, [C_NpcCombat.new()])
	_free_before_flush(S_PlayerMelee, [C_Combat.new()])
	_free_before_flush(S_FloorHazard, [C_Hazard.new(), C_FloorHazard.new()])
	_free_before_flush(S_InteractionInput, [C_Controller.new(), C_Interactor.new(), C_GrabControl.new()])
	var marker: C_Marker = C_Marker.new()
	marker.capture_token = 1
	_free_before_flush(S_Marker, [marker])


## Every isolated phase queued_owner rejects an appearance removed after its query snapshot.
func test_customer_phase_owners_survive_free_before_flush() -> void:
	for owner_type: Script in [S_CustomerClock, S_CustomerGreeting, S_CustomerCleanup, S_CustomerCombat,
			S_CustomerApproach, S_CustomerDeparture, S_CustomerInspection, S_CustomerWaiting]:
		var agent: C_CustomerAgent = C_CustomerAgent.new()
		if owner_type == S_CustomerDeparture:
			agent.phase = C_CustomerAgent.Phase.LEAVING
		elif owner_type == S_CustomerInspection:
			agent.phase = C_CustomerAgent.Phase.INSPECTING
		elif owner_type == S_CustomerWaiting:
			agent.phase = C_CustomerAgent.Phase.WAITING
		agent.scheduled_phase = int(agent.phase)
		_free_before_flush(owner_type, [agent, C_NpcCombat.new()])


## Session queues cannot accidentally treat a freed runtime session as an ownerless data fixture.
func test_customer_and_district_session_owners_survive_free_before_flush() -> void:
	for owner_type: Script in [S_CustomerFlow, S_CustomerArrivals]:
		_free_before_flush(owner_type, [C_CustomerFlow.new(), C_DayCycle.new()])
	for owner_type: Script in [S_District, S_NpcCadence, S_NpcFootsteps, S_NpcNoise, S_NpcRoutePlanning]:
		_free_before_flush(owner_type, [C_District.new(), C_DayCycle.new()])


## Due AI stages cannot dereference a body freed between their snapshot and commit.
func test_due_npc_stage_owners_survive_free_before_flush() -> void:
	for owner_type: Script in [S_NpcPerception, S_NpcTraits, S_NpcDecision, S_NpcRoute]:
		var decision: C_NpcDecision = C_NpcDecision.new()
		decision.scheduled_delta = 0.1
		_free_before_flush(owner_type, [C_NpcIdentity.new(), C_NpcAwareness.new(), C_NpcIntent.new(), decision])


## Explosion resolution and TTL retirement both tolerate removal before structural commit.
func test_hazard_terminal_owners_survive_free_before_flush() -> void:
	var lifetime: C_HazardLifetime = C_HazardLifetime.new()
	lifetime.remaining_seconds = 1.0
	_free_before_flush(S_Explosion, [C_Hazard.new(), C_Explosion.new(), lifetime])
	_free_before_flush(S_HazardLifetime, [C_Hazard.new(), C_HazardLifetime.new()])


## Replaced combat state must remain untouched when an older queued strike flushes.
func test_replaced_combat_component_rejects_queued_strike() -> void:
	var actor: Entity = _entity([C_Combat.new()])
	var queued_owner: System = _owner(S_PlayerMelee)
	_world.process(0.1, queued_owner.group)
	assert_eq(queued_owner.cmd.size(), 1)
	var replacement: C_Combat = C_Combat.new()
	actor.remove_component(C_Combat)
	actor.add_component(replacement)
	_world.flush_command_buffers()
	assert_eq(replacement.execution_generation, 0)
	assert_false(queued_owner.has_pending_commands())


## A role can end while its body remains registered; its old clock must not use a missing Component.
func test_customer_clock_rejects_role_removed_before_flush() -> void:
	var agent: C_CustomerAgent = C_CustomerAgent.new()
	var customer: Entity = _entity([agent])
	var queued_owner: System = _owner(S_CustomerClock)
	_world.process(0.1, queued_owner.group)
	assert_eq(queued_owner.cmd.size(), 1)
	customer.remove_component(C_CustomerAgent)
	_world.flush_command_buffers()
	assert_eq(agent.elapsed, 0.0)
	assert_false(queued_owner.has_pending_commands())


## Damage queued for the old package aggregate cannot destroy a replacement aggregate on the same body.
func test_damage_reaction_rejects_replaced_package_state() -> void:
	var subject: Entity = _entity([C_PackageState.new()])
	var observer: Observer = _observer(O_PackageDamage)
	var result: DamageResult = DamageResult.new()
	result.request = DamageRequest.new()
	result.request.target = subject
	result.outcome = DamageResult.Outcome.HEALTH_DEPLETED
	result.applied_amount = 1.0
	_world.emit_event(DamageResult.EVENT, subject, result)
	assert_eq(observer.cmd.size(), 1)

	var replacement: C_PackageState = C_PackageState.new()
	subject.remove_component(C_PackageState)
	subject.add_component(replacement)
	_world.flush_command_buffers()
	assert_eq(replacement.damage, C_PackageState.Damage.UNDAMAGED)
	assert_false(observer.has_pending_commands())
#endregion

#region Reactive queued_owner lifetime
## A runtime planning receipt rejects an expired session instead of planning detached state.
func test_planning_command_rejects_expired_runtime_owner() -> void:
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	var session: Entity = _entity([flow, C_DayCycle.new()])
	var observer: Observer = _observer(O_CustomerPlanning)
	var request: CustomerPlanningRequest = CustomerPlanningRequest.new()
	request.flow = flow
	request.day_index = 1
	_world.emit_event(CustomerPlanningRequest.EVENT, session, request)
	assert_eq(observer.cmd.size(), 1)
	assert_false(request.completed)

	_world.remove_entity(session)
	session.free()
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"session_unavailable")
	assert_true(flow.visits.is_empty())


## Health reactions use committed Resource payloads without binding their target as a typed argument.
func test_damage_reactions_survive_free_before_flush() -> void:
	for observer_type: Script in [O_HealthLifecycle, O_PackageDamage, O_NpcRemains, O_RemoveOnHealthDepleted]:
		var subject: Entity = _entity([C_Living.new(), C_PackageState.new(), C_NpcRemains.new(), C_RemoveOnHealthDepleted.new()])
		var observer: Observer = _observer(observer_type)
		var result: DamageResult = DamageResult.new()
		result.request = DamageRequest.new()
		result.request.target = subject
		result.outcome = DamageResult.Outcome.HEALTH_DEPLETED
		result.applied_amount = 1.0
		_world.emit_event(DamageResult.EVENT, subject, result)
		assert_eq(observer.cmd.size(), 1)

		_world.remove_entity(subject)
		subject.free()
		_world.flush_command_buffers()
		assert_false(observer.has_pending_commands())
		_world.remove_observer(observer)
		observer.free()


## Each invalid relationship queues a structural removal safe after the relationship queued_owner is freed.
func test_relationship_rejection_survives_free_before_flush() -> void:
	var target: Entity = _entity([])
	var relations: Array[Script] = [R_HeldBy, R_PushedBy, R_CartCargo, R_CartDrivenBy, R_StoredIn]
	var observers: Array[Script] = [O_GrabLifecycle, O_PushLifecycle, O_CartLifecycle, O_CartLifecycle, O_PhysicalSlotLifecycle]
	for index: int in relations.size():
		var subject: Entity = _entity([])
		var observer: Observer = _observer(observers[index])
		var relation: Resource = relations[index].new() as Resource
		subject.add_relationship(Relationship.new(relation, target))
		assert_eq(observer.cmd.size(), 1)

		_world.remove_entity(subject)
		subject.free()
		_world.flush_command_buffers()
		assert_false(observer.has_pending_commands())
		_world.remove_observer(observer)
		observer.free()


## A pending removal identifies the original Relationship instead of pattern-matching its replacement.
func test_old_relationship_rejection_does_not_remove_replacement() -> void:
	var target: Entity = _entity([])
	var subject: Entity = _entity([])
	var observer: Observer = _observer(O_CartLifecycle)
	var old_binding: Relationship = Relationship.new(R_CartDrivenBy.new(), target)
	subject.add_relationship(old_binding)
	assert_eq(observer.cmd.size(), 1)

	# Stop new dispatch only: the original pending command still flushes normally.
	observer.active = false
	subject.remove_relationship(old_binding)
	var replacement: Relationship = Relationship.new(old_binding.relation, target)
	subject.add_relationship(replacement)
	_world.flush_command_buffers()
	assert_true(subject.relationships.has(replacement))
	assert_false(observer.has_pending_commands())


## A committed opening retains attribution and releases once after its optional initiator is freed.
func test_contents_release_retains_freed_initiator_identity() -> void:
	var queue: C_LootDrops = C_LootDrops.new()
	_entity([queue, C_DayCycle.new()])
	var actor: Entity = _entity([])
	var actor_id: String = actor.id
	var parcel: E_Package = (load("res://content/entities/packages/test_bread.tscn") as PackedScene).instantiate() as E_Package
	_world.add_entity(parcel)
	(parcel.get_component(C_PackageState) as C_PackageState).opening = C_PackageState.Opening.OPENED
	var observer: Observer = _observer(O_PackageContents)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.Opened, actor)
	assert_eq(observer.cmd.size(), 1)

	_world.remove_entity(actor)
	actor.free()
	_world.flush_command_buffers()
	assert_true((parcel.get_component(C_PackageContents) as C_PackageContents).released)
	# With no authored support surface, actual placement is pending, preserving the terminal context.
	assert_gt(queue.pending.size(), 0)
	for record: PendingLootDrop in queue.pending:
		assert_eq(record.actor_id, actor_id)
	assert_false(observer.has_pending_commands())
#endregion
