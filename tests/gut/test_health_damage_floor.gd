extends GutTest
## Exercises opt-in nonlethal bounds at the real deferred damage calculation and result boundary.

var _world: World
var _target: Entity
var _health: C_Health
var _damage: O_Damage
var _probe: ResultProbe


class ResultProbe:
	extends Observer

	var results: Array[DamageResult] = []


	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		results.append(payload as DamageResult)


#region Real request/resolution fixture
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_damage = O_Damage.new()
	_world.add_observer(_damage)
	_probe = ResultProbe.new()
	_world.add_observer(_probe)
	_target = Entity.new()
	_target.component_resources = [C_Health.new(), C_Living.new()]
	_world.add_entity(_target)
	_health = _target.get_component(C_Health) as C_Health


func after_each() -> void:
	_probe.results.clear()
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_target = null
	_health = null
	_damage = null
	_probe = null


func _request(amount: float, floor_fraction: float = 0.1) -> DamageRequest:
	var request: DamageRequest = DamageRequest.new()
	request.target = _target
	request.amount = amount
	request.minimum_health_fraction = floor_fraction
	request.damage_type = DamageRequest.Type.MELEE
	return request
#endregion


#region Resolution-time nonlethal floor
func test_multiple_queued_hits_preserve_captured_fraction_and_resolution_time_maximum() -> void:
	_damage.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_health.current = 60.0
	var request: DamageRequest = _request(1000.0)
	assert_true(DamageRequestService.submit(request))
	assert_true(DamageRequestService.submit(request))
	request.minimum_health_fraction = 0.9
	assert_eq(_health.current, 60.0)
	assert_true(_probe.results.is_empty())
	_health.value = 200.0
	_health.current = 40.0
	_world.flush_command_buffers()
	assert_eq(_health.current, 20.0)
	assert_eq(_probe.results.size(), 2)
	assert_eq(_probe.results[0].request.minimum_health_fraction, 0.1)
	assert_eq(_probe.results[0].applied_amount, 20.0)
	assert_eq(_probe.results[1].applied_amount, 0.0)
	assert_eq(_probe.results[1].outcome, DamageResult.Outcome.APPLIED)
	assert_false(_health.depleted)
	assert_false(_target.has_component(C_Death))


func test_resistance_applies_before_floor_and_damage_never_heals_already_lower_hp() -> void:
	var resistance: C_DamageResistance = C_DamageResistance.new()
	resistance.multipliers = { DamageRequest.Type.MELEE: 0.5 }
	_target.add_component(resistance)
	_health.current = 20.0
	assert_true(DamageRequestService.submit(_request(10.0)))
	assert_eq(_health.current, 15.0)
	assert_eq(_probe.results.back().applied_amount, 5.0)
	assert_true(DamageRequestService.submit(_request(1000.0)))
	assert_eq(_health.current, 10.0)
	assert_eq(_probe.results.back().applied_amount, 5.0)
	_health.current = 3.0
	assert_true(DamageRequestService.submit(_request(1000.0)))
	assert_eq(_health.current, 3.0)
	assert_eq(_probe.results.back().applied_amount, 0.0)
	assert_false(_health.depleted)


func test_unguarded_damage_still_depletes_through_common_living_lifecycle() -> void:
	_world.add_observer(O_HealthLifecycle.new())
	_health.current = 30.0
	assert_true(DamageRequestService.submit(_request(1000.0)))
	assert_eq(_health.current, 10.0)
	assert_false(_target.has_component(C_Death))
	assert_true(DamageRequestService.submit(_request(1000.0, 0.0)))
	assert_eq(_health.current, 0.0)
	assert_true(_health.depleted)
	assert_true(_target.has_component(C_Death))
	assert_eq(_probe.results.back().outcome, DamageResult.Outcome.HEALTH_DEPLETED)


func test_invalid_floors_and_non_damage_operations_reject_before_any_health_mutation() -> void:
	for invalid: float in [-0.1, 1.01, INF, NAN]:
		assert_true(DamageRequestService.submit(_request(10.0, invalid)))
		assert_eq(_probe.results.back().outcome, DamageResult.Outcome.REJECTED)
		assert_eq(_probe.results.back().reason, &"invalid_health_floor")
		assert_eq(_health.current, 100.0)
	for operation: DamageRequest.Operation in [
		DamageRequest.Operation.HEAL,
		DamageRequest.Operation.SACRIFICE,
	]:
		var request: DamageRequest = _request(10.0)
		request.operation = operation
		request.maximum_health_delta = (
			-10.0 if operation == DamageRequest.Operation.SACRIFICE else 0.0
		)
		assert_true(DamageRequestService.submit(request))
		assert_eq(_probe.results.back().reason, &"invalid_health_floor")
		assert_eq(_health.current, 100.0)
		assert_eq(_health.value, 100.0)
		assert_eq(_health.base, 100.0)
	assert_false(_health.depleted)


func test_source_veto_and_full_immunity_remain_authoritative() -> void:
	var source: Entity = Entity.new()
	source.component_resources = [C_NoDamage.new()]
	_world.add_entity(source)
	var request: DamageRequest = _request(1000.0)
	request.source = source
	assert_true(DamageRequestService.submit(request))
	assert_eq(_probe.results.back().outcome, DamageResult.Outcome.BLOCKED)
	assert_eq(_probe.results.back().reason, &"source_veto")
	assert_eq(_health.current, 100.0)
	var resistance: C_DamageResistance = C_DamageResistance.new()
	resistance.multipliers = { DamageRequest.Type.MELEE: 0.0 }
	_target.add_component(resistance)
	assert_true(DamageRequestService.submit(_request(1000.0)))
	assert_eq(_probe.results.back().applied_amount, 0.0)
	assert_eq(_health.current, 100.0)


func test_inclusive_full_floor_blocks_cost_without_healing_or_depletion() -> void:
	_health.current = 40.0
	assert_true(DamageRequestService.submit(_request(1000.0, 1.0)))
	assert_eq(_health.current, 40.0)
	assert_eq(_probe.results.back().applied_amount, 0.0)
	assert_false(_health.depleted)
#endregion
