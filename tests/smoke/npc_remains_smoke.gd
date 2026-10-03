extends Node
## Actual main-scene death wiring and consumable remains, separate from full-slice owner QA.

const FRAME_DELTA: float = 1.0 / 60.0
const SUPPLY_FRAMES: int = 900
const TEST_HUNGER: float = 80.0

var _level: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	(actor as Node).set_physics_process(false)
	for frame: int in SUPPLY_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if CustomerFlowService.parcel_for("base_supply:1:oil") != null:
			break
	var parcel: Entity = CustomerFlowService.parcel_for("base_supply:1:oil")
	assert(parcel != null)
	assert(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED)
	var cycle: C_DayCycle = DayPhaseService.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	var npc: E_Customer = null
	for frame: int in SUPPLY_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		npc = ECS.world.query.with_all([C_CustomerAgent]).execute_one() as E_Customer
		if npc != null:
			break
	assert(npc != null)
	var visit: CustomerVisit = CustomerFlowService.find_visit((npc.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	assert(CombatService.hit(actor, actor, npc, 200.0))
	assert(npc.has_component(C_Death))
	assert((npc.get_component(C_NpcRemains) as C_NpcRemains).released)
	assert(not (npc as Node as Node3D).visible)
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(CustomerFlowService.customer_for(visit.visit_id) == null)
	assert(visit.customer_dead and visit.defeated_by_player)
	var meat: Array[Entity] = []
	for drop: Entity in ECS.world.query.with_all([C_InventoryItem]).execute():
		var item: C_InventoryItem = drop.get_component(C_InventoryItem) as C_InventoryItem
		if item.definition.key == &"npc_meat":
			meat.append(drop)
	assert(meat.size() == 3)
	for drop: Entity in meat:
		assert((drop as Node as Node3D).global_position.y > -0.5, "Actual authored floor supports the remains")
		assert(InventoryService.transfer(drop, actor))
	var food: Entity = null
	for item: Entity in InventoryService.items(actor):
		if (item.get_component(C_InventoryItem) as C_InventoryItem).definition.key == &"npc_meat":
			food = item
	assert(food != null)
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	hunger.value = TEST_HUNGER
	assert(InventoryService.use(actor, food))
	assert(hunger.value == TEST_HUNGER - 25.0)
	assert((food.get_component(C_InventoryItem) as C_InventoryItem).quantity == 2)
	ECS.world.purge(false)
	_level.free()
	ECS.world = null
	await get_tree().process_frame
	print("NPC remains actual main death cleanup physical meat inventory eating smoke PASS")
	get_tree().quit.call_deferred()
