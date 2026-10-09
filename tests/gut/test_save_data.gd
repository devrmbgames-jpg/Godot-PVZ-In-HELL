extends GutTest
## Проверки закрытой схемы данных и атомарной записи слота; живые Node и временные блокировки не сериализуются.

const SAVE_PATH: String = "user://gut_r21_autosave.pvzh"


#region Очистка тестового слота
## Удаляет только тестовый слот и его временный файл атомарной записи.
func after_each() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


#endregion

#region Схема данных и атомарное хранилище
## Round-trip спора сохраняет факт, заявление, расчёт и личность участника ответного нападения.
func test_customer_dispute_round_trip_keeps_actual_declaration_and_retaliation_identity() -> void:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"customer:11:tools"
	visit.package_id = "parcel:1:tools"
	visit.arrival_day = 11
	visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	visit.declaration = CustomerVisit.Declaration.TAKEN
	visit.settlement_committed = true
	visit.settlement_day = 11
	visit.money_delta = -150
	visit.complaint = CustomerComplaint.new()
	visit.last_combat_context = CombatContext.new()
	visit.last_combat_context.visit_id = visit.visit_id
	visit.last_combat_context.day = 12

	var decoded: CustomerVisit = SaveDataCodec.decode(SaveDataCodec.encode(visit)) as CustomerVisit
	assert_not_null(decoded)
	if decoded == null:
		return

	assert_eq(decoded.visit_id, visit.visit_id)
	assert_eq(decoded.package_id, visit.package_id)
	assert_eq(decoded.actual, visit.actual)
	assert_eq(decoded.declaration, visit.declaration)
	assert_eq(decoded.settlement_day, 11)
	assert_true(decoded.settlement_committed)
	assert_eq(decoded.money_delta, -150)
	assert_eq(decoded.last_combat_context.visit_id, visit.visit_id)
	assert_eq(decoded.last_combat_context.day, 12)
	assert_ne(decoded.complaint, visit.complaint)


## Авторское определение предмета остаётся каноническим; временные блокировки передачи не сохраняются.
func test_inventory_definition_remains_canonical_and_transient_locks_are_excluded() -> void:
	var original: C_InventoryItem = C_InventoryItem.new()
	original.definition = load("res://content/domains/inventory/definitions/def_item_food.tres") as DEF_InventoryItem
	original.quantity = 4
	original.pending_use_id = &"temporary"
	original.transfer_in_progress = true
	var data: Dictionary = SaveDataCodec.component_data(original)
	var restored: C_InventoryItem = C_InventoryItem.new()
	assert_true(SaveDataCodec.apply_fields(restored, data.fields as Dictionary))
	assert_eq(restored.definition, original.definition)
	assert_eq(restored.quantity, 4)
	assert_false(restored.transfer_in_progress)
	assert_eq(restored.pending_use_id, &"")
	assert_false((data.fields as Dictionary).has("transfer_in_progress"))


## Типизированные ресурсы заказов и словарь поставок восстанавливают значения и ссылки на определения.
func test_typed_resource_arrays_and_receiving_dictionary_round_trip() -> void:
	var commerce: C_Commerce = C_Commerce.new()
	var delivery: PendingDelivery = PendingDelivery.new()
	delivery.delivery_id = &"order:1:1"
	delivery.item = commerce.catalog[0]
	delivery.quantity = 3
	delivery.fulfilled = true
	commerce.pending_deliveries.append(delivery)
	commerce.next_request = 7

	var copied: C_Commerce = C_Commerce.new()
	assert_true(SaveDataCodec.apply_fields(copied, SaveDataCodec.component_data(commerce).fields as Dictionary))
	assert_eq(copied.pending_deliveries.size(), 1)
	if copied.pending_deliveries.is_empty():
		return

	assert_true(copied.pending_deliveries[0].fulfilled)
	assert_eq(copied.pending_deliveries[0].item, commerce.catalog[0])
	assert_eq(copied.next_request, 7)
	var receiving: C_Receiving = C_Receiving.new()
	receiving.last_started_day = 9
	receiving.delivered_counts[9] = 8
	var batch: ReceivingBatch = ReceivingBatch.new()
	batch.day_index = 10
	batch.next_package = 4
	receiving.pending.append(batch)

	var other: C_Receiving = C_Receiving.new()
	assert_true(SaveDataCodec.apply_fields(other, SaveDataCodec.component_data(receiving).fields as Dictionary))
	assert_eq(other.delivered_counts.get(9), 8)
	assert_eq(other.pending[0].next_package, 4)


## Повторная атомарная запись заменяет слот, сохраняя native Transform3D и массивы точек.
func test_store_replaces_same_slot_and_preserves_native_physical_values() -> void:
	var pose: Transform3D = Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.3)), Vector3(1, 2, 3))
	var data: Dictionary = {"version": 1, "day": 2, "pose": pose, "ink": PackedVector3Array([Vector3.ONE, Vector3.UP])}
	assert_eq(AutosaveStore.write(data, SAVE_PATH), OK)
	assert_eq(AutosaveStore.read(SAVE_PATH), data)
	data.day = 3
	assert_eq(AutosaveStore.write(data, SAVE_PATH), OK)
	assert_eq(AutosaveStore.read(SAVE_PATH).day, 3)
	assert_false(FileAccess.file_exists(SAVE_PATH + ".tmp"))


## Отсутствующий, повреждённый или обрезанный файл даёт пустой результат чтения.
func test_missing_corrupt_and_truncated_slot_are_safe() -> void:
	assert_true(AutosaveStore.read(SAVE_PATH).is_empty())
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	assert_true(AutosaveStore.read(SAVE_PATH).is_empty())
	assert_eq(AutosaveStore.write({"day": 2}, SAVE_PATH), OK)
	file = FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE)
	file.seek_end(-1)
	file.store_8(255)
	file.close()
	assert_true(AutosaveStore.read(SAVE_PATH).is_empty())


## Закрытая схема отклоняет посторонние скрипты, неверные типы, transient-поля и живые Node.
func test_unknown_script_fields_wrong_types_and_runtime_objects_are_rejected() -> void:
	assert_null(SaveDataCodec.decode({"type": "res://content/scenes/main_level.gd", "fields": {}}))
	assert_null(SaveDataCodec.decode({"definition": "res://project.godot"}))
	var item: C_InventoryItem = C_InventoryItem.new()
	assert_false(SaveDataCodec.apply_fields(item, {"quantity": "three"}))
	assert_false(SaveDataCodec.apply_fields(item, {"definition": 3}))
	assert_false(SaveDataCodec.apply_fields(item, {"pending_use_id": &"bad"}))
	var node: Node = Node.new()
	var encoded: Dictionary = SaveDataCodec.encode(node) as Dictionary
	node.free()
	assert_true(encoded.get("invalid", false))

#endregion
