extends GutTest
## Проверки снимка World: стабильные ID, владение, физические слоты, lifecycle и отказ до изменения живого состояния.

const SAVE_PATH: String = "user://gut_r21_world_snapshot.pvzh"
const _PACKAGE_SCENE_PATH: String = "res://content/domains/packages/entities/package.tscn"
var _root: Node = null
var _world: World = null
var _session: Entity = null
var _actor: Entity = null
var _item: Entity = null

## Тестовая Entity считает реальные вызовы lifecycle World при восстановлении снимка.
class LifecycleEntity extends Entity:
	var _enable_calls: int = 0
	var _disable_calls: int = 0

	## Регистрирует фактическое включение, не подменяя переход World.
	func on_enable() -> void:
		_enable_calls += 1

	## Регистрирует фактическое отключение, включая отключение при загрузке.
	func on_disable() -> void:
		_disable_calls += 1

	## Возвращает число наблюдавшихся включений для проверки однократности перехода.
	func enable_calls() -> int:
		return _enable_calls

	## Возвращает число наблюдавшихся отключений для проверки lifecycle.
	func disable_calls() -> int:
		return _disable_calls


#region Подготовка и очистка
## Создаёт авторскую сессию и игрока; предмет принадлежит игроку через R_OwnedBy.
func before_each() -> void:
	_root = Node.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_world.add_observer(O_NightPreparationRequirement.new())
	_world.add_observer(O_InventoryLifecycle.new())
	_session = _authored("Session", [C_DayCycle.new(), C_Wallet.new(), C_PackageLedger.new(), C_CustomerFlow.new(), C_Commerce.new(), C_QuestSession.new(), C_Autosave.new()])
	(_session.get_component(C_Autosave) as C_Autosave).path = SAVE_PATH
	_actor = _authored("Actor", [C_Inventory.new(), C_Hunger.new(), C_Health.new()])

	var stack: C_InventoryItem = C_InventoryItem.new()
	stack.definition = (load("res://content/domains/inventory/definitions/def_item_food.tres") as DEF_InventoryItem)
	stack.quantity = 4
	_item = Entity.new()
	_item.component_resources = [stack]
	_world.add_entity(_item)
	_item.add_relationship(Relationship.new(R_OwnedBy.new(), _actor))


func _authored(label: String, components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.name = label
	entity.component_resources = components
	_root.add_child(entity)
	entity.owner = _root
	_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	entity.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(entity.name))
	assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
	_world.add_entity(entity, null, false)
	return entity


## Освобождает World и удаляет только файлы тестового снимка.
func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


#endregion

