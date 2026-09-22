extends Node

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
	var system: S_Damage = level.get_node("World/Systems/GamePlay/S_Damage") as S_Damage
	system.defeated.connect(_on_defeated)
	system.damage_resolved.connect(_on_resolved)
	var health: C_Health = actor.get_component(C_Health) as C_Health
	_send(actor, 25.0, DamageRequest.Operation.DAMAGE, package)
	assert(health.value == 75.0 and _last_result.applied_amount == 25.0)
	_send(actor, 40.0, DamageRequest.Operation.HEAL, other_package)
	assert(health.value == health.base)
	_send(actor, NAN)
	assert(health.value == 100.0 and _last_result.outcome == DamageResult.Outcome.REJECTED)
	_send(package, 20.0)
	var package_state: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	assert(package_state.damage == C_PackageState.Damage.DAMAGED)
	_send(package, 50.0, DamageRequest.Operation.HEAL)
	assert(_last_result.outcome == DamageResult.Outcome.REJECTED)
	_send(package, 200.0)
	assert(package_state.damage == C_PackageState.Damage.DESTROYED)
	assert(_last_result.outcome == DamageResult.Outcome.PACKAGE_DESTROYED)
	package.add_relationship(Relationship.new(C_HeldBy.new(), actor))
	assert(S_Grab.held_object(actor) == package)
	_send(actor, 1000.0)
	assert(health.value == 0.0 and health.defeated and _defeat_count == 1)
	assert(S_Grab.held_object(actor) == null)
	assert(not (actor.get_component(C_Motion) as C_Motion).control_enabled)
	_send(actor, 10.0)
	_send(actor, 100.0, DamageRequest.Operation.HEAL)
	assert(health.value == 0.0 and _defeat_count == 1)
	var request: DamageRequest = DamageRequest.new()
	request.target = other_package
	request.amount = 10.0
	assert(S_Damage.submit(request))
	ECS.world.remove_entity(other_package)
	other_package.free()
	var previous_results: int = _resolved_count
	ECS.world.process(1.0 / 60.0, "GamePlay")
	assert(_resolved_count == previous_results + 1)
	assert(_last_result.outcome == DamageResult.Outcome.REJECTED)
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
	assert(S_Damage.submit(request))
	ECS.world.process(1.0 / 60.0, "GamePlay")


func _on_defeated(_target: Entity, _result: DamageResult) -> void:
	_defeat_count += 1


func _on_resolved(result: DamageResult) -> void:
	_resolved_count += 1
	_last_result = result
