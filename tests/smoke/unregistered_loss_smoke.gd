extends Node
## Regression smoke: unregistered package-pickup customers do not spawn; next Morning closes them as Lost.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 300

var _level: Node = null
var _cycle: C_DayCycle = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	add_child(_level)
	_level.set_physics_process(false)
	_cycle = DayPhaseService.current()

	for _frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	assert(ECS.world.query.with_all([C_Package]).execute().size() == 8)

	var flow: C_CustomerFlow = CustomerFlowService.current()
	var wallet: C_Wallet = WalletService.current()
	assert(flow != null and _cycle != null and wallet != null)
	var books_visit: CustomerVisit = CustomerFlowService.find_visit(&"visit/base_supply:1:books")
	var books: Entity = CustomerFlowService.parcel_for("base_supply:1:books")
	var late: Entity = CustomerFlowService.parcel_for("base_supply:1:equipment")
	assert(books_visit != null and books != null and late != null)
	var books_identity: C_Package = books.get_component(C_Package) as C_Package
	assert(not books_identity.history_id.is_empty())
	assert(PackageHistoryId.parse(books_identity.history_id) != null)

	_transition(DayTransitionRequest.Kind.START_SHIFT)
	for _frame: int in 30:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
	assert(ECS.world.query.with_all([C_CustomerAgent]).execute().is_empty())
	assert(_cycle.remaining_customer_events == 0)
	assert(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT))

	var balance_before: int = wallet.balance
	_transition(DayTransitionRequest.Kind.FINISH_SHIFT)
	_transition(DayTransitionRequest.Kind.SLEEP)
	ECS.world.process(FRAME_DELTA, "GamePlay")
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(_cycle.day_index == 2 and _cycle.phase == C_DayCycle.Phase.MORNING)

	for key: String in ["books", "glass", "clothes"]:
		var visit: CustomerVisit = CustomerFlowService.find_visit(
			StringName("visit/base_supply:1:" + key)
		)
		assert(visit != null)
		assert(not visit.started)
		assert(visit.finished)
		assert(visit.declaration == CustomerVisit.Declaration.LOST)
		assert(visit.loss_cause == CustomerVisit.LossCause.MISSED_REGISTRATION)
		assert(visit.disposition == CustomerVisit.Disposition.LOST)
		assert(visit.settlement_committed)
		assert(CustomerFlowService.parcel_for(visit.package_id) == null)
	assert(wallet.balance == balance_before - 900)
	assert(CustomerFlowService.parcel_for("base_supply:1:equipment") == late)
	assert(not CustomerFlowService.find_visit(&"visit/base_supply:1:equipment").finished)

	_level.free()
	ECS.world = null
	print("Unregistered customer gate and next-morning loss smoke PASS")
	get_tree().quit()


func _transition(kind: DayTransitionRequest.Kind) -> void:
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = _cycle.day_index
	request.expected_phase = _cycle.phase
	assert(DayPhaseService.submit(request))
	ECS.world.process(FRAME_DELTA, "GamePlay")