#region Quest variant persistence and exactly-once payment
func _offered_quest() -> RefusalQuestRecord:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.EVENING
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	wallet.balance = 500
	var shop: C_Trader = C_Trader.new()
	shop.profile = (load("res://content/domains/commerce/definitions/def_trader_default.tres") as DEF_TraderProfile).duplicate() as DEF_TraderProfile
	shop.profile.refusal_quest = load("res://content/domains/quests/definitions/def_refusal_patient.tres") as DEF_RefusalQuest
	var trader: Entity = _authored("QuestIssuer", [shop])
	var package: C_Package = C_Package.new()
	package.package_id = "fixture/quest/parcel"
	package.definition = load("res://content/domains/packages/definitions/def_test_bread.tres") as DEF_Package
	_authored("QuestParcel", [package, C_PackageState.new()])
	var registration: PackageRegistrationRecord = PackageRegistrationRecord.new()
	registration.package_id = package.package_id
	registration.number = 3
	(_session.get_component(C_PackageLedger) as C_PackageLedger).records.append(registration)
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"fixture/quest/visit"
	visit.customer_id = &"fixture/quest/recipient"
	visit.package_id = package.package_id
	visit.arrival_day = 2
	visit.definition = load("res://content/domains/customers/definitions/def_customer_prototype.tres") as DEF_Customer
	(_session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(visit)
	return RefusalQuestService.offer(trader)


## Real slot write/read keeps the authored variant and rejects a queued pre-load reward.
func test_quest_variant_slot_roundtrip_and_pending_outcome_do_not_double_pay() -> void:
	var record: RefusalQuestRecord = _offered_quest()
	assert_not_null(record)
	assert_true(RefusalQuestService.accept(record.quest_id))
	var quest_owner: S_RefusalQuest = S_RefusalQuest.new()
	quest_owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(quest_owner)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.MORNING
	CustomerFlowQueries.find_visit(record.visit_id).actual = CustomerVisit.Actual.PLAYER_DENIED
	_world.process(0.0)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	var loaded: RefusalQuestRecord = RefusalQuestService.find(record.quest_id)
	assert_ne(loaded, record)
	assert_eq(loaded.definition.resource_path, "res://content/domains/quests/definitions/def_refusal_patient.tres")
	assert_eq(loaded.deadline_day, 4)
	assert_eq(loaded.reward, 90)
	_world.flush_command_buffers()
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	assert_eq(wallet.balance, 500)
	assert_eq(loaded.state, RefusalQuestRecord.State.ACTIVE)
	_world.process(0.0)
	_world.flush_command_buffers()
	assert_true(loaded.reward_paid)
	assert_eq(wallet.balance, 590)
	assert_eq(wallet.operations.size(), 1)
	assert_false(RefusalQuestService.accept(loaded.quest_id))

	# Reload a committed wallet operation with a missing derived receipt flag.
	loaded.reward_paid = false
	snapshot = WorldSnapshotService.capture(_root, 2)
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	loaded = RefusalQuestService.find(record.quest_id)
	_world.process(0.0)
	_world.flush_command_buffers()
	_world.process(0.0)
	_world.flush_command_buffers()
	assert_true(loaded.reward_paid)
	assert_eq(wallet.balance, 590)
	assert_eq(wallet.operations.size(), 1)
	assert_eq(loaded.definition.accepted_text, "Тестовое задание ждёт фактического отказа.")


## Invalid current quest fields reject the full snapshot before calendar/wallet/relationships change.
func test_invalid_quest_snapshot_rejects_before_live_mutation() -> void:
	var record: RefusalQuestRecord = _offered_quest()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	var fields: Dictionary = {}
	for entity_row: Dictionary in snapshot.entities:
		for component_row: Dictionary in entity_row.components:
			if SaveDataCodec.component_script(String(component_row.type)) == C_QuestSession:
				var quest_records: Array = (component_row.fields as Dictionary).records as Array
				fields = (quest_records[0] as Dictionary).fields as Dictionary
	assert_false(fields.is_empty())
	for corruption: Dictionary in [{"definition": null}, {"quest_id": &""}, {"reward": -1}, {"reward_paid": true}, {"deadline_day": 1}]:
		var saved_fields: Dictionary = fields.duplicate(true)
		fields.merge(corruption, true)
		assert_false(WorldSnapshotService.restore(snapshot, _root))
		assert_eq(DayPhaseQueries.current().phase, C_DayCycle.Phase.EVENING)
		assert_eq((_session.get_component(C_Wallet) as C_Wallet).balance, 500)
		assert_eq(RefusalQuestService.find(record.quest_id), record)
		assert_eq(_world.query.with_all([C_QuestBinding]).execute().size(), 1)
		fields.clear()
		fields.merge(saved_fields)
#endregion

#region Восстановление мира и проверка снимка
## Current-format in-place restore clears transient planning state and rebuilds it once.
func test_restore_rebuilds_customer_planning_cache_without_serializing_it() -> void:
	_session.add_component(C_CustomerFlow.new())
	var flow: C_CustomerFlow = _session.get_component(C_CustomerFlow) as C_CustomerFlow
	flow.planning_day = 2
	flow.planning_phase = int(C_DayCycle.Phase.DAY)
	flow.arrival_cooldown_seconds = 17.0
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(flow.planning_day, 0)
	assert_eq(flow.planning_phase, -1)
	assert_eq(flow.arrival_cooldown_seconds, 0.0)

	CustomerFlowFixture.advance(flow, DayPhaseQueries.current(), 0.0)
	assert_eq(flow.planning_day, 2)
	assert_eq(flow.planning_phase, int(C_DayCycle.Phase.MORNING))
	var encoded: Dictionary = SaveDataCodec.component_data(flow)
	assert_false((encoded.fields as Dictionary).has("planning_day"))
	assert_false((encoded.fields as Dictionary).has("planning_phase"))


## Долг, ID и владение предметом переживают запись и повторную загрузку без дубликатов.
func test_negative_wallet_and_owned_inventory_survive_snapshot_and_repeated_restore() -> void:
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	wallet.balance = -123
	var id: String = _item.id
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	_world.remove_entity(_item)
	wallet.balance = 0
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(wallet.balance, -123)
	assert_eq(DayPhaseQueries.current().day_index, 2)
	assert_eq(InventoryService.items(_actor).size(), 1)

	var restored: Entity = InventoryService.items(_actor)[0]
	assert_eq(restored.id, id)
	assert_eq((restored.get_component(C_InventoryItem) as C_InventoryItem).quantity, 4)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(InventoryService.items(_actor).size(), 1)
	assert_eq(InventoryService.items(_actor)[0].id, id)
	assert_eq(restored.relationships.size(), 1)


## Ошибка записи удерживает ночь; повтор фиксирует то же утро и не изменяет долг или номер дня дважды.
func test_failed_write_holds_night_and_retry_commits_the_same_morning_in_debt() -> void:
	var cycle: C_DayCycle = _session.get_component(C_DayCycle) as C_DayCycle
	var state: C_Autosave = _session.get_component(C_Autosave) as C_Autosave
	(_session.get_component(C_Wallet) as C_Wallet).balance = -300
	cycle.phase = C_DayCycle.Phase.NIGHT
	cycle.night_ready = false
	state.path = "user://r21_missing_directory/slot.pvzh"
	_night_step(0.1)
	assert_ne(state.last_error, OK)
	assert_false(cycle.night_ready)
	assert_eq(cycle.day_index, 1)
	assert_eq(state.started_night, 1)
	var captured: Dictionary = state.prepared_snapshot.duplicate(true)
	(_session.get_component(C_Wallet) as C_Wallet).balance = -123
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	_night_step(0.1)
	assert_eq(state.last_error, OK)
	assert_true(cycle.night_ready)
	assert_eq(state.last_saved_morning, 2)
	assert_eq(AutosaveStore.read(SAVE_PATH), captured, "I/O retry writes the original detached state")
	_night_step(0.1)
	assert_eq(state.last_saved_morning, 2)
	assert_eq(cycle.day_index, 1)
	_world.add_system(S_DayPhase.new())
	_world.process(0.1)
	assert_eq(cycle.day_index, 2)
	assert_eq(cycle.phase, C_DayCycle.Phase.MORNING)
	_world.process(0.1)
	assert_eq(cycle.day_index, 2)


## Дублированная запись отклоняется до изменения денег, владения и фазы.
func test_invalid_snapshot_is_rejected_before_mutating_wallet_or_ownership() -> void:
	var wallet: C_Wallet = _session.get_component(C_Wallet) as C_Wallet
	wallet.balance = 70
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var records: Array = snapshot.entities as Array
	var duplicate: Dictionary = (records[0] as Dictionary).duplicate(true)
	records.append(duplicate)
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(wallet.balance, 70)
	assert_eq(DayPhaseQueries.current().day_index, 1)
	assert_eq(InventoryService.owner_for(_item), _actor)
	assert_eq(InventoryService.items(_actor).size(), 1)


## Отсутствующий владелец в сохранённой связи запрещает загрузку до изменения живого инвентаря.
func test_inventory_with_unknown_relationship_target_is_rejected_before_mutation() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	for record: Dictionary in snapshot.entities:
		if not (record.links as Array).is_empty():
			(record.links as Array)[0].target = "missing/owner"
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(InventoryService.owner_for(_item), _actor)
	assert_eq(DayPhaseQueries.current().day_index, 1)


## Пропущенная сцена или авторский путь не допускают частичного восстановления.
func test_missing_scene_or_authored_id_is_rejected_before_mutation() -> void:
	for field: String in ["scene", "authored_id"]:
		var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
		var records: Array = snapshot.entities as Array
		(records[0] as Dictionary).erase(field)
		assert_false(WorldSnapshotService.restore(snapshot, _root))
		assert_eq(InventoryService.owner_for(_item), _actor)
		assert_eq(DayPhaseQueries.current().day_index, 1)


## Загрузка заменяет прежнего владельца без удаления предмета или сохранения блокировки передачи.
func test_restore_replaces_previous_inventory_owner_without_retiring_item() -> void:
	var other: Entity = _authored("Other", [C_Inventory.new()])
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(InventoryService.transfer(_item, other, _actor))
	assert_eq(InventoryService.owner_for(_item), other)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(InventoryService.owner_for(_item), _actor)
	assert_eq(InventoryService.items(_actor).size(), 1)
	assert_true(InventoryService.items(other).is_empty())
	assert_eq(_item.relationships.size(), 1)
	assert_false((_item.get_component(C_InventoryItem) as C_InventoryItem).transfer_in_progress)


## Посылка без обязательного авторского определения отклоняется до изменения фазы и владения.
func test_null_package_definition_is_rejected_before_mutation() -> void:
	var identity: C_Package = C_Package.new()
	identity.package_id = "late:equipment"
	identity.definition = (load("res://content/domains/packages/definitions/def_delivery_morning_supply.tres") as DEF_Delivery).packages[0]
	_authored("Package", [identity, C_PackageState.new()])
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	for record: Dictionary in snapshot.entities:
		for component: Dictionary in record.components:
			if SaveDataCodec.component_script(String(component.type)) == C_Package:
				(component.fields as Dictionary).definition = null
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(DayPhaseQueries.current().day_index, 1)
	assert_eq(InventoryService.owner_for(_item), _actor)


## Восстановление enabled/disabled проходит через lifecycle World и переиспользует существующую Entity.
func test_restore_disabled_entity_uses_world_lifecycle_and_reenables_existing_entity() -> void:
	var entity: LifecycleEntity = LifecycleEntity.new()
	entity.name = "Lifecycle"
	entity.component_resources = [C_Health.new()]
	_root.add_child(entity)
	entity.owner = _root
	_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	entity.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(entity.name))
	assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
	_world.add_entity(entity, null, false)
	var enabled_snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.disable_entity(entity)

	var disabled_snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.enable_entity(entity)
	var disable_calls: int = entity.disable_calls()
	assert_true(WorldSnapshotService.restore(disabled_snapshot, _root))
	assert_false(entity.enabled)
	assert_false(entity.is_processing())
	assert_false(entity.is_physics_processing())
	assert_eq(entity.disable_calls(), disable_calls + 1)

	var enable_calls: int = entity.enable_calls()
	assert_true(WorldSnapshotService.restore(enabled_snapshot, _root))
	assert_true(entity.enabled)
	assert_true(entity.is_processing())
	assert_true(entity.is_physics_processing())
	assert_eq(entity.enable_calls(), enable_calls + 1)


