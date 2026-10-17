extends RefCounted
## Фактически законченная BASE_SUPPLY; отложенные покупки не публикуют этот факт.
class_name ReceivingSupplyCompleted

## Потребители фиксируют собственный результат по batch_id; повтор доставки факта допустим.
const EVENT: StringName = &"receiving_supply_completed"
## Точный receiving owner на момент окончания; queued потребитель проверяет его incarnation.
var receiving: C_Receiving
## Завершённая реальная партия, не план будущей поставки.
var batch_id: String
## Календарный день этой партии.
var day_index: int
## Реально зарегистрированные ID из manifest; пропущенные позиции без поступления не включаются.
var package_ids: PackedStringArray = []
## Реальные извлекаемые типы груза по архивным arrival records; не общий каталог.
var items: Array[DEF_InventoryItem] = []


#region Detached факт поставки
## Копирует только уже подтверждённые arrival records текущей партии; live тела не удерживает.
func _init(owner: C_Receiving, registry: C_PackageLedger) -> void:
	receiving = owner
	batch_id = owner.batch_id
	day_index = owner.last_started_day
	if registry == null:
		return
	for entry: PackageRegistrationRecord in registry.records:
		if entry.package_id not in owner.incoming_package_ids or entry.received_day != day_index:
			continue
		package_ids.append(entry.package_id)
		if (
			entry.ordered_item != null and entry.ordered_quantity > 0
			and entry.ordered_item not in items
		):
			items.append(entry.ordered_item)
#endregion
