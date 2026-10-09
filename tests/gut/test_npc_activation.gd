extends "res://tests/gut/test_district_population.gd"
## Native blocked arrivals and retirement of transient sessions on the retained actor.


## Minimal affordance keeps the actual reservation owner in the cleanup fixture.
class ReservationAction extends DEF_InteractionAction:
	#region Affordance contract
	func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		return true
	#endregion


#region Activation geometry
## An explicit phase retry reconciles arrival without replacing the accepted calendar goal.
func test_blocked_phase_arrival_retries_without_replanning_or_false_completion() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.HOME)
	var target: Vector3 = NpcPopulationQueries.position_for(person.home_id)
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE * 3.0
	collision.shape = box
	blocker.add_child(collision)
	_root.add_child(blocker)
	blocker.global_position = target + Vector3.UP
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(DistrictPopulationService.request_phase(body, 2, phase).succeeded)
	assert_false(body.enabled)
	assert_false(person.phase_complete)
	assert_true(NpcDecisionDiagnostics.actor_state(body)["pending_arrival"])
	var goal: StringName = person.goal_id
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var action_generation: int = decision.action_generation
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"test/blocked_arrival"
	visit.customer_id = person.npc_id
	assert_false(NpcServiceRole.begin(body, person, visit, 2))
	assert_false(visit.started)
	assert_eq(visit.visit_count, 0)
	assert_false(body.has_component(C_CustomerAgent))
	blocker.free()
	await get_tree().physics_frame
	assert_true(DistrictPopulationService.request_phase(body, 2, phase).succeeded)
	assert_true(body.enabled)
	assert_eq(person.goal_id, goal)
	assert_eq(decision.action_generation, action_generation)
	assert_false(person.phase_complete)
	assert_false(NpcDecisionDiagnostics.actor_state(body)["pending_arrival"])
	assert_true(NpcServiceRole.begin(body, person, visit, 2))
	assert_true(visit.started)
	assert_eq(visit.visit_count, 1)


## A native collider rejects once without moving the dormant body or completing its obligation.
func test_blocked_activation_preserves_state_and_explicit_retry_uses_same_body() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	var old_pose: Vector3 = body.global_position
	var old_id: String = body.id
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.participation_generation
	var target: Vector3 = Vector3(-20.0, 0.0, 0.0)
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE * 3.0
	collision.shape = box
	blocker.add_child(collision)
	_root.add_child(blocker)
	blocker.global_position = target + Vector3.UP
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"test_arrival",
			false,
			target,
		)
	)
	assert_eq(decision.participation_reason, &"activation_blocked")
	assert_eq(decision.participation_generation, generation)
	assert_eq(person.placement, NpcRecord.Placement.OUTSIDE)
	assert_false(person.phase_complete)
	assert_eq(body.global_position, old_pose)
	assert_false(body.enabled)
	assert_false((body.get_node("Brain") as BTPlayer).active)
	blocker.free()
	await get_tree().physics_frame
	assert_true(
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"test_retry",
			false,
			target,
		)
	)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
	assert_eq(body.id, old_id)
	assert_eq(body.global_position, target)
	assert_true(body.enabled)
	assert_false(body.freeze)
	assert_eq(decision.participation_generation, generation + 1)


## Invalid explicit poses cannot fall back to the body's previous valid position.
func test_nonfinite_activation_pose_rejects_before_transition() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.participation_generation
	for invalid: Vector3 in [Vector3(NAN, 0.0, 0.0), Vector3(INF, 0.0, 0.0)]:
		assert_false(
			DistrictPopulationService.set_placement(
				person,
				body,
				NpcRecord.Placement.STREET,
				&"invalid",
				false,
				invalid,
			)
		)
		assert_eq(decision.participation_reason, &"invalid_activation_position")
		assert_eq(decision.participation_generation, generation)
		assert_false(body.enabled)


