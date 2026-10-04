extends GutTest
## Проверяет исключительное владение стеком, успешный расход и освобождение при lifecycle-переходах.

var _world: World = null
var _owner: Entity = null
var _other: Entity = null
var _damage: O_Damage = null


#region Владельцы и предметы
## Создаёт двух живых владельцев и observers применения/очистки предметов.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_damage = O_Damage.new()
	_world.add_observer(_damage)
	_world.add_observer(O_InventoryEffect.new())
	_world.add_observer(O_InventoryLifecycle.new())
	_owner = _new_owner()
	_other = _new_owner()


## Удаляет World и сбрасывает глобальную ссылку ECS.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _new_owner() -> Entity:
	var actor: Entity = Entity.new()
	var health: C_Health = C_Health.new()
	health.current = 50.0
	health.value = 100.0
	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = load("res://content/definitions/gameplay/hunger/def_hunger_default.tres") as DEF_HungerPolicy
	hunger.value = 75.0
	actor.component_resources = [C_Inventory.new(), C_Living.new(), health, hunger]
	_world.add_entity(actor)
	return actor


func _item(key: String, quantity: int = 1) -> Entity:
	var item: Entity = Entity.new()
	var state: C_InventoryItem = C_InventoryItem.new()
	state.definition = load("res://content/definitions/gameplay/inventory/def_item_%s.tres" % key) as DEF_InventoryItem
	state.quantity = quantity
	item.component_resources = [state]
	_world.add_entity(item)
	return item


#endregion

#region Владение и объединение
## Передача сверяет прежнего владельца и сохраняет одну авторитетную связь.
func test_pickup_and_compare_owner_transfer_never_creates_two_owners() -> void:
	var item: Entity = _item("food", 2)
	assert_true(InventoryService.transfer(item, _owner))
	assert_eq(InventoryService.owner_for(item), _owner)
	assert_false(InventoryService.transfer(item, _other))
	assert_false(InventoryService.transfer(item, _owner, _owner))
	assert_true(InventoryService.transfer(item, _other, _owner))
	assert_eq(InventoryService.owner_for(item), _other)
	assert_eq(item.relationships.size(), 1)
	assert_true(InventoryService.items(_owner).is_empty())
	assert_eq(InventoryService.items(_other).size(), 1)