## Перед восстановлением обменённых слотов очищается вся прежняя занятость и затем возвращаются физические связи.
func test_restore_swapped_slots_clears_all_old_occupancy_before_attaching() -> void:
	var slots: Array[E_PhysicalSlot] = []
	var boxes: Array[Entity] = []
	for index: int in 2:
		var slot: E_PhysicalSlot = (load("res://content/domains/interaction/entities/physical_slot.tscn") as PackedScene).instantiate() as E_PhysicalSlot
		slot.name = "Slot%d" % index
		_root.add_child(slot)
		slot.owner = _root
		_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
		slot.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(slot.name))
		assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
		_world.add_entity(slot, null, false)
		slots.append(slot)
		var box: Entity = (load("res://content/domains/interaction/entities/anchorable_test_box.tscn") as PackedScene).instantiate() as Entity
		box.name = "Box%d" % index
		_root.add_child(box)
		box.owner = _root
		_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
		box.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(box.name))
		assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
		_world.add_entity(box, null, false)
		boxes.append(box)
		var binding: Relationship = Relationship.new(R_StoredIn.new(), slot)
		box.add_relationship(binding)
		assert_true(PhysicalSlotService.attach(box, binding))

	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	for box: Entity in boxes:
		PhysicalSlotService.release(box)
	for index: int in 2:
		var binding: Relationship = Relationship.new(R_StoredIn.new(), slots[1 - index])
		boxes[index].add_relationship(binding)
		assert_true(PhysicalSlotService.attach(boxes[index], binding))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	for index: int in 2:
		assert_eq(PhysicalSlotService.occupant(slots[index]), boxes[index])
		var binding: Relationship = PhysicalSlotService.relationship(boxes[index])
		assert_true((binding.relation as R_StoredIn).applied)
		assert_false((boxes[index] as Node as RigidBody3D).is_physics_processing())
		assert_eq(slots[index].driver.get_node(slots[index].driver.remote_path), boxes[index])


