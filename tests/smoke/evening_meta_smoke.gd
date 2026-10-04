extends Node

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 600
var _actor: Entity = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	add_child(level)
	level.set_physics_process(false)
	_actor = level.get_node("Entityes/Player") as Entity
	(_actor as Node as RigidBody3D).freeze = true
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	var parcel: Entity = CustomerFlowService.parcel_for("base_supply:1:equipment")
	assert(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED)
	var budget: MoneyOperation = MoneyOperation.new()
	budget.operation_id = &"evening_meta_smoke/budget"
	budget.reason = MoneyOperation.Reason.DEBUG_CREDIT
	budget.amount = 500
	budget.day_index = 1
	assert(WalletService.submit(budget) == WalletService.Status.COMMITTED)
	await _transition(DayTransitionRequest.Kind.START_SHIFT)
	await _transition(DayTransitionRequest.Kind.FINISH_SHIFT)
	assert(DayPhaseService.current().phase == C_DayCycle.Phase.EVENING)

	var trader: E_NpcCharacter = level.get_node("Entityes/Trader") as E_NpcCharacter
	assert(trader.navigation_agent != null)
	assert(trader.has_component(C_NpcIntent) and trader.has_component(C_Trader))
	assert(trader.global_position.y > -0.2, "Trader stands on the authored exterior floor")
	await _aim(trader, Vector3.UP)
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.USE)
	assert(choice != null and choice.action is DEF_TraderAction)
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	controller.input_tick += 1
	controller.use_pressed = true
	InteractionActionResolver.handle_input(_actor)
	controller.use_pressed = false

	var shop: CommercePanel = _panel()
	assert(shop != null)
	await _click(shop, "Купить ×1", "Хлеб")
	assert(WalletService.current().balance == 475)
	assert(InventoryService.items(_actor).size() == 1)
	await _click(shop, "Купить ×1", "Аптечка")
	assert(WalletService.current().balance == 415)
	assert(InventoryService.items(_actor).size() == 2)
	await _click(shop, "Принять задание")

	var quest: RefusalQuestRecord = RefusalQuestService.current().records[0]
	assert(quest.state == RefusalQuestRecord.State.ACTIVE)
	assert(quest.package_id == "base_supply:1:equipment" and quest.deadline_day == 11)
	assert(quest.reward == 60)
	assert(MetaPresentation.debug_text().contains("Не выдавай") and MetaPresentation.debug_text().contains("Night дня 11"))
	shop.close_panel()
	for frame: int in 3:
		await get_tree().process_frame

	var terminal: E_Terminal = level.get_node("Entityes/Terminal") as E_Terminal
	terminal.open_for(_actor)
	var terminal_panel: TerminalPanel = terminal.get_node("TerminalPanel") as TerminalPanel
	var orders: Button = terminal_panel.get_node("Root/Panel/NewUI/HBoxContainer/VBoxContainer/Tools/MarginContainer/HBoxContainer/ButtonOrders") as Button
	assert(not orders.disabled)
	orders.pressed.emit()
	assert(not terminal_panel.visible)
	var order_panel: CommercePanel = _panel()
	assert(order_panel != null and InteractionControlFocus.current(_actor) == InteractionControlFocus.Priority.MODAL)
	await _click(order_panel, "Заказать ×1", "Хлеб")
	assert(WalletService.current().balance == 390)
	assert(CommerceService.current().pending_deliveries.size() == 1)
	assert(CommerceService.current().pending_deliveries[0].delivery_day == 2)
	assert(not CommerceService.current().pending_deliveries[0].fulfilled)
	assert(InventoryService.items(_actor).size() == 2)
	assert(MetaPresentation.debug_text().contains("Заказ Хлеб ×1"))
	order_panel.close_panel()
	for frame: int in 3:
		await get_tree().process_frame
	assert(InteractionControlFocus.current(_actor) == InteractionControlFocus.Priority.HANDS)

	var debug: Label = level.get_node("InteractionHud/Overlay/PlayerDebugPanel/Debug/MetaDebug") as Label
	for frame: int in 32:
		await get_tree().process_frame
		if debug.text.contains("Заказ Хлеб"):
			break

	assert(debug.text.contains("задача") or debug.text.contains("Задача"))
	assert(debug.text.contains("Night дня 11") and debug.text.contains("Заказ Хлеб"))
	var commerce_copy: C_Commerce = CommerceService.current().duplicate(true) as C_Commerce
	var quest_copy: C_QuestSession = RefusalQuestService.current().duplicate(true) as C_QuestSession
	assert(commerce_copy.receipts.size() == 3 and commerce_copy.pending_deliveries.size() == 1)
	assert(quest_copy.records[0].package_id == quest.package_id)
	level.free()
	ECS.world = null
	print("Evening Trader physical NPC ray interaction purchases Terminal orders durable quest and debug UI smoke PASS")
	get_tree().quit.call_deferred()


func _transition(kind: DayTransitionRequest.Kind) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	ECS.world.process(FRAME_DELTA, "GamePlay")
	await get_tree().physics_frame


func _aim(target: Entity, offset: Vector3) -> void:
	var position: Vector3 = (target as Node as Node3D).global_position + offset
	var ray: RayCast3D = GrabService.interaction_raycast(_actor)
	# Fixture position only; production interaction never moves either physical actor.
	(_actor as Node as RigidBody3D).global_position = (target as Node as Node3D).global_position + Vector3.BACK * 1.5
	ray.global_position = position + Vector3.BACK * 1.5
	ray.look_at(position)
	for frame: int in 2:
		await get_tree().physics_frame

	var interactor: C_Interactor = _actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingService.find_target(_actor, interactor)
	assert(interactor.target == target)


func _panel() -> CommercePanel:
	for child: Node in _actor.get_children():
		if child is CommercePanel and not child.is_queued_for_deletion():
			return child as CommercePanel
	return null


func _click(panel: CommercePanel, action: String, caption: String = "") -> void:
	await get_tree().process_frame
	var buttons: Array[Node] = panel.find_children("*", "Button", true, false)
	for child: Node in buttons:
		var button: Button = child as Button
		if button.text.contains(action) and (caption.is_empty() or button.text.contains(caption)):
			assert(not button.disabled)
			button.pressed.emit()
			return

	assert(false, "Expected an enabled commerce action button")