## Объединение учитывает ёмкость; отказ сохраняет количество и отсутствие владельца нового стека.
func test_stacking_uses_capacity_and_rejected_transfer_is_atomic() -> void:
	(_owner.get_component(C_Inventory) as C_Inventory).maximum_stacks = 1
	var first: Entity = _item("food", 8)
	assert_true(InventoryService.transfer(first, _owner))
	var second: Entity = _item("food", 2)
	assert_true(InventoryService.transfer(second, _owner))
	assert_eq((first.get_component(C_InventoryItem) as C_InventoryItem).quantity, 10)
	assert_eq(InventoryService.items(_owner).size(), 1)

	var remainder: Entity = _item("food", 2)
	assert_false(InventoryService.transfer(remainder, _owner))
	assert_null(InventoryService.owner_for(remainder))
	assert_eq((remainder.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	var med: Entity = _item("med")
	assert_false(InventoryService.transfer(med, _owner))
	assert_eq((first.get_component(C_InventoryItem) as C_InventoryItem).quantity, 10)


## Излишек объединения остаётся во втором стеке того же владельца.
func test_stack_overflow_keeps_remainder_in_second_owned_stack() -> void:
	var first: Entity = _item("food", 9)
	var second: Entity = _item("food", 4)
	assert_true(InventoryService.transfer(first, _owner))
	assert_true(InventoryService.transfer(second, _owner))
	assert_eq((first.get_component(C_InventoryItem) as C_InventoryItem).quantity, 10)
	assert_eq((second.get_component(C_InventoryItem) as C_InventoryItem).quantity, 3)
	assert_eq(InventoryService.items(_owner).size(), 2)
	assert_eq(InventoryService.owner_for(second), _owner)


#endregion

#region Эффекты и повторный вход
## Еда расходуется только после эффекта; пустой стек удаляется.
func test_food_consumes_once_per_success_and_removes_empty_stack() -> void:
	var item: Entity = _item("food", 3)
	assert_true(InventoryService.transfer(item, _owner))
	assert_true(InventoryService.use(_owner, item))
	assert_eq((_owner.get_component(C_Hunger) as C_Hunger).value, 40.0)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_false(InventoryService.use(_other, item))
	assert_true(InventoryService.use(_owner, item))
	assert_true(InventoryService.use(_owner, item))
	assert_eq((_owner.get_component(C_Hunger) as C_Hunger).value, 0.0)
	assert_true(InventoryService.items(_owner).is_empty())
	assert_false(InventoryService.use(_owner, item))

	var extra: Entity = _item("food")
	assert_true(InventoryService.transfer(extra, _owner))
	assert_false(InventoryService.use(_owner, extra))
	assert_eq((extra.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)


## Аптечка расходуется по результату лечения и сохраняется при полном HP.
func test_med_consumes_after_actual_healing_and_never_at_full_health() -> void:
	var item: Entity = _item("med", 3)
	assert_true(InventoryService.transfer(item, _owner))
	assert_true(InventoryService.use(_owner, item))
	assert_eq((_owner.get_component(C_Health) as C_Health).current, 85.0)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_false((_owner.get_component(C_Inventory) as C_Inventory).use_in_progress)
	assert_true(InventoryService.use(_owner, item))
	assert_eq((_owner.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)
	assert_false(InventoryService.use(_owner, item))
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)


## Повторный вход из сигнала здоровья не дублирует использование или передачу.
func test_reentrant_health_notification_cannot_use_or_transfer_twice() -> void:
	var item: Entity = _item("med", 2)
	assert_true(InventoryService.transfer(item, _owner))
	var health: C_Health = _owner.get_component(C_Health) as C_Health
	health.property_changed.connect(func(_component: Component, property: StringName, _old: Variant, _new: Variant) -> void:
		if property == &"current":
			assert_false(InventoryService.use(_owner, item))
			assert_false(InventoryService.transfer(item, _other, _owner))
	)
	assert_true(InventoryService.use(_owner, item))
	assert_eq(health.current, 85.0)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)


## Удаление/отключение предмета с ожидающим лечением освобождает блокировку владельца.
func test_pending_heal_item_removal_or_disable_releases_owner_lock() -> void:
	_damage.active = false
	for remove: bool in [true, false]:
		var item: Entity = _item("med")
		assert_true(InventoryService.transfer(item, _owner))
		assert_true(InventoryService.use(_owner, item))
		assert_true((_owner.get_component(C_Inventory) as C_Inventory).use_in_progress)
		if remove:
			_world.remove_entity(item)
		else:
			_world.disable_entity(item)
		assert_false((_owner.get_component(C_Inventory) as C_Inventory).use_in_progress)
		assert_eq((_owner.get_component(C_Health) as C_Health).current, 50.0)


## Устаревший ID результата лечения не завершает новое использование предмета.
func test_old_healing_result_cannot_commit_a_later_pending_use() -> void:
	_damage.active = false
	var item: Entity = _item("med", 2)
	assert_true(InventoryService.transfer(item, _owner))
	assert_true(InventoryService.use(_owner, item))
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	var result: DamageResult = DamageResult.new()
	result.request = DamageRequest.new()
	result.request.source = item
	result.request.target = _owner
	result.request.instigator = _owner
	result.request.operation = DamageRequest.Operation.HEAL
	result.request.origin_id = state.pending_use_id
	InventoryService.healing_result(result)
	assert_eq(state.quantity, 2, "Rejected healing retains the quantity")
	assert_true(InventoryService.use(_owner, item))
	assert_ne(state.pending_use_id, result.request.origin_id)
	result.applied_amount = 35.0
	InventoryService.healing_result(result)
	assert_eq(state.quantity, 2)
	assert_true((_owner.get_component(C_Inventory) as C_Inventory).use_in_progress)
	result.request.origin_id = state.pending_use_id
	result.applied_amount = 0.0
	InventoryService.healing_result(result)
	assert_false((_owner.get_component(C_Inventory) as C_Inventory).use_in_progress)


## Упаковка расходуется только при реальном увеличении защиты подходящей коробки.
func test_wrap_only_consumes_on_valid_package_protection_increase() -> void:
	var item: Entity = _item("bubble_wrap", 2)
	assert_true(InventoryService.transfer(item, _owner))
	assert_false(InventoryService.use(_owner, item))
	assert_false(InventoryService.use(_owner, item, _other))
	var parcel: Entity = Entity.new()
	var health: C_Health = C_Health.new()
	health.current = 100.0
	health.value = 100.0
	parcel.component_resources = [C_Package.new(), health]
	_world.add_entity(parcel)
	assert_true(InventoryService.use(_owner, item, parcel))
	assert_eq((parcel.get_component(C_ImpactProtection) as C_ImpactProtection).tier, ImpactResult.Severity.Medium)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)
	assert_false(InventoryService.use(_owner, item, parcel))
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)
	assert_true(EntityAvailability.contains(parcel, _world), "The physical package remains in the world")