## Дубликаты владельцев/ID/путей, неверная роль и превышенная вместимость отклоняются до мутации.
func test_duplicate_owners_wrong_role_or_capacity_fail_before_any_mutation() -> void:
	for invalid: String in ["owners", "role", "capacity", "ids", "paths"]:
		var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
		var records: Array = snapshot.entities as Array
		for record: Dictionary in records:
			if String(record.key) == ActorIdentityRules.key_for(_item, _root):
				if invalid == "owners":
					(record.links as Array).append((record.links[0] as Dictionary).duplicate())
				elif invalid == "role":
					(record.links as Array)[0].target = ActorIdentityRules.key_for(_session, _root)
			if invalid == "capacity" and String(record.key) == ActorIdentityRules.key_for(_actor, _root):
				for component: Dictionary in record.components:
					if SaveDataCodec.component_script(String(component.type)) == C_Inventory:
						(component.fields as Dictionary).maximum_stacks = 0
		if invalid == "ids":
			(records[1] as Dictionary).entity_id = (records[0] as Dictionary).entity_id
		if invalid == "paths":
			(records[1] as Dictionary).authored_id = (records[0] as Dictionary).authored_id
		assert_false(WorldSnapshotService.restore(snapshot, _root), invalid)
		assert_eq(DayPhaseQueries.current().day_index, 1)
		assert_eq(InventoryService.owner_for(_item), _actor)


## Групповое восстановление авторских ID перестраивает реестр World без конфликтов при обмене значений.
func test_authored_ids_restore_as_a_group_and_reindex_world_lookup() -> void:
	var session_id: String = _session.id
	var actor_id: String = _actor.id
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.entity_id_registry.erase(session_id)
	_world.entity_id_registry.erase(actor_id)
	_session.id = actor_id
	_actor.id = session_id
	_world.entity_id_registry[_actor.id] = _actor
	_world.entity_id_registry[_session.id] = _session
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_session.id, session_id)
	assert_eq(_actor.id, actor_id)
	assert_eq(_world.get_entity_by_id(session_id), _session)
	assert_eq(_world.get_entity_by_id(actor_id), _actor)


