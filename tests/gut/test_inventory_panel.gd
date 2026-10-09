extends GutTest
## Проверяет сетку инвентаря, захват ввода и физический выброс целого стека с проверкой опоры.

var _root: Node3D
var _world: World
var _actor: E_RigidBodyCharacter
var _panel: InventoryPanel


#region Физическое окружение и UI
## Создаёт физическую опору, игрока и реальную панель инвентаря.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_world.add_observer(O_InventoryLifecycle.new())
	_world.add_observer(O_InventoryEffect.new())
	_world.add_observer(O_Damage.new())

	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/domains/motion/entities/e_rigid_body_character.gd"))
	_actor = body as Node as E_RigidBodyCharacter
	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = load("res://content/domains/needs/definitions/def_hunger_default.tres") as DEF_HungerPolicy
	hunger.value = 60.0
	_actor.component_resources = [C_Inventory.new(), C_GrabControl.new(), C_Controller.new(), C_Health.new(), hunger]
	_root.add_child(body)
	_actor.owner = _root
	_world.add_entity(_actor, null, false)
	_floor(Vector3(0, -0.1, 0), Vector3(10, 0.2, 10))
	_panel = (load("res://content/ui/inventory_panel.tscn") as PackedScene).instantiate() as InventoryPanel
	_panel.player = _actor
	_root.add_child(_panel)
	await get_tree().physics_frame
	await get_tree().physics_frame


## Закрывает панель до удаления World и отложенных узлов.
func after_each() -> void:
	_panel.close_inventory()
	_world.purge(false)
	_root.free()
	ECS.world = null
	await get_tree().process_frame