## Actual death during native enable supersedes reactivation before physics/AI can resume.
func test_death_inside_enable_does_not_publish_active_participation() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	var callback: Callable = func(candidate: Entity) -> void:
		if candidate == body:
			body.add_component(C_Death.new())
	_world.entity_enabled.connect(callback)
	assert_false(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET))
	_world.entity_enabled.disconnect(callback)
	assert_eq(person.placement, NpcRecord.Placement.DEAD)
	assert_gt(person.death_day, 0)
	assert_false(body.enabled)
	assert_true(body.freeze)
	assert_false((body.get_node("Brain") as BTPlayer).active)
#endregion


#region Native session cleanup
## Suspending the actual holder releases the live grip, collision exception and input capture.
func test_dormancy_releases_actual_hold_without_deleting_the_item() -> void:
	_world.add_observer(O_GrabLifecycle.new())
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	body.add_component(C_GrabControl.new())
	body.add_component(C_CarryLoad.new())
	body.add_component(C_Strength.new())
	var anchor: Marker3D = Marker3D.new()
	body.add_child(anchor)
	body.hold_anchor = anchor
	var item_body: RigidBody3D = RigidBody3D.new()
	item_body.set_script(E_GrabbableBody)
	item_body.gravity_scale = 0.0
	item_body.mass = 5.0
	var item: Entity = item_body as Node as Entity
	item.component_resources = [C_Grabbable.new()]
	_world.add_entity(item)
	var data: R_HeldBy = R_HeldBy.new()
	data.slot = C_Grabbable.HoldSlot.CARRY
	item.add_relationship(Relationship.new(data, body))
	assert_true(data.lifecycle_applied)
	assert_same(GrabQueries.held_in_slot(body, C_Grabbable.HoldSlot.CARRY), item)
	assert_eq(InteractionControlFocus.current(body), InteractionControlFocus.Priority.CARRY)
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE))
	assert_null(GrabQueries.held_relationship(item))
	assert_null(GrabQueries.held_in_slot(body, C_Grabbable.HoldSlot.CARRY))
	assert_eq(InteractionControlFocus.current(body), InteractionControlFocus.Priority.HANDS)
	assert_false((body.get_component(C_CarryLoad) as C_CarryLoad).active)
	assert_false(item_body.get_collision_exceptions().has(body))
	assert_true(_world.entity_to_archetype.has(item))


## Departure retires real combat/dialogue/slot bindings while preserving durable identity.
func test_dormancy_retires_combat_dialogue_and_smart_object_session() -> void:
	_world.add_observer(O_SmartObject.new())
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	body.add_component(C_GrabControl.new())
	var peer: Entity = Entity.new()
	_world.add_entity(peer)
	assert_true(NpcDialogueService.begin(peer, body))
	assert_true(CombatService.bind_target(body, peer))
	var object: Entity = _reservation_object()
	var receipt: SmartObjectReceipt = SmartObjectService.submit(
		SmartObjectRequest.Operation.ACQUIRE,
		body,
		object,
		&"service",
	)
	assert_eq(receipt.status, SmartObjectReceipt.Status.ACQUIRED)
	assert_eq(body.relationships.size(), 3)
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE))
	assert_null(NpcDialogueService.participant(body))
	assert_null(CombatQueries.target_for(body))
	assert_true(body.relationships.is_empty())
	var second: SmartObjectReceipt = SmartObjectService.submit(
		SmartObjectRequest.Operation.ACQUIRE,
		peer,
		object,
		&"service",
	)
	assert_eq(second.status, SmartObjectReceipt.Status.ACQUIRED)


func _reservation_object() -> Entity:
	var object: Entity = Entity.new()
	var marker: Marker3D = Marker3D.new()
	marker.name = "ServiceMarker"
	object.add_child(marker)
	var slot: DEF_SmartSlot = DEF_SmartSlot.new()
	slot.slot_id = &"service"
	slot.marker = NodePath("ServiceMarker")
	var affordance: DEF_SmartAffordance = DEF_SmartAffordance.new()
	affordance.affordance_id = &"service"
	affordance.slot_id = &"service"
	affordance.executor = ReservationAction.new()
	var definition: DEF_SmartObject = DEF_SmartObject.new()
	definition.slots = [slot]
	definition.affordances = [affordance]
	var capability: C_SmartObject = C_SmartObject.new()
	capability.definition = definition
	object.component_resources = [capability]
	_world.add_entity(object)
	return object
#endregion