## Двойная занятость слота и цель без нужной роли отклоняются до изменения дня.
func test_duplicate_slot_occupants_or_wrong_slot_entity_fail_before_mutation() -> void:
	var slot: E_PhysicalSlot = (load("res://content/domains/interaction/entities/physical_slot.tscn") as PackedScene).instantiate() as E_PhysicalSlot
	slot.name = "ValidationSlot"
	_root.add_child(slot)
	slot.owner = _root
	_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	slot.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(slot.name))
	assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
	_world.add_entity(slot, null, false)
	for index: int in 2:
		var box: Entity = (load("res://content/domains/interaction/entities/anchorable_test_box.tscn") as PackedScene).instantiate() as Entity
		box.name = "ValidationBox%d" % index
		_root.add_child(box)
		box.owner = _root
		_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
		box.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(box.name))
		assert_true(PlacedIdentityRules.compile_for(_root).is_empty())
		_world.add_entity(box, null, false)
		box.add_relationship(Relationship.new(R_StoredIn.new(), slot))

	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(DayPhaseQueries.current().day_index, 1)
	## Для одного оставшегося предмета проверяем отказ связи с целью без роли физического слота.
	var first: bool = true
	for record: Dictionary in snapshot.entities:
		if not (record.links as Array).is_empty() and String(record.links[0].kind) == SnapshotLinks.STORED:
			if first:
				(record.links as Array)[0].target = ActorIdentityRules.key_for(_actor, _root)
				first = false
			else:
				(record.links as Array).clear()
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(DayPhaseQueries.current().day_index, 1)


## Алиас авторского пути и выход за корень запрещены до изменения реестра или владения.
func test_authored_id_alias_or_outside_root_is_rejected_before_registry_changes() -> void:
	var id: String = _actor.id
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var records: Array = snapshot.entities as Array
	for record: Dictionary in records:
		if String(record.key) == ActorIdentityRules.key_for(_actor, _root):
			var alias: Dictionary = record.duplicate(true)
			alias.key = "placed/fixture/AliasActor"
			alias.entity_id = "alias_actor"
			alias.authored_id = "placed/fixture/UnknownActor"
			records.append(alias)
			break

	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_world.get_entity_by_id(id), _actor)
	assert_null(_world.get_entity_by_id("alias_actor"))
	assert_eq(DayPhaseQueries.current().day_index, 1)
	var outside: Entity = Entity.new()
	outside.name = "Outside"
	add_child(outside)
	snapshot = WorldSnapshotService.capture(_root, 2)
	for record: Dictionary in snapshot.entities:
		if String(record.key) == ActorIdentityRules.key_for(_actor, _root):
			record.authored_id = "placed/other_world/Actor"
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(InventoryService.owner_for(_item), _actor)
	outside.free()


## Отсутствующий C_Package запрещает загрузку до создания физических экземпляров.
func test_omitted_package_identity_is_rejected_before_instantiation_commit() -> void:
	var package_scene: PackedScene = load(_PACKAGE_SCENE_PATH) as PackedScene
	var package: E_Package = package_scene.instantiate() as E_Package
	package.package_id = "test/required_identity"
	package.package_definition = (load("res://content/domains/packages/definitions/def_delivery_morning_supply.tres") as DEF_Delivery).packages[0]
	EntityCompositionFixture.register(_world, package)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_world.remove_entity(package)
	for record: Dictionary in snapshot.entities:
		if String(record.key) == "package/test/required_identity":
			var components: Array = record.components as Array
			for index: int in range(components.size() - 1, -1, -1):
				if SaveDataCodec.component_script(String(components[index].type)) == C_Package:
					components.remove_at(index)

	var count: int = _world.entities.size()
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_world.entities.size(), count)
	assert_eq(DayPhaseQueries.current().day_index, 1)
	assert_eq(InventoryService.owner_for(_item), _actor)


## Снимок без выносливости сбрасывает живое состояние спринта и его множитель движения.
func test_pre_stamina_snapshot_clears_existing_sprint_session() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var stamina: C_Stamina = C_Stamina.new()
	stamina.current = 45.0
	stamina.initialized = true
	stamina.toggled = true
	stamina.running = true
	stamina.exhausted = true
	stamina.recovery_remaining = 2.0
	_actor.add_component(stamina)

	var motion: C_Motion = C_Motion.new()
	motion.sprint_multiplier = 1.5
	_actor.add_component(motion)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_false(stamina.toggled)
	assert_false(stamina.running)
	assert_false(stamina.exhausted)
	assert_eq(stamina.recovery_remaining, 0.0)
	assert_eq(motion.sprint_multiplier, 1.0)

#endregion

#region Scheduled persistence fixture
func _night_step(delta: float) -> void:
	var installed: bool = false
	for owner: System in _world.systems:
		if owner is S_NightSave:
			installed = true
	if not installed:
		var night_owner: S_NightSave = S_NightSave.new()
		night_owner.group = "PersistenceTest"
		_world.add_system(night_owner)
	_world.process(delta, "PersistenceTest")
