extends RefCounted
## Test-only wiring of real planning, first-contact and scheduled visit owners.
class_name CustomerFlowFixture

#region Real owner wiring
## Installs a missing planning handler in an isolated test/smoke World.
static func install() -> void:
	DialogueUiFixture.install()
	NpcCustomerComposition.install(ECS.world)
	for observer_type: Script in [O_CustomerPlanning, O_CustomerGreeting, O_CustomerServiceClock, O_CustomerOutcomes, O_CustomerNpcInterruption, O_CustomerNpcConversation, O_CustomerInspectionCargo]:
		var installed: bool = false
		for observer: Observer in ECS.world.observers:
			if observer.get_script() == observer_type:
				installed = true
				break
		if not installed:
			ECS.world.add_observer(observer_type.new() as Observer)


## Advances the actual scheduling owner through the fixture's isolated World group.
static func advance(_flow: C_CustomerFlow, _cycle: C_DayCycle, delta: float) -> void:
	install()
	var owner: S_CustomerFlow = null
	for system: System in ECS.world.systems:
		if system is S_CustomerFlow:
			owner = system as S_CustomerFlow
			break
	if owner == null:
		owner = S_CustomerFlow.new()
		owner.group = "customer_fixture"
		ECS.world.add_system(owner)
	for owner_type: Script in [S_CustomerVisitPresence, S_CustomerCleanup, S_CustomerClock, S_CustomerGreeting, S_CustomerApproach, S_CustomerWaiting, S_CustomerInspection, S_CustomerDeparture, S_CustomerArrivals]:
		var installed: bool = false
		for system: System in ECS.world.systems:
			if system.get_script() == owner_type:
				installed = true
				break
		if not installed:
			var phase_owner: System = owner_type.new() as System
			phase_owner.group = owner.group
			ECS.world.add_system(phase_owner, true)
	ECS.world.process(delta, owner.group)


## Uses the real debug action's selection/materialization instead of a legacy spawn API.
static func spawn(_flow: C_CustomerFlow, _cycle: C_DayCycle) -> bool:
	install()
	return DebugWorldService.customer_next().success
## Sends a real first-contact request without advancing unrelated test clocks.
static func greet(customer: E_NpcCharacter) -> void:
	install()
	ECS.world.emit_event(CustomerGreetingRequest.EVENT, customer, CustomerGreetingRequest.new())


## Publishes the same committed perception interval consumed before production BT execution.
static func decision_ready(customer: Entity, delta: float) -> void:
	install()
	ECS.world.emit_event(NpcDecisionReady.EVENT, customer, NpcDecisionReady.new(delta))
#endregion

#region Explicit commands
## Dispatches calendar preparation to the real command owner.
static func plan(flow: C_CustomerFlow, day: int, payment: int) -> void:
	var request: CustomerPlanningRequest = CustomerPlanningRequest.new()
	request.flow = flow
	request.day_index = day
	request.payment = payment
	_dispatch(request)


## Dispatches morning reconciliation with an optional payment endpoint.
static func morning(flow: C_CustomerFlow, cycle: C_DayCycle, wallet: C_Wallet) -> int:
	var request: CustomerPlanningRequest = CustomerPlanningRequest.new()
	request.kind = CustomerPlanningRequest.Kind.RECONCILE_MORNING
	request.flow = flow
	request.cycle = cycle
	request.wallet = wallet
	_dispatch(request)
	return request.affected_visits


## Reconciles due followups after an explicit test-authored calendar change.
static func reactivate(flow: C_CustomerFlow, day: int) -> int:
	var request: CustomerPlanningRequest = CustomerPlanningRequest.new()
	request.kind = CustomerPlanningRequest.Kind.REACTIVATE_FOLLOWUPS
	request.flow = flow
	request.day_index = day
	_dispatch(request)
	return request.affected_visits


static func _dispatch(request: CustomerPlanningRequest) -> void:
	install()
	ECS.world.emit_event(CustomerPlanningRequest.EVENT, null, request)
	assert(request.completed, "Fixture requires the real Observer's PER_CALLBACK flush")
#endregion
