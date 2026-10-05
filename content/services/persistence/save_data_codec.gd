extends RefCounted
## Закрытая схема постоянных данных без Node, Object ID, произвольных Script и живых Relationships.
class_name SaveDataCodec

static var _component_fields: Dictionary = {
	C_DayCycle: ["phase", "day_index"],
	C_Wallet: ["balance", "penalties", "completed_days", "operations", "daily_results"],
	C_PackageLedger: ["records", "history_sequence_day", "next_history_number", "last_departed_package_id"],
	C_CustomerFlow: ["planned_through_day", "visits"],
	C_District: ["definition", "people", "home_deliveries", "delivery_offer_day", "terminal_offer_target", "delivery_considered", "next_incident", "next_person", "prepared_morning", "replacement_morning", "conflict_phase", "ambient_conflicts", "next_service_order"],
	C_NpcIdentity: ["npc_id"],
	C_DamageResistance: ["multipliers"],
	C_Commerce: ["receipts", "pending_deliveries", "next_request"],
	C_QuestSession: ["records"],
	C_Inventory: ["maximum_stacks"],
	C_InventoryItem: ["definition", "quantity"],
	C_Package: ["package_id", "history_id", "definition", "delivery_day", "supply_key"],
	C_PackageState: ["registration", "scan", "opening", "damage", "registration_number", "registration_day", "leaking"],
	C_PackageContents: ["released"],
	C_NpcRemains: ["released"],
	C_LootDrops: ["placement", "pending", "committed_batches"],
	C_Health: ["base", "value", "current", "depleted"],
	C_Hunger: ["value"],
	C_Stamina: ["current", "initialized"],
	C_ImpactProtection: ["tier"],
	C_Receiving: ["last_started_day", "pending", "delivered_counts"],
	C_Openable: ["locked", "requested_open", "actual_fraction"],
	C_LightCircuit: ["enabled"],
	C_HazardEmitter: ["fired", "sequence"],
	C_Hazard: ["definition", "request_id", "origin_id", "instigator_id"],
	C_HazardLifetime: ["remaining_seconds", "persistent", "awaiting_resolution"],
	C_PersistentIdentity: ["key"],
	C_InteractionToggle: ["active"],
	C_ToxicArea: ["tick_elapsed"],
	C_Explosion: ["resolved"],
	C_NoDamage: [],
}
static var _record_types: Array[Script] = [NpcRecord, NpcMemory, NpcHomeDelivery, CustomerVisit, CustomerComplaint, CombatContext, MoneyOperation, DailyMoneyResult, PackageRegistrationRecord, PurchaseReceipt, PendingDelivery, RefusalQuestRecord, ReceivingBatch, PendingLootDrop]
## Максимальная глубина вложенных сериализуемых данных.
const MAX_DEPTH: int = 16


#region Кодирование и декодирование
## Кодирует только разрешённые поля известного компонента; неизвестный тип даёт пустой словарь.
static func component_data(component: Component) -> Dictionary:
	var script: Script = component.get_script() as Script
	if not _component_fields.has(script):
		return {}

	var fields: Dictionary = {}
	for field: String in _component_fields[script]:
		fields[field] = encode(component.get(field))
	return {"type": script.resource_path, "fields": fields}


## Кодирует ресурсы по закрытому списку и определения по пути; неподдерживаемое значение помечает invalid.
static func encode(value: Variant, depth: int = 0) -> Variant:
	if depth > MAX_DEPTH:
		return {"invalid": true}
	if value is GameDefinition:
		var definition: GameDefinition = value as GameDefinition
		return {"definition": definition.resource_path}
	if value is Resource:
		var resource: Resource = value as Resource
		var script: Script = resource.get_script() as Script
		if script not in _record_types:
			return {"invalid": true}

		var fields: Dictionary = {}
		for property: Dictionary in resource.get_property_list():
			var name: String = String(property.name)
			if int(property.usage) & PROPERTY_USAGE_STORAGE and name not in ["script", "resource_name", "resource_local_to_scene", "resource_path"]:
				fields[name] = encode(resource.get(name), depth + 1)
		return {"type": script.resource_path, "fields": fields}
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(encode(entry, depth + 1))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = encode(value[key], depth + 1)
		return result
	if value is Object:
		return {"invalid": true}
	return value


