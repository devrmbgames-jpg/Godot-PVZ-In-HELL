extends Node
## Main-level pickup, consumption, modal input and death cleanup with the current player and supply.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 600
var _actor: Entity = null
var _panel: InventoryPanel = null


#region Main-level inventory scenario
func _ready() -> void:
	_run.call_deferred()


## Checks the actual current panel, physical pickup, consumption and terminal cleanup.
func _run() -> void:
	var level: Node = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	add_child(level)
	level.set_physics_process(false)
	_actor = level.get_node("Entityes/Player") as Entity
	(_actor as Node as CharacterBody3D).set_physics_process(false)
	_panel = level.get_node("InventoryPanel") as InventoryPanel
	assert(InputMap.has_action(&"inventory"))
	var receiving_zone: E_ReceivingZone = level.get_node("Entityes/ReceivingZone") as E_ReceivingZone
	var expected_packages: int = mini(receiving_zone.supply.maximum_batch_packages, receiving_zone.supply.packages.size())
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == expected_packages:
			break
	assert(ECS.world.query.with_all([C_Package]).execute().size() == expected_packages, "Current authored first batch must finish before Inventory checks")

	for node_name: String in ["FoodPickup", "MedPickup", "WrapPickup"]:
		var pickup: Entity = level.get_node("Entityes/" + node_name) as Entity
		await _aim(pickup)
		var choice: InteractionActionChoice = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT)
		assert(choice != null and choice.action is DEF_InventoryPickupAction)
		var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
		controller.input_tick += 1
		controller.interact_pressed = true
		InteractionInputFixture.advance(_actor)
		controller.interact_pressed = false
		assert(InventoryService.owner_for(pickup) == _actor)
		for frame: int in 3:
			await get_tree().process_frame
		assert(not (pickup.get_node("Visual") as Node3D).visible)
		assert((pickup as Node as PhysicsBody3D).collision_layer == 0)
	assert(InventoryService.items(_actor).size() == 3)

	var hunger: C_Hunger = _actor.get_component(C_Hunger) as C_Hunger
	hunger.value = 75.0
	var request: DamageRequest = DamageRequest.new()
	request.target = _actor
	request.amount = 50.0
	assert(DamageRequestService.submit(request))
	assert((_actor.get_component(C_Health) as C_Health).current == 50.0)
	var parcel: Entity = PackageQueries.find_live_package("base_supply:1:books")
	await _aim(parcel, Vector3.UP * 0.15)

	var quantity_before: int = InventoryService.items(_actor).size()
	assert(not InventoryService.transfer(parcel, _actor))
	assert(InventoryService.items(_actor).size() == quantity_before)
	assert(_panel.open_inventory())
	assert(InteractionControlFocus.current(_actor) == InteractionControlFocus.Priority.MODAL)
	assert(InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT) == null)
	_click("Хлеб")
	assert(hunger.value == 40.0)
	_click("Аптечка")
	assert((_actor.get_component(C_Health) as C_Health).current == 85.0)
	_click("Пузырчатая плёнка")
	assert((parcel.get_component(C_ImpactProtection) as C_ImpactProtection).tier == ImpactResult.Severity.Medium)
	assert((InventoryService.item_by_id(_actor, _item_id("bubble_wrap")).get_component(C_InventoryItem) as C_InventoryItem).quantity == 2)
	assert(EntityAvailability.contains(parcel, ECS.world))

	_button("Пузырчатая плёнка").pressed.emit()
	var use_button: Button = _panel.get_node("Root/Center/Panel/Content/Actions/Use") as Button
	assert(use_button.disabled)
	assert((_panel.get_node("Root/Center/Panel/Content/Details") as Label).text.contains("Наведитесь"))
	var nested_owner: Node = Node.new()
	add_child(nested_owner)
	var token: int = InteractionControlFocus.acquire(_actor, nested_owner, InteractionControlFocus.Priority.MODAL)
	_panel.close_inventory()
	assert(InteractionControlFocus.current(_actor) == InteractionControlFocus.Priority.MODAL)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	InteractionControlFocus.release(_actor, token)
	nested_owner.free()
	assert(_panel.open_inventory())

	var event: InputEventAction = InputEventAction.new()
	event.action = &"menu"
	event.pressed = true
	_panel._input(event)
	assert(InteractionControlFocus.current(_actor) == InteractionControlFocus.Priority.HANDS)
	assert(not (_panel.get_node("Root") as Control).visible)
	var debug: Label = level.get_node("InteractionHud/Overlay/PlayerDebugPanel/Debug/InventoryDebug") as Label
	for frame: int in 32:
		await get_tree().process_frame
		if debug.text.contains("Хлеб ×2"):
			break

	var inventory_text: String = InventoryPresentation.debug_text(_actor)
	assert(inventory_text.contains("[Tab]") and inventory_text.contains("Хлеб ×2") and inventory_text.contains("задача:"))
	assert(debug.text == inventory_text.get_slice("\n", 0), "HUD must show the current compact Inventory summary")
	assert(_panel.open_inventory())
	request = DamageRequest.new()
	request.target = _actor
	request.amount = 200.0
	assert(DamageRequestService.submit(request))
	for frame: int in 3:
		await get_tree().process_frame
	assert(not (_panel.get_node("Root") as Control).visible)
	assert(InventoryService.items(_actor).is_empty(), "Death=%s HP=%s items=%d" % [_actor.has_component(C_Death), (_actor.get_component(C_Health) as C_Health).current, InventoryService.items(_actor).size()])
	level.free()
	ECS.world = null
	print("Inventory main targeting pickup ownership quantity Food Health Bubble Wrap modal UI and cleanup smoke PASS")
	get_tree().quit.call_deferred()


#endregion

#region Тестовое наведение и UI
func _aim(target: Entity, offset: Vector3 = Vector3.ZERO) -> void:
	var position: Vector3 = (target as Node as Node3D).global_position + offset
	var ray: RayCast3D = GrabQueries.interaction_raycast(_actor)
	ray.global_position = position + Vector3.BACK * 1.5
	ray.look_at(position)
	for frame: int in 2:
		await get_tree().physics_frame
	var interactor: C_Interactor = _actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingGeometry.find_target(_actor, interactor)
	assert(interactor.target == target, "Expected %s, actual %s, collider %s" % [target.name, interactor.target.name if interactor.target != null else "none", ray.get_collider()])


func _button(caption: String) -> Button:
	var rows: GridContainer = _panel.get_node("Root/Center/Panel/Content/Scroll/Rows") as GridContainer
	for child: Node in rows.get_children():
		var button: Button = child as Button
		if button != null and button.tooltip_text.begins_with(caption):
			return button

	assert(false, "Expected an authored item button")
	return null


func _click(caption: String) -> void:
	var button: Button = _button(caption)
	assert(not button.disabled)
	button.pressed.emit()
	var use_button: Button = _panel.get_node("Root/Center/Panel/Content/Actions/Use") as Button
	assert(not use_button.disabled)
	use_button.pressed.emit()


func _item_id(key: StringName) -> String:
	for item: Entity in InventoryService.items(_actor):
		if (item.get_component(C_InventoryItem) as C_InventoryItem).definition.key == key:
			return item.id
	return ""

#endregion
