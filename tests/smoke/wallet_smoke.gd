extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	add_child(level)
	level.set_physics_process(false)
	# This fixture isolates the day/wallet contract; R11 has its own full flow smoke.
	var session: Entity = level.get_node("Entityes/DaySession") as Entity
	session.remove_component(C_CustomerFlow)
	var wallet: C_Wallet = WalletService.current()
	assert(wallet != null)
	var cycle: C_DayCycle = DayPhaseService.current()
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = &"smoke/payment"
	operation.amount = wallet.policy.delivery_payment
	assert(WalletService.submit(operation) == WalletService.Status.COMMITTED)
	var transition: DayTransitionRequest = DayTransitionRequest.new()
	transition.kind = DayTransitionRequest.Kind.START_SHIFT
	transition.expected_day = 1
	transition.expected_phase = C_DayCycle.Phase.MORNING
	assert(DayPhaseService.submit(transition))
	ECS.world.process(0.0, "GamePlay")
	transition = DayTransitionRequest.new()
	transition.kind = DayTransitionRequest.Kind.FINISH_SHIFT
	transition.expected_day = 1
	transition.expected_phase = C_DayCycle.Phase.DAY
	assert(DayPhaseService.submit(transition))
	ECS.world.process(0.0, "GamePlay")
	assert(wallet.completed_days == 1)
	transition = DayTransitionRequest.new()
	transition.kind = DayTransitionRequest.Kind.SLEEP
	transition.expected_day = 1
	transition.expected_phase = C_DayCycle.Phase.EVENING
	assert(DayPhaseService.submit(transition))
	ECS.world.process(0.0, "GamePlay")
	ECS.world.process(0.0, "GamePlay")
	assert(cycle.day_index == 2)
	assert(wallet.daily_results.size() == 2)
	assert(wallet.daily_results[1].income == 0)
	assert(wallet.balance == operation.amount)
	assert(WalletService.submit(operation) == WalletService.Status.DUPLICATE)
	level.free()
	ECS.world = null
	print("R10 wallet day smoke PASS")
	get_tree().quit()