## Восстанавливает разрешённые определения/записи и вложенные данные; неверный тип/глубина даёт null.
static func decode(value: Variant, depth: int = 0) -> Variant:
	if depth > MAX_DEPTH:
		return null
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(decode(entry, depth + 1))
		return result
	if value is Dictionary:
		var data: Dictionary = value as Dictionary
		if data.has("definition"):
			var path: String = String(data.definition)
			if not path.begins_with("res://content/definitions/") or not ResourceLoader.exists(path):
				return null
			return load(path) as GameDefinition
		if data.has("type"):
			var script: Script = record_script(String(data.type))
			if script == null or not data.get("fields") is Dictionary:
				return null

			var resource: Resource = script.new() as Resource
			if not apply_fields(resource, data.fields as Dictionary, depth + 1):
				return null
			return resource

		var result: Dictionary = {}
		for key: Variant in data:
			result[key] = decode(data[key], depth + 1)
		return result
	return value


#endregion

#region Закрытая схема и применение полей
## Возвращает только разрешённый Script постоянной записи по точному пути.
static func record_script(path: String) -> Script:
	for script: Script in _record_types:
		if script.resource_path == path:
			return script
	return null


## Возвращает только разрешённый Script компонента по точному пути.
static func component_script(path: String) -> Script:
	for script: Script in _component_fields:
		if script.resource_path == path:
			return script
	return null


## Проверяет точный набор полей компонента без применения значений.
static func complete_component_data(script: Script, fields: Dictionary) -> bool:
	if not _component_fields.has(script):
		return false

	var expected: Array = _component_fields[script] as Array
	if fields.size() != expected.size():
		return false

	for field: String in expected:
		if not fields.has(field):
			return false
	return true


## Последовательно проверяет и записывает разрешённые поля; полная валидация использует отдельную заготовку.
static func apply_fields(resource: Resource, fields: Dictionary, depth: int = 0) -> bool:
	var script: Script = resource.get_script() as Script
	var allowed: Array = _component_fields.get(script, []) as Array
	if script in _record_types:
		for property: Dictionary in resource.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and String(property.name) not in ["script", "resource_name", "resource_local_to_scene", "resource_path"]:
				allowed.append(String(property.name))
	var schema: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		schema[String(property.name)] = property
	for field: Variant in fields:
		if not field is String or field not in allowed or depth > MAX_DEPTH:
			return false

		var decoded: Variant = decode(fields[field], depth + 1)
		var current: Variant = resource.get(field)
		if fields[field] != null and decoded == null:
			return false

		var property: Dictionary = schema.get(field, {}) as Dictionary
		if property.is_empty() or (decoded != null and typeof(decoded) != int(property.type)):
			return false
		if decoded is Resource and int(property.hint) == PROPERTY_HINT_RESOURCE_TYPE:
			var actual: Script = (decoded as Resource).get_script() as Script
			if not _script_matches(actual, StringName(property.hint_string)):
				return false
		if current is Array:
			if not decoded is Array:
				return false

			var target: Array = current as Array
			var values: Array = decoded as Array
			if target.is_typed():
				for entry: Variant in values:
					if typeof(entry) != target.get_typed_builtin():
						return false

					var required: Script = target.get_typed_script() as Script
					if required != null and (not entry is Resource or (entry as Resource).get_script() != required):
						return false

			target.assign(values)
			resource.set(field, target)
		elif current is Dictionary:
			if not decoded is Dictionary:
				return false

			var target: Dictionary = current as Dictionary
			var values: Dictionary = decoded as Dictionary
			if target.is_typed():
				for key: Variant in values:
					if typeof(key) != target.get_typed_key_builtin() or typeof(values[key]) != target.get_typed_value_builtin():
						return false

			target.assign(values)
			resource.set(field, target)
		else:
			if current != null and typeof(current) != typeof(decoded):
				return false
			if decoded is Resource and current is Resource and (decoded as Resource).get_script() != (current as Resource).get_script():
				return false

			resource.set(field, decoded)
	return true


#endregion

#region Проверка типа ресурса
static func _script_matches(actual: Script, expected: StringName) -> bool:
	while actual != null:
		if actual.get_global_name() == expected:
			return true

		actual = actual.get_base_script()
	return false

#endregion
