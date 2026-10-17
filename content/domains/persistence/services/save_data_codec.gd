extends RefCounted
## Закрытая схема постоянных данных без Node, Object ID, произвольных Script и живых Relationships.
class_name SaveDataCodec

static var _component_fields: Dictionary = {
	C_DayCycle: C_DayCycle.SAVE_FIELDS,
	C_Wallet: C_Wallet.SAVE_FIELDS,
	C_PackageLedger: C_PackageLedger.SAVE_FIELDS,
	C_CustomerFlow: C_CustomerFlow.SAVE_FIELDS,
	C_District: C_District.SAVE_FIELDS,
	C_NpcIdentity: C_NpcIdentity.SAVE_FIELDS,
	C_NpcAddress: C_NpcAddress.SAVE_FIELDS,
	C_DamageResistance: C_DamageResistance.SAVE_FIELDS,
	C_Commerce: C_Commerce.SAVE_FIELDS,
	C_QuestSession: C_QuestSession.SAVE_FIELDS,
	C_Inventory: C_Inventory.SAVE_FIELDS,
	C_InventoryItem: C_InventoryItem.SAVE_FIELDS,
	C_Package: C_Package.SAVE_FIELDS,
	C_PackageState: C_PackageState.SAVE_FIELDS,
	C_PackageContents: C_PackageContents.SAVE_FIELDS,
	C_NpcRemains: C_NpcRemains.SAVE_FIELDS,
	C_LootDrops: C_LootDrops.SAVE_FIELDS,
	C_Health: C_Health.SAVE_FIELDS,
	C_Strength: C_Strength.SAVE_FIELDS,
	C_SoulTrade: C_SoulTrade.SAVE_FIELDS,
	C_Karma: C_Karma.SAVE_FIELDS,
	C_Hunger: C_Hunger.SAVE_FIELDS,
	C_Stamina: C_Stamina.SAVE_FIELDS,
	C_ImpactProtection: C_ImpactProtection.SAVE_FIELDS,
	C_Receiving: C_Receiving.SAVE_FIELDS,
	C_Openable: C_Openable.SAVE_FIELDS,
	C_LightCircuit: C_LightCircuit.SAVE_FIELDS,
	C_HazardEmitter: C_HazardEmitter.SAVE_FIELDS,
	C_Hazard: C_Hazard.SAVE_FIELDS,
	C_HazardLifetime: C_HazardLifetime.SAVE_FIELDS,
	C_PersistentIdentity: C_PersistentIdentity.SAVE_FIELDS,
	C_InteractionToggle: C_InteractionToggle.SAVE_FIELDS,
	C_ToxicArea: C_ToxicArea.SAVE_FIELDS,
	C_BloodArea: C_BloodArea.SAVE_FIELDS,
	C_Explosion: C_Explosion.SAVE_FIELDS,
	C_NoDamage: C_NoDamage.SAVE_FIELDS,
}
static var _record_types: Array[Script] = [
	GameClock,
	NpcRecord,
	NpcDeathRecord,
	NpcVariation,
	NpcMemory,
	NpcHomeDelivery,
	CustomerVisit,
	CustomerParcelIncident,
	CustomerComplaint,
	CombatContext,
	MoneyOperation,
	DailyMoneyResult,
	PackageRegistrationRecord,
	PurchaseReceipt,
	PendingDelivery,
	RefusalQuestRecord,
	ReceivingBatch,
	TruckCargoReceipt,
	PendingLootDrop,
	SoulTradeRecord,
	BloodConsentRecord,
]
## Максимальная глубина вложенных сериализуемых данных.
const MAX_DEPTH: int = 16


#region Кодирование и декодирование
## Кодирует только разрешённые поля известного компонента; неизвестный тип даёт пустой словарь.
static func component_data(component: Component) -> Dictionary:
	var script: Script = component.get_script() as Script
	if not _component_fields.has(script):
		return { }

	var fields: Dictionary = { }
	for field: String in _component_fields[script]:
		fields[field] = encode(component.get(field))
	return { "type": script.resource_path, "fields": fields }


## Кодирует известный snapshot value graph; records по whitelist, Definitions по immutable пути.
## Unsupported Object/Resource или глубина > MAX_DEPTH дают invalid envelope. Это не semantic
## preflight произвольного Dictionary: caller обязан проверить итоговый snapshot через can_restore.
static func encode(value: Variant, depth: int = 0) -> Variant:
	if depth > MAX_DEPTH:
		return { "invalid": true }
	if value is GameDefinition:
		var definition: GameDefinition = value as GameDefinition
		return { "definition": definition.resource_path }
	if value is Resource:
		var resource: Resource = value as Resource
		var script: Script = resource.get_script() as Script
		if script not in _record_types:
			return { "invalid": true }

		var fields: Dictionary = { }
		for property: Dictionary in resource.get_property_list():
			var name: String = String(property.name)
			if (
				int(property.usage) & PROPERTY_USAGE_STORAGE
				and name
				not in ["script", "resource_name", "resource_local_to_scene", "resource_path"]
			):
				if resource is NpcRecord and name in ["dialogue_tags", "dialogue_values"]:
					fields[name] = DialogueValueCodec.encode(
						resource.get(name), "%s.%s" % [(resource as NpcRecord).npc_id, name],
						MAX_DEPTH,
					)
				else:
					fields[name] = encode(resource.get(name), depth + 1)
		return { "type": script.resource_path, "fields": fields }
	if value is Array:
		var encoded_collection: Array = []
		for entry: Variant in value:
			encoded_collection.append(encode(entry, depth + 1))
		return encoded_collection
	if value is Dictionary:
		var encoded_collection: Dictionary = { }
		for key: Variant in value:
			encoded_collection[key] = encode(value[key], depth + 1)
		return encoded_collection
	if value is Object:
		return { "invalid": true }
	if value is PackedStringArray:
		return (value as PackedStringArray).duplicate()
	return value