#endregion

#region Explicit identity and rejected-slot regression
## Rename/reparent changes presentation topology while immutable identity and ownership remain stable.
func test_renamed_and_reparented_placed_actor_restores_same_identity_and_links() -> void:
	var key: String = ActorIdentityRules.key_for(_actor, _root)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	var group: Node = Node.new()
	group.name = "Reorganized"
	_root.add_child(group)
	_actor.reparent(group)
	_actor.owner = _root
	_actor.name = "RenamedActor"
	assert_eq(ActorIdentityRules.key_for(_actor, _root), key)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(InventoryService.owner_for(_item), _actor)
	assert_eq(PlacedIdentityRules.resolver(_root)[key], _actor)


## Both duplicate and missing identity reject before any authored Entity enters the actual GameWorld.
func test_game_world_rejects_invalid_authored_ids_before_registration() -> void:
	for missing: bool in [false, true]:
		var root: Node = Node.new()
		root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"invalid_fixture")
		var actors: Node = Node.new()
		actors.name = "Actors"
		root.add_child(actors)
		for index: int in 2:
			var actor: Entity = Entity.new()
			actor.name = "Actor%d" % index
			actors.add_child(actor)
			actor.owner = root
			if not missing or index == 0:
				actor.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"same_id")
		var world: GameWorld = GameWorld.new()
		world.entity_nodes_root = NodePath("../Actors")
		root.add_child(world)
		add_child(root)
		assert_true(world.initialization_failed())
		assert_eq(world.entities.size(), 0)
		for child: Node in actors.get_children():
			assert_null(PlacedIdentityRules.component_for(child as Entity), "No partially compiled identity")
		world.purge(false)
		root.free()
	ECS.world = _world


## A rejected old-schema slot remains byte-identical after subsequent actual Night scheduling.
func test_rejected_schema_slot_is_protected_from_later_night_and_other_slot_is_allowed() -> void:
	var old_snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	old_snapshot.version = AutosaveStore.SCHEMA_VERSION - 1
	assert_eq(AutosaveStore.write(old_snapshot, SAVE_PATH), OK)
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	var state: C_Autosave = _session.get_component(C_Autosave) as C_Autosave
	assert_false(NightSaveService.restore_startup(_root, state))
	assert_eq(state.rejected_path, SAVE_PATH)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.NIGHT
	_night_step(0.1)
	assert_eq(state.last_error, ERR_UNAUTHORIZED)
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), bytes_before)
	state.path = SAVE_PATH + ".other"
	state.retry_remaining = 0.0
	_night_step(0.1)
	assert_eq(state.last_error, OK)
	assert_true(cycle.night_ready)
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), bytes_before)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.path))
#endregion

#region Selected-slot and receiving preflight
## A compatible manual handoff retains automatic rejected-slot protection through the next Night.
func test_selected_snapshot_does_not_overwrite_rejected_automatic_slot() -> void:
	_root.scene_file_path = GameSessionService.MAIN_LEVEL
	var selected: Dictionary = WorldSnapshotService.capture(_root, 1)
	var old: Dictionary = selected.duplicate(true)
	old.version = AutosaveStore.SCHEMA_VERSION - 1
	assert_eq(AutosaveStore.write(old, SAVE_PATH), OK)
	var retained: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	GameSessionService._pending_level = _root.scene_file_path
	GameSessionService._pending_snapshot = selected
	var state: C_Autosave = _session.get_component(C_Autosave) as C_Autosave
	GameSessionService.restore_startup(_root, state)
	assert_eq(state.last_saved_morning, 1)
	assert_eq(state.rejected_path, SAVE_PATH)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.NIGHT
	_night_step(0.1)
	assert_eq(state.last_error, ERR_UNAUTHORIZED)
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), retained)


## A retained recipe pointing at a non-package prefab rejects before changing the live queue/calendar.
func test_pending_receiving_recipe_wrong_prefab_rejects_before_live_mutation() -> void:
	var receiving: C_Receiving = C_Receiving.new()
	var batch: ReceivingBatch = ReceivingBatch.new()
	batch.day_index = 1
	batch.package_keys = ["fixture_package"]
	batch.package_scenes = ["res://content/domains/packages/entities/package.tscn"]
	receiving.pending.append(batch)
	_session.add_component(receiving)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for record: Dictionary in snapshot.entities:
		for component: Dictionary in record.components:
			if component.type == C_Receiving.resource_path:
				var invalid: C_Receiving = C_Receiving.new()
				assert_true(SaveDataCodec.apply_fields(invalid, component.fields as Dictionary))
				invalid.pending[0].package_scenes[0] = "res://content/domains/interaction/entities/anchorable_test_box.tscn"
				component.fields = SaveDataCodec.component_data(invalid).fields
	var count_before: int = _world.entities.size()
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_world.entities.size(), count_before)
	assert_eq(receiving.pending[0], batch)
	assert_eq(batch.package_scenes[0], "res://content/domains/packages/entities/package.tscn")
	assert_eq(DayPhaseQueries.current().day_index, 1)
