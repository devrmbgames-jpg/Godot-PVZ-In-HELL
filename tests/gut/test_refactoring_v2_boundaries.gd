extends GutTest
## Real-World proof of accepted vs committed commands, reentrancy and detached diagnostics.

var _world: World
var _session: Entity
var _target: Entity
var _damage: O_Damage
var _results: Array[DamageResult] = []
var _nested_submitted: bool = false
var _link_committed: bool = false
var _consumer_saw_link: bool = false
var _depletion_facts: int = 0

class DamageFacts extends Observer:
	## Test consumer, intentionally synchronous like the pinned World event contract.
	var receive: Callable

	func query() -> QueryBuilder:
		return q.on_event(DamageResult.EVENT)

	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		receive.call(payload as DamageResult)


class GroupProducer extends System:
	## Structural endpoint supplied by the isolated fixture.
	var endpoint: Entity
	## Commits the terminal fact after its queued relationship mutation.
	var commit: Callable

	func query() -> QueryBuilder:
		return q.with_all([C_Health])

	func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
		for subject: Entity in entities:
			cmd.add_relationship(subject, Relationship.new(R_NpcMoveTarget.new(), endpoint))
			cmd.add_custom(commit)


class DepletionFacts extends Observer:
	## Counts real depletion publications without spawning presentation scenes.
	var receive: Callable

	func query() -> QueryBuilder:
		return q.on_event(HealthDepletionEvent.EVENT)

	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		receive.call()


class GroupConsumer extends System:
	## Observes the later System, before PER_GROUP structural commit.
	var inspect_pending: Callable

	func deps() -> Dictionary[int, Array]:
		return {Runs.After: [GroupProducer]}

	func query() -> QueryBuilder:
		return q.with_all([C_Health])

	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		inspect_pending.call()


#region Isolated World
## Installs the real handler and an optional ECS-owned diagnostic provider.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_results.clear()
	_nested_submitted = false
	_link_committed = false
	_consumer_saw_link = false
	_depletion_facts = 0
	_session = _entity([C_DayCycle.new(), C_BoundaryTrace.new()])
	_session.id = "fixture/session"
	_target = _entity([C_Health.new()])
	_target.id = "fixture/target"
	_damage = O_Damage.new()
	_world.add_observer(_damage)
	var facts: DamageFacts = DamageFacts.new()
	facts.receive = _receive_damage
	_world.add_observer(facts)


## Purges the fixture without touching authored scenes or user saves.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _entity(components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.component_resources = components
	_world.add_entity(entity)
	return entity


func _request(correlation: StringName, amount: float = 7.0) -> DamageRequest:
	var request: DamageRequest = DamageRequest.new()
	request.target = _target
	request.amount = amount
	request.correlation_id = correlation
	return request


func _receive_damage(resolution: DamageResult) -> void:
	_results.append(resolution)
	assert_eq((_target.get_component(C_Health) as C_Health).current, resolution.current_value)
	if resolution.request.correlation_id == &"outer" and not _nested_submitted:
		_nested_submitted = true
		assert_true(DamageRequestService.submit(_request(&"nested", 3.0)))


func _commit_link() -> void:
	_link_committed = not _target.relationships.is_empty()
	assert_true(_link_committed, "Terminal fact follows the actual structural mutation")


func _inspect_pending() -> void:
	_consumer_saw_link = not _target.relationships.is_empty()
	assert_false(_link_committed, "deps does not flush PER_GROUP work")


func _receive_depletion() -> void:
	_depletion_facts += 1
#endregion