## Decodes supported envelopes into shared immutable Definitions/new owned record Resources.
## null can mean encoded null or an invalid envelope/depth; apply_fields checks type/null contracts.
## Not a standalone untrusted-input gate: full snapshot validation belongs to can_restore.
static func decode(value: Variant, depth: int = 0) -> Variant:
	if depth > MAX_DEPTH:
		return null
	if value is Array:
		var decoded_collection: Array = []
		for entry: Variant in value:
			decoded_collection.append(decode(entry, depth + 1))
		return decoded_collection
	if value is Dictionary:
		var encoded_record: Dictionary = value as Dictionary
		if encoded_record.has("definition"):
			var path: String = String(encoded_record.definition)
			if (
				not GameplayResourcePaths.is_definition_path(path)
				or not ResourceLoader.exists(path)
			):
				return null
			return load(path) as GameDefinition
		if encoded_record.has("type"):
			var script: Script = record_script(String(encoded_record.type))
			if script == null or not encoded_record.get("fields") is Dictionary:
				return null

			var resource: Resource = script.new() as Resource
			if not apply_fields(resource, encoded_record.fields as Dictionary, depth + 1):
				return null
			return resource

		var decoded_collection: Dictionary = { }
		for key: Variant in encoded_record:
			decoded_collection[key] = decode(encoded_record[key], depth + 1)
		return decoded_collection
	if value is PackedStringArray:
		return (value as PackedStringArray).duplicate()
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
## Checks field names/count only; it does not validate encoded values or prefab capability.
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


## Проверяет/пишет поля и typed containers последовательно; false может оставить частичную запись.
## Preflight использует отдельную заготовку; live overlay — только после полной проверки snapshot.
## True подтверждает codec/type contract, не все domain invariants или готовность World.
static func apply_fields(resource: Resource, fields: Dictionary, depth: int = 0) -> bool:
	var script: Script = resource.get_script() as Script
	if script == CustomerVisit and not fields.has("absence_sequence"):
		return false
	if script in [
		GameClock,
		NpcVariation,
		NpcRecord,
		NpcDeathRecord,
		ReceivingBatch,
		CustomerParcelIncident,
		PackageRegistrationRecord,
		SoulTradeRecord,
		BloodConsentRecord,
	]:
		var exact_fields: Array[String] = GameClock.SAVE_FIELDS
		if script == NpcVariation:
			exact_fields = NpcVariation.SAVE_FIELDS
		elif script == NpcRecord:
			exact_fields = NpcRecord.SAVE_FIELDS
		elif script == NpcDeathRecord:
			exact_fields = NpcDeathRecord.SAVE_FIELDS
		elif script == ReceivingBatch:
			exact_fields = ReceivingBatch.SAVE_FIELDS
		elif script == CustomerParcelIncident:
			exact_fields = CustomerParcelIncident.SAVE_FIELDS
		elif script == PackageRegistrationRecord:
			exact_fields = PackageRegistrationRecord.SAVE_FIELDS
		elif script == SoulTradeRecord:
			exact_fields = SoulTradeRecord.SAVE_FIELDS
		elif script == BloodConsentRecord:
			exact_fields = BloodConsentRecord.SAVE_FIELDS
		if fields.size() != exact_fields.size():
			return false
		for required_field: String in exact_fields:
			if not fields.has(required_field):
				return false
	var allowed: Array = _component_fields.get(script, []) as Array
	if script in _record_types:
		for property: Dictionary in resource.get_property_list():
			if (
				int(property.usage) & PROPERTY_USAGE_STORAGE
				and String(property.name)
				not in ["script", "resource_name", "resource_local_to_scene", "resource_path"]
			):
				allowed.append(String(property.name))
	var schema: Dictionary = { }
	for property: Dictionary in resource.get_property_list():
		schema[String(property.name)] = property
	for field: Variant in fields:
		if not field is String or field not in allowed or depth > MAX_DEPTH:
			return false

		var decoded: Variant = null
		if resource is NpcRecord and field in ["dialogue_tags", "dialogue_values"]:
			var author_value: Dictionary = DialogueValueCodec.decode(fields[field], MAX_DEPTH)
			if not author_value.ok:
				return false
			decoded = author_value.value
		else:
			decoded = decode(fields[field], depth + 1)
		var current: Variant = resource.get(field)
		if fields[field] != null and decoded == null:
			return false

		var property: Dictionary = schema.get(field, { }) as Dictionary
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
					if (
						required != null
						and (not entry is Resource or (entry as Resource).get_script() != required)
					):
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
					if (
						(target.is_typed_key() and typeof(key) != target.get_typed_key_builtin())
						or (
							target.is_typed_value()
							and typeof(values[key]) != target.get_typed_value_builtin()
						)
					):
						return false

			target.assign(values)
			resource.set(field, target)
		else:
			if current != null and typeof(current) != typeof(decoded):
				return false
			if (
				decoded is Resource and current is Resource
				and (decoded as Resource).get_script() != (current as Resource).get_script()
			):
				return false

			resource.set(field, decoded)
	if resource is GameClock:
		return GameTimeRules.valid(resource as GameClock)
	if resource is C_SoulTrade:
		return SoulTradeRules.valid(resource as C_SoulTrade)
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