#endregion

#region Package composition preflight
## Invalid authoring rejects a saved missing package before registry/calendar/ownership changes.
func test_fresh_package_template_conflict_rejects_restore_before_live_mutation() -> void:
	var package_scene: PackedScene = load(_PACKAGE_SCENE_PATH) as PackedScene
	var parcel: E_Package = package_scene.instantiate() as E_Package
	parcel.package_id = "fixture/package/rejected_template"
	EntityCompositionFixture.register(_world, parcel)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	_world.remove_entity(parcel)
	var count_before: int = _world.entities.size()
	var actor_id_before: String = _actor.id
	var calendar: C_DayCycle = DayPhaseQueries.current()
	calendar.day_index = 7

	# Simulate an authored duplicate in the shared direct Trait; restore must reject it.
	var capability: EntityTrait = load(
		"res://content/domains/combat/authoring/et_impact_capture.tres") as EntityTrait
	var conflicting: EntityTrait = EntityTrait.new()
	conflicting.trait_id = &"fixture_duplicate_health"
	conflicting.component_recipes = [C_Health.new()]
	capability.component_recipes.append(conflicting.component_recipes[0])
	var can_restore: bool = WorldSnapshotService.can_restore(snapshot, _root)
	var restored: bool = WorldSnapshotService.restore(snapshot, _root)
	capability.component_recipes.erase(conflicting.component_recipes[0])

	assert_false(can_restore)
	assert_false(restored)
	assert_eq(_world.entities.size(), count_before)
	assert_eq(_actor.id, actor_id_before)
	assert_same(_world.entity_id_registry[actor_id_before], _actor)
	assert_eq(calendar.day_index, 7)
	assert_same(InventoryService.owner_for(_item), _actor)
#endregion

#region Raw package recipe reconstruction
## Fresh restored receiving prefab retains authored carry/impact/liquid settings and overlaid damaged HP.
func test_fresh_package_restore_rebuilds_recipe_without_resetting_saved_health() -> void:
	var supply: DEF_Delivery = load("res://content/domains/packages/definitions/def_delivery_morning_supply.tres") as DEF_Delivery
	var definition: DEF_Package = null
	for candidate: DEF_Package in supply.packages:
		if candidate.tags & DEF_Package.Tag.LIQUID:
			definition = candidate
			break
	assert_not_null(definition)
	var parcel: E_Package = (load(String(definition.scene_variants[0])) as PackedScene).instantiate() as E_Package
	assert_true(ReceivingPackageFactory.configure_recipe(parcel, definition, "fixture/liquid_recipe"))
	EntityCompositionFixture.register(_world, parcel)
	(parcel.get_component(C_Health) as C_Health).current = definition.maximum_health * 0.5
	var expected_health: float = (parcel.get_component(C_Health) as C_Health).current
	(parcel as Node as Node3D).global_position = Vector3(3.0, 4.0, 5.0)
	var expected_pose: Transform3D = (parcel as Node as Node3D).global_transform
	var key: String = ActorIdentityRules.key_for(parcel, _root)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	_world.remove_entity(parcel)
	var registration_health: Array[float] = []
	var registration_quantity: Array[int] = []
	var registration_poses: Array[Transform3D] = []
	var registration_readiness: Array[bool] = []
	var capture_saved_state: Callable = func(actor: Entity) -> void:
		if actor is E_Package:
			registration_health.append((actor.get_component(C_Health) as C_Health).current)
			registration_poses.append((actor as Node as Node3D).global_transform)
			registration_readiness.append(EntityCompositionService.composition_ready(actor))
		if actor.has_component(C_InventoryItem):
			var stack: C_InventoryItem = actor.get_component(C_InventoryItem) as C_InventoryItem
			registration_quantity.append(stack.quantity)
	_world.remove_entity(_item)
	_world.entity_added.connect(capture_saved_state)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	_world.entity_added.disconnect(capture_saved_state)
	assert_eq(registration_health, [expected_health])
	assert_eq(registration_quantity, [4])
	assert_eq(registration_poses, [expected_pose])
	assert_eq(registration_readiness, [false], "Restore has not fixed saved endpoints yet")
	var restored: Entity = null
	for actor: Entity in _world.entities:
		if ActorIdentityRules.key_for(actor, _root) == key:
			restored = actor
	assert_not_null(restored)
	assert_true(EntityCompositionService.composition_ready(restored))
	assert_true(EntityCompositionService.composition_ready(_actor))
	assert_eq((restored.get_component(C_Health) as C_Health).current, expected_health)
	assert_eq((restored.get_component(C_Grabbable) as C_Grabbable).throw_velocity, definition.throw_velocity)
	assert_eq((restored.get_component(C_ImpactReceiver) as C_ImpactReceiver).profile, definition.impact_profile)
	var tilt: C_LiquidTilt = restored.get_component(C_LiquidTilt) as C_LiquidTilt
	assert_not_null(tilt)
	assert_eq(tilt.maximum_angle_degrees, definition.liquid_maximum_angle_degrees)
	assert_eq(tilt.duration_seconds, definition.liquid_tilt_seconds)
	assert_eq(tilt.unsafe_seconds, 0.0)
