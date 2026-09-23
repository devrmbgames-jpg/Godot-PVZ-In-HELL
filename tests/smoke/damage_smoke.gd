extends Node
## Existing damage regression, adapted to typed Observer results; run manually when requested.

var _defeat_count: int = 0
var _last_result: DamageResult = null
var _resolved_count: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	add_child(level)
	level.set_physics_process(false)
	for delivery_tick: int in 12:
		await get_tree().physics_frame
		ECS.world.process(1.0 / 60.0, "GamePlay")
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	var package: Entity = level.get_node("Entityes/Parcel_001_03") as Entity
	var other_package: Entity = level.get_node("Entityes/Parcel_001_02") as Entity
	var probe: ResultProbe = ResultProbe.new()
	probe.received = _on_resolved
	ECS.world.add_observer(probe)
	var health: C_Health = actor.get_component(C_Health) as C_Health
	_send(actor, 25.0, DamageRequest.Operation.DAMAGE, package)
	assert(health.current == 75.0 and _last_result.applied_amount == 25.0)
	_send(actor, 40.0, DamageRequest.Operation.HEAL, other_package)
	assert(health.current == health.value)
	_send(actor, NAN)
	assert(health.current == 100.0 and _last_result.outcome == DamageResult.Outcome.REJECTED)
	_send(package, 20.0)
	var package_state: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	assert(package_state.damage == C_PackageState.Damage.DAMAGED)
	_send(package, 50.0, DamageRequest.Operation.HEAL)
	assert(_last_result.outcome == DamageResult.Outcome.APPLIED)
	_send(package, 200.0)
	assert(package_state.damage == C_PackageState.Damage.DESTROYED)
	assert(_last_result.outcome == DamageResult.Outcome.HEALTH_DEPLETED)
	package.add_relationship(Relationship.new(C_HeldBy.new(), actor))
	assert(S_Grab.held_object(actor) == package)
	_send(actor, 1000.0)
	assert(health.current == 0.0 and health.depleted and _defeat_count == 2)
	assert(S_Grab.held_object(actor) == null)
	assert(not (actor.get_component(C_Motion) as C_Motion).control_enabled)
	_send(actor, 10.0)
	_send(actor, 100.0, DamageRequest.Operation.HEAL)
	assert(health.current == 0.0 and _defeat_count == 2)
	var request: DamageRequest = DamageRequest.new()
	request.target = other_package
	request.amount = 10.0
	ECS.world.remove_entity(other_package)
	assert(not DamageRequestService.submit(request))
	other_package.free()
	level.free()
	ECS.world = null
	print("R04 damage/heal/defeat/package smoke PASS")
	get_tree().quit()


func _send(
	target: Entity,
	amount: float,
	operation: DamageRequest.Operation = DamageRequest.Operation.DAMAGE,
	source: Entity = null,
) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.target = target
	request.source = source
	request.amount = amount
	request.operation = operation
	assert(DamageRequestService.submit(request))
	ECS.world.process(1.0 / 60.0, "GamePlay")


func _on_resolved(result: DamageResult) -> void:
	_last_result = result
	_resolved_count += 1
	if result.outcome == DamageResult.Outcome.HEALTH_DEPLETED:
		_defeat_count += 1


class ResultProbe extends Observer:
	var received: Callable


	func query() -> QueryBuilder:
		return q.on_event(DamageResult.EVENT)


	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		received.call(payload as DamageResult)
