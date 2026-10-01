extends Node

const SAVE_PATH: String = "user://night_persistence_smoke.pvzh"
const DELTA: float = 1.0 / 60.0
const MAX_FRAMES: int = 600


func _ready() -> void:
	_run.call_deferred()


func _load_level() -> Node:
	var level: Node = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	level.set("autosave_path", SAVE_PATH)
	add_child(level)
	level.set_physics_process(false)
	return level


func _step(frames: int) -> void:
	for frame: int in frames:
		ECS.world.process(DELTA, "GamePlay")
		await get_tree().physics_frame


func _run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var level: Node = _load_level()
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	(actor as Node as RigidBody3D).freeze = true
	for frame: int in MAX_FRAMES:
		await _step(1)
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break
	var parcel: Entity = CustomerFlowService.parcel_for("base_supply:1:equipment")
	assert(parcel != null)
	var registration: PackageScanResult = PackageRegistrationService.register_package(parcel)
	assert(registration.outcome == PackageScanResult.Outcome.REGISTERED)
	var number: int = registration.number
	var package_health: C_Health = parcel.get_component(C_Health) as C_Health
	package_health.current = package_health.value * 0.5
	var package_state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	package_state.opening = C_PackageState.Opening.OPENED
	package_state.damage = C_PackageState.Damage.DAMAGED
	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	var stroke: PackageMarkStroke = PackageMarkStroke.new()
	stroke.points = PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0.0, 0.0)])
	marks.strokes.append(stroke)
	marks.point_count = 2
	marks.revision += 1
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	hunger.value = 55.0
	var wallet: C_Wallet = WalletService.current()
	wallet.balance = 500
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.EVENING
	var food: DEF_InventoryItem = CommerceService.current().catalog[0]
	assert(CommerceService.order(actor, food, 2, &"night/order") == CommerceService.Status.COMMITTED)
	var trader: Entity = level.get_node("Entityes/Trader") as Entity
	var quest: RefusalQuestRecord = RefusalQuestService.offer(trader)
	assert(quest != null and RefusalQuestService.accept(quest.quest_id))
	var refused: Entity = level.get_node("Entityes/Parcel_001_01") as Entity
	assert(PackageRegistrationService.register_package(refused).outcome == PackageScanResult.Outcome.REGISTERED)
	var refused_id: String = (refused.get_component(C_Package) as C_Package).package_id
	var refused_visit: CustomerVisit = null
	for visit: CustomerVisit in CustomerFlowService.current().visits:
		if visit.package_id == refused_id:
			refused_visit = visit
	assert(refused_visit != null)
	refused_visit.started = true
	assert(CustomerOutcomeService.commit_player_denial(refused_visit))
	assert(CustomerOutcomeService.declare(refused_visit, CustomerVisit.Declaration.REFUSED))
	CustomerOutcomeService.settle(refused_visit, wallet, 1)
	refused_visit.finished = true
	refused_visit.finished_day = 1
	var expected_balance: int = wallet.balance
	var item: Entity = level.get_node("Entityes/MedPickup") as Entity
	assert(InventoryService.transfer(item, actor))
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.SLEEP
	request.expected_day = 1
	request.expected_phase = C_DayCycle.Phase.EVENING
	assert(DayPhaseService.submit(request))
	for frame: int in MAX_FRAMES:
		await _step(1)
		if cycle.day_index == 2 and CommerceService.current().pending_deliveries[0].fulfilled:
			break
	assert(cycle.day_index == 2 and cycle.phase == C_DayCycle.Phase.MORNING)
	assert(FileAccess.file_exists(SAVE_PATH))
	assert(CommerceService.current().pending_deliveries[0].fulfilled)
	assert(WalletService.current().balance == expected_balance)
	var physical_id: String = OrderDeliveryService.key_for(CommerceService.current().pending_deliveries[0])
	assert(_delivery_count(physical_id) == 1)
	assert(not DayPhaseService.submit(request), "Stale sleep cannot increment DayIndex")
	level.free()
	await get_tree().process_frame
	level = _load_level()
	actor = level.get_node("Entityes/Player") as Entity
	(actor as Node as RigidBody3D).freeze = true
	cycle = DayPhaseService.current()
	assert(cycle.day_index == 2 and cycle.phase == C_DayCycle.Phase.MORNING)
	assert(WalletService.current().balance == expected_balance)
	assert((actor.get_component(C_Hunger) as C_Hunger).value >= 55.0)
	assert(InventoryService.items(actor).size() == 1)
	assert((InventoryService.items(actor)[0].get_component(C_InventoryItem) as C_InventoryItem).definition.kind == DEF_InventoryItem.Kind.MED_ITEM)
	parcel = CustomerFlowService.parcel_for("base_supply:1:equipment")
	assert(parcel != null)
	package_state = parcel.get_component(C_PackageState) as C_PackageState
	assert(package_state.registration_number == number and package_state.registration == C_PackageState.Registration.REGISTERED)
	assert(package_state.opening == C_PackageState.Opening.OPENED and package_state.damage == C_PackageState.Damage.DAMAGED)
	assert(is_equal_approx((parcel.get_component(C_Health) as C_Health).current, package_health.current))
	assert((parcel.get_component(C_PackageMarks) as C_PackageMarks).point_count == 2)
	assert(RefusalQuestService.current().records[0].state == RefusalQuestRecord.State.ACTIVE)
	assert(ECS.world.query.with_all([C_QuestBinding]).execute().size() == 1)
	for frame: int in MAX_FRAMES:
		await _step(1)
		if CommerceService.current().pending_deliveries[0].fulfilled:
			break
	assert(_delivery_count(physical_id) == 1)
	await _step(10)
	assert(_delivery_count(physical_id) == 1)
	assert(MetaPresentation.debug_text().contains("Восстановлено утро 2"))
	refused = CustomerFlowService.parcel_for(refused_id)
	assert(refused != null and PackageReturnService.can_return(refused))
	assert(MetaPresentation.debug_text().contains("держать и вернуть"))
	var return_point: Entity = level.get_node("Entityes/PackageReturnPoint") as Entity
	(refused as Node as RigidBody3D).global_position = (return_point as Node as Node3D).global_position + Vector3(1.0, 1.0, 1.0)
	await _aim(actor, refused)
	assert(GrabService.try_pickup(actor, refused), "pickup available=%s freeze=%s reach=%s selected=%d" % [GrabService.holder_available(actor), (refused as Node as RigidBody3D).freeze, GrabService.within_pickup_reach_body(actor, refused as Node as RigidBody3D), GrabService.pickup_slot(actor, refused, false)])
	await _aim(actor, return_point)
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(actor, DEF_InteractionAction.Slot.USE)
	assert(choice != null and choice.action is DEF_PackageReturnAction)
	var balance_before_return: int = WalletService.current().balance
	var penalties_before_return: int = WalletService.current().penalties
	choice.action.execute(actor, choice.source, choice.target)
	assert(CustomerFlowService.parcel_for(refused_id) == null)
	for visit: CustomerVisit in CustomerFlowService.current().visits:
		if visit.package_id == refused_id:
			assert(visit.disposition == CustomerVisit.Disposition.RETURNED)
			assert(visit.actual == CustomerVisit.Actual.PLAYER_DENIED and visit.declaration == CustomerVisit.Declaration.REFUSED)
			assert(visit.settlement_committed)
	for record: PackageRegistrationRecord in PackageRegistrationService.ledger().records:
		if record.package_id == refused_id:
			assert(not record.active and record.departure == C_PackageState.Registration.RETURNED)
	assert(WalletService.current().balance == balance_before_return and WalletService.current().penalties == penalties_before_return)
	assert(not PackageReturnService.return_held(actor))
	var delivered: Entity = null
	for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == physical_id:
			delivered = entity
	assert(delivered != null and InventoryService.transfer(delivered, actor))
	var owned_food: Entity = null
	for owned: Entity in InventoryService.items(actor):
		if (owned.get_component(C_InventoryItem) as C_InventoryItem).definition == food:
			owned_food = owned
	assert(owned_food != null)
	assert(InventoryService.use(actor, owned_food))
	assert(InventoryService.use(actor, owned_food))
	assert(_delivery_count(physical_id) == 0)
	cycle.phase = C_DayCycle.Phase.EVENING
	request = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.SLEEP
	request.expected_day = 2
	request.expected_phase = C_DayCycle.Phase.EVENING
	assert(DayPhaseService.submit(request))
	for frame: int in MAX_FRAMES:
		await _step(1)
		if cycle.day_index == 3:
			break
	assert(cycle.day_index == 3)
	level.free()
	await get_tree().process_frame
	level = _load_level()
	assert(DayPhaseService.current().day_index == 3)
	assert(CommerceService.current().pending_deliveries[0].fulfilled)
	assert(CustomerFlowService.parcel_for(refused_id) == null)
	assert(CustomerFlowService.parcel_for("base_supply:1:equipment") != null)
	await _step(10)
	assert(_delivery_count(physical_id) == 0, "Consumed order cannot respawn after another Night/restart")
	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("PASS: night persistence: two Nights/restarts, paid order consumed without respawn, inventory, late target/number/condition/ink, physical refusal return retaining penalties and stale requests")
	get_tree().quit()


func _delivery_count(key: String) -> int:
	var count: int = 0
	for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == key:
			count += 1
	return count


func _aim(actor: Entity, target: Entity) -> void:
	var position: Vector3 = (target as Node as Node3D).global_position
	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	# Fixture positioning; production return uses the existing ray/reach/hand pipeline.
	(actor as Node as RigidBody3D).global_position = position + Vector3.BACK * 1.5
	ray.global_position = position + Vector3.BACK * 1.5
	ray.look_at(position)
	for frame: int in 2:
		await get_tree().physics_frame
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingService.find_target(actor, interactor)
	assert(interactor.target == target, "aim target=%s resolved=%s collider=%s pose=%s ray=%s" % [target.name, interactor.target, ray.get_collider(), (target as Node as Node3D).global_position, ray.global_position])