#endregion

#region Допуск и lifecycle
## Коробка, обычный инструмент, неверное количество и неоднозначное владение недоступны инвентарю.
func test_package_physical_grabbable_invalid_quantity_and_ambiguous_owner_are_rejected() -> void:
	var parcel: Entity = _item("food")
	parcel.add_component(C_Package.new())
	assert_false(InventoryService.transfer(parcel, _owner))
	var tool: Entity = _item("food")
	tool.add_component(C_Grabbable.new())
	assert_false(InventoryService.transfer(tool, _owner))
	for quantity: int in [0, -1, 11]:
		assert_false(InventoryService.transfer(_item("food", quantity), _owner))

	var ambiguous: Entity = _item("food")
	ambiguous.add_relationship(Relationship.new(R_OwnedBy.new(), _owner))
	ambiguous.add_relationship(Relationship.new(R_OwnedBy.new(), _other))
	assert_null(InventoryService.owner_for(ambiguous))
	assert_false(InventoryService.transfer(ambiguous, _owner))


## Отключённые хранимые предметы занимают ёмкость и удаляются вместе с владельцем.
func test_disabled_stored_items_count_capacity_and_cleanup_on_owner_removal() -> void:
	(_owner.get_component(C_Inventory) as C_Inventory).maximum_stacks = 1
	var item: Entity = _item("food")
	assert_true(InventoryService.transfer(item, _owner))
	_world.disable_entity(item)
	assert_eq(InventoryService.owner_for(item), _owner)
	assert_eq(InventoryService.items(_owner).size(), 1)
	assert_false(InventoryService.use(_owner, item))
	assert_false(InventoryService.transfer(_item("med"), _owner))
	_world.remove_entity(_owner)
	assert_false(_world.entity_to_archetype.has(item), "Disabled stored items must be removed before their owner disappears")


## Снятие владения отключённого предмета или смерть владельца очищает его из ECS.
func test_disabled_item_explicit_owner_detachment_and_death_cleanup() -> void:
	var item: Entity = _item("med")
	assert_true(InventoryService.transfer(item, _owner))
	_world.disable_entity(item)
	item.remove_relationship(item.relationships[0] as Relationship)
	assert_false(_world.entity_to_archetype.has(item))
	item = _item("food")
	assert_true(InventoryService.transfer(item, _other))
	_world.disable_entity(item)
	_other.add_component(C_Death.new())
	assert_false(_world.entity_to_archetype.has(item))


## Удаление, отключение и смерть владельца освобождают виртуальные предметы.
func test_owner_removal_disable_and_death_cleanup_virtual_items() -> void:
	var item: Entity = _item("food")
	assert_true(InventoryService.transfer(item, _owner))
	_world.remove_entity(_owner)
	assert_false(EntityAvailability.contains(item, _world))
	_owner = _new_owner()
	item = _item("med")
	assert_true(InventoryService.transfer(item, _owner))
	_world.disable_entity(_owner)
	assert_false(EntityAvailability.contains(item, _world))
	item = _item("food")
	assert_true(InventoryService.transfer(item, _other))
	assert_true(InventoryService.transfer(_item("med"), _other))
	assert_true(InventoryService.transfer(_item("bubble_wrap"), _other))
	assert_eq(InventoryService.items(_other).size(), 3)
	_other.add_component(C_Death.new())
	assert_false(EntityAvailability.contains(item, _world))
	assert_true(InventoryService.items(_other).is_empty(), "Cleanup snapshots the query before structural mutation")
	assert_false(InventoryService.transfer(_item("food"), _other))

#endregion
