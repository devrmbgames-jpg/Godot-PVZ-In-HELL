extends Node
## Regression smoke: a missed unregistered customer shipment is lost on the next Morning.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 300

var _level: Node = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	add_child(_level)
	_level.set_physics_process(false)

	for _frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break
	assert(ECS.world.query.with_all([C_Package]).execute().size() == 8)

	var flow: C_CustomerFlow = CustomerFlowService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	var wallet: C_Wallet = WalletService.current()
	assert(flow != null and cycle != null and wallet != null)
	CustomerFlowService.plan_day(flow, 1, wallet.policy.delivery_payment)

	var visit: CustomerVisit = CustomerFlowService.find_visit(&"visit/base_supply:1:books")
	var parcel: Entity = CustomerFlowService.parcel_for("base_supply:1:books")
	var late: Entity = CustomerFlowService.parcel_for("base_supply:1:equipment")
	assert(visit != null and parcel != null and late != null)
	var package_identity: C_Package = parcel.get_component(C_Package) as C_Package
	var package_state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	assert(not package_identity.history_id.is_empty())
	assert(PackageHistoryId.parse(package_identity.history_id) != null)
	assert(package_state.registration == C_PackageState.Registration.UNREGISTERED)

	visit.started = true
	visit.finished = true
	visit.finished_day = 1
	visit.package_history_id = package_identity.history_id
	var balance_before: int = wallet.balance

	cycle.phase = C_DayCycle.Phase.NIGHT
	cycle.night_ready = true
	ECS.world.process(FRAME_DELTA, "GamePlay")
	ECS.world.process(FRAME_DELTA, "GamePlay")

	assert(cycle.day_index == 2 and cycle.phase == C_DayCycle.Phase.MORNING)
	assert(visit.declaration == CustomerVisit.Declaration.LOST)
	assert(visit.disposition == CustomerVisit.Disposition.LOST)
	assert(visit.settlement_committed)
	assert(wallet.balance == balance_before - 120)
	assert(CustomerFlowService.parcel_for(visit.package_id) == null)
	assert(visit.package_history_id == package_identity.history_id)
	assert(CustomerFlowService.parcel_for("base_supply:1:equipment") == late)

	_level.free()
	ECS.world = null
	print("Missed unregistered package next-morning loss smoke PASS")
	get_tree().quit()