#region Acceptance, completion and reentrancy
## MANUAL handler acceptance stays pending until the concrete observer flush.
func test_damage_acceptance_is_not_completion_and_submission_snapshots_inputs() -> void:
	_damage.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: DamageRequest = _request(&"manual")
	assert_true(DamageRequestService.submit(request))
	request.amount = 80.0
	assert_eq((_target.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq(_results.size(), 0)
	var pending: Array[Dictionary] = BoundaryTrace.snapshots(_target.id)
	assert_eq(pending.size(), 1)
	assert_eq(pending[0]["stage"], BoundaryTraceEntry.Stage.ACCEPTED)

	_world.flush_command_buffers()
	assert_eq(_results.size(), 1)
	assert_eq(_results[0].request.amount, 7.0)
	assert_eq(_results[0].current_value, 93.0)
	assert_eq(BoundaryTrace.snapshots(_target.id).back()["stage"],
		BoundaryTraceEntry.Stage.COMPLETED)


## A result consumer may submit a bounded nested command without replaying the outer mutation.
func test_synchronous_result_reentrancy_commits_each_damage_once() -> void:
	assert_true(DamageRequestService.submit(_request(&"outer")))
	assert_eq(_results.size(), 2)
	assert_eq(_results[0].current_value, 93.0)
	assert_eq(_results[1].current_value, 90.0)
	assert_eq((_target.get_component(C_Health) as C_Health).current, 90.0)
	assert_false(_damage.has_pending_commands())


## One damage handler feeds death and depletion owners; replay cannot repeat either effect.
func test_terminal_fact_has_distinct_idempotent_domain_consumers() -> void:
	_target.add_component(C_Living.new())
	var effects: C_HealthDepletionEffects = C_HealthDepletionEffects.new()
	_target.add_component(effects)
	_world.add_observer(O_HealthLifecycle.new())
	_world.add_observer(O_DepletionEffects.new())
	var depletion: DepletionFacts = DepletionFacts.new()
	depletion.receive = _receive_depletion
	_world.add_observer(depletion)

	assert_true(DamageRequestService.submit(_request(&"terminal", 150.0)))
	var death: C_Death = _target.get_component(C_Death) as C_Death
	assert_not_null(death)
	assert_true(effects.committed)
	assert_eq(_depletion_facts, 1)
	assert_eq(_results.size(), 1)

	_world.emit_event(DamageResult.EVENT, _target, _results[0])
	assert_same(_target.get_component(C_Death), death, "Death authority is preserved on replay")
	assert_eq(_depletion_facts, 1, "Depletion effects publish only once")
	assert_eq((_target.get_component(C_Health) as C_Health).current, 0.0)


## A later dependent System still sees pending PER_GROUP relationships; fact comes after flush.
func test_deps_does_not_make_per_group_relationships_or_facts_visible() -> void:
	var producer: GroupProducer = GroupProducer.new()
	producer.endpoint = _session
	producer.commit = _commit_link
	producer.command_buffer_flush_mode = System.FlushMode.PER_GROUP
	producer.group = "fixture"
	_world.add_system(producer)
	var consumer: GroupConsumer = GroupConsumer.new()
	consumer.inspect_pending = _inspect_pending
	consumer.group = "fixture"
	_world.add_system(consumer)

	_world.process(0.1, "fixture")
	assert_false(_consumer_saw_link)
	assert_true(_link_committed)
	assert_false(producer.has_pending_commands())


## The provider is bounded and detached; readers cannot rewrite history or gameplay.
func test_trace_is_bounded_detached_and_uses_explicit_identities() -> void:
	for index: int in BoundaryTrace.MAX_ENTRIES + 3:
		BoundaryTrace.record(&"fixture.operation", StringName(str(index)),
			BoundaryTraceEntry.Stage.REJECTED, &"fixture_reason", "origin", _target.id)
	var snapshots_out: Array[Dictionary] = BoundaryTrace.snapshots(_target.id)
	assert_eq(snapshots_out.size(), BoundaryTrace.MAX_ENTRIES)
	assert_eq(snapshots_out[0]["correlation_id"], &"3")
	snapshots_out[0]["reason"] = &"reader_mutation"
	assert_eq(BoundaryTrace.snapshots(_target.id)[0]["reason"], &"fixture_reason")
	assert_eq(BoundaryTrace.identity(_target), "fixture/target")
	var package_identity: C_Package = C_Package.new()
	package_identity.package_id = "shipment/stable"
	_target.add_component(package_identity)
	assert_eq(BoundaryTrace.identity(_target), "shipment/stable")
#endregion