#endregion


#region Time preparation contract
## Only an installed autosave workflow holds Night; removing it updates the real query scope.
func test_night_preparation_query_tracks_the_configured_workflow() -> void:
	var requirement: NightPreparationRequirement = NightPreparationRequirement.new()
	_world.emit_event(NightPreparationRequirement.EVENT, _session, requirement)
	assert_true(requirement.is_required())

	_session.remove_component(C_Autosave)
	var without_workflow: NightPreparationRequirement = NightPreparationRequirement.new()
	_world.emit_event(NightPreparationRequirement.EVENT, _session, without_workflow)
	assert_false(without_workflow.is_required())
#endregion

#region Fresh runtime marker reconstruction
## A removed physical parcel returns with terminal damage and private ink before native publication.
func test_fresh_dead_marked_package_publishes_saved_markers_without_reinstalling() -> void:
	var parcel: Entity = (load(
		"res://content/domains/packages/entities/test_bread.tscn"
	) as PackedScene).instantiate() as Entity
	EntityCompositionFixture.register(_world, parcel)
	(parcel.get_component(C_Health) as C_Health).current = 0.0
	parcel.add_component(C_Death.new())
	var marks: C_PackageMarks = C_PackageMarks.new()
	var stroke: PackageMarkStroke = PackageMarkStroke.new()
	stroke.points = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])
	marks.strokes = [stroke]
	marks.point_count = 2
	parcel.add_component(marks)
	var key: String = ActorIdentityRules.key_for(parcel, _root)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	_world.remove_entity(parcel)
	var publications: Array[Entity] = []
	var inspect_marker: Callable = func(actor: Entity) -> void:
		if actor is E_Package:
			publications.append(actor)
			assert_true(actor.has_component(C_Death))
			assert_eq((actor.get_component(C_Health) as C_Health).current, 0.0)
			var restored_ink: C_PackageMarks = actor.get_component(C_PackageMarks) as C_PackageMarks
			assert_not_null(restored_ink)
			assert_eq(restored_ink.point_count, 2)
			assert_eq(restored_ink.revision, 1)
	_world.entity_added.connect(inspect_marker)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	_world.entity_added.disconnect(inspect_marker)
	assert_eq(publications.size(), 1)
	assert_eq(ActorIdentityRules.key_for(publications[0], _root), key)
	var restored: C_PackageMarks = publications[0].get_component(C_PackageMarks) as C_PackageMarks
	assert_eq(restored.revision, 1, "Fresh restoration never reapplies initial ink")
	assert_eq(restored.strokes[0].points, stroke.points)


## An anchored physical order is frozen and has its original release snapshot at native publication.
func test_fresh_anchored_furniture_publishes_complete_physical_snapshot_once() -> void:
	var definition: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_large_shelf.tres"
	) as DEF_InventoryItem
	var shelf: Entity = FurniturePlacement.create_validated(definition)
	EntityCompositionFixture.register(_world, shelf)
	var anchored: C_PlayerAnchored = C_PlayerAnchored.new()
	anchored.snapshot = AnchoredBodySnapshot.new()
	anchored.snapshot.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	anchored.snapshot.can_sleep = false
	shelf.add_component(anchored)
	(shelf as Node as RigidBody3D).freeze = true
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	_world.remove_entity(shelf)
	var observed_snapshots: Array[AnchoredBodySnapshot] = []
	var publications: Array[Entity] = []
	var inspect_anchor: Callable = func(actor: Entity) -> void:
		if actor.has_component(C_Anchorable):
			var marker: C_PlayerAnchored = actor.get_component(C_PlayerAnchored) as C_PlayerAnchored
			assert_not_null(marker)
			observed_snapshots.append(marker.snapshot)
			publications.append(actor)
			assert_true((actor as Node as RigidBody3D).freeze)
			assert_false(marker.snapshot.freeze)
			assert_eq(marker.snapshot.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
			assert_false(marker.snapshot.can_sleep)
	_world.entity_added.connect(inspect_anchor)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	_world.entity_added.disconnect(inspect_anchor)
	assert_eq(observed_snapshots.size(), 1)
	var retained: C_PlayerAnchored = publications[0].get_component(
		C_PlayerAnchored) as C_PlayerAnchored
	assert_same(retained.snapshot, observed_snapshots[0], "Fresh restore never replaces the marker")
#endregion