func _floor(position: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.position = position
	body.add_child(collider)
	_root.add_child(body)


func _item(key: String, quantity: int = 1) -> Entity:
	var definition: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_%s.tres" % key) as DEF_InventoryItem
	var item: Entity = Entity.new()
	var stack: C_InventoryItem = C_InventoryItem.new()
	stack.definition = definition
	stack.quantity = quantity
	item.component_resources = [stack]
	_world.add_entity(item)
	assert_true(InventoryService.transfer(item, _actor))
	return item


func _grid() -> GridContainer:
	return _panel.get_node("Root/Center/Panel/Content/Scroll/Rows") as GridContainer


func _button(name: String) -> Button:
	return _panel.get_node("Root/Center/Panel/Content/Actions/" + name) as Button


#endregion

#region Выбор, применение и выброс
## Сетка показывает пустую ёмкость и отдельные авторские иконки четырёх типов предметов.
func test_capacity_grid_has_empty_slots_and_four_unused_authored_icons() -> void:
	assert_true(_panel.open_inventory())
	assert_eq(_grid().columns, 4)
	assert_eq(_grid().get_child_count(), 8)
	assert_true(_button("Use").disabled)
	assert_true(_button("Drop").disabled)
	for slot: Node in _grid().get_children():
		assert_true((slot as Button).disabled)
	_panel.close_inventory()
	for key: String in ["food", "med", "bubble_wrap", "npc_meat"]:
		var item: Entity = _item(key)
		var icon: Texture2D = (item.get_component(C_InventoryItem) as C_InventoryItem).definition.icon
		assert_not_null(icon)
		assert_true(icon.resource_path.begins_with("res://addons/at-icons/mesh/"))
	assert_true(_panel.open_inventory())
	for index: int in 4:
		var icon: TextureRect = _grid().get_child(index).get_child(0).get_child(0).get_child(0) as TextureRect
		assert_not_null(icon.texture)
	assert_eq(_grid().get_child_count(), 8)


## Выбор аптечки не расходует её; кнопка применения учитывает актуальное HP и количество.
func test_selecting_med_does_not_consume_and_use_follows_actual_health_then_updates_quantity() -> void:
	var med: Entity = _item("med", 2)
	var health: C_Health = _actor.get_component(C_Health) as C_Health
	health.value = 100.0
	health.current = 100.0
	assert_true(_panel.open_inventory())
	(_grid().get_child(0) as Button).pressed.emit()
	assert_eq((med.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_true(_button("Use").disabled)
	assert_false(_button("Drop").disabled)
	health.current = 50.0
	_panel._process(1.0)
	assert_false(_button("Use").disabled)
	_button("Use").pressed.emit()
	assert_eq(health.current, 85.0)
	assert_eq((med.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)
	_button("Use").pressed.emit()
	assert_eq(health.current, 100.0)
	assert_true(InventoryService.items(_actor).is_empty())
	assert_true(_button("Use").disabled)
	assert_true(_button("Drop").disabled)


## Выброс материализует весь виртуальный стек на опоре для последующего подбора.
func test_drop_button_materializes_virtual_stack_on_floor_and_can_pick_it_back_up() -> void:
	_item("npc_meat", 3)
	assert_true(_panel.open_inventory())
	_button("Drop").pressed.emit()
	assert_true(InventoryService.items(_actor).is_empty())
	var drops: Array[Entity] = _world.query.with_all([C_InventoryItem]).execute()
	assert_eq(drops.size(), 1)
	var drop: Entity = drops[0]
	assert_true(drop is E_InventoryPickup)
	assert_null(InventoryService.owner_for(drop))
	assert_eq((drop.get_component(C_InventoryItem) as C_InventoryItem).quantity, 3)
	assert_almost_eq((drop as Node as Node3D).global_position.y, 0.15, 0.01)
	assert_almost_eq((drop as Node as Node3D).global_position.z, -0.9, 0.00001)
	assert_true(InventoryService.transfer(drop, _actor))
	assert_eq(InventoryService.items(_actor).size(), 1)


## Отсутствие опоры или стена отклоняют выброс без потери количества и владельца.
func test_no_support_and_wall_reject_drop_without_item_or_relationship_loss() -> void:
	var item: Entity = _item("food", 2)
	(_actor as Node as Node3D).position = Vector3(0, 0, 20)
	assert_false(InventoryDropService.drop(_actor, item))
	assert_eq(InventoryService.owner_for(item), _actor)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	(_actor as Node as Node3D).position = Vector3.ZERO
	_floor(Vector3(0, 0.7, -0.5), Vector3(4, 1.4, 0.1))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(InventoryDropService.drop(_actor, item), "Cannot materialize behind a thin wall")
	assert_eq(InventoryService.owner_for(item), _actor)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 1)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)


## Чужой модальный токен блокирует действия; закрытие панели сохраняет его.
func test_nested_modal_prevents_grid_actions_and_close_preserves_other_capture() -> void:
	var food: Entity = _item("food", 2)
	assert_true(_panel.open_inventory())
	var modal_owner: Node = Node.new()
	_root.add_child(modal_owner)
	var token: int = InteractionControlFocus.acquire(_actor, modal_owner, InteractionControlFocus.Priority.MODAL)
	_button("Use").pressed.emit()
	_button("Drop").pressed.emit()
	assert_eq((food.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_eq((_actor.get_component(C_Hunger) as C_Hunger).value, 60.0)
	_panel.close_inventory()
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	InteractionControlFocus.release(_actor, token)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


## Ожидающее применение и чужой владелец блокируют выброс стека.
func test_pending_use_and_nonowner_cannot_drop() -> void:
	var item: Entity = _item("med")
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	state.pending_use_id = &"pending-heal"
	assert_false(InventoryDropService.drop(_actor, item))
	assert_eq(InventoryService.owner_for(item), _actor)
	state.pending_use_id = &""
	var stranger: Entity = Entity.new()
	stranger.component_resources = [C_Inventory.new()]
	_world.add_entity(stranger)
	assert_false(InventoryDropService.drop(stranger, item))
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)
	assert_eq(InventoryService.owner_for(item), _actor)

#endregion
