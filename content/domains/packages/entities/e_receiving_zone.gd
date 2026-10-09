@tool
extends E_ReceivingZoneBody
## Вывеска приёмки над native зоной, авторскими местами и runtime-машиной.
class_name E_ReceivingZone

const STATUS_REFRESH_SECONDS: float = 0.25
var _status_remaining: float = 0.0
@onready var _sign_label: Label3D = $Sign

#region Информация приёмки
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_status_remaining = maxf(0.0, _status_remaining - delta)
	if _status_remaining > 0.0:
		return
	_status_remaining = STATUS_REFRESH_SECONDS

	var receiving: C_Receiving = get_component(C_Receiving) as C_Receiving
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if receiving == null or cycle == null or supply == null:
		return

	_sign_label.text = "ПРИЁМКА · цикл %d\nПоставка: %d / %d%s" % [
		cycle.day_index,
		receiving.delivered_counts.get(cycle.day_index, 0),
		mini(supply.maximum_batch_packages, supply.packages.size()),
		"\nОсвободите место для оставшихся коробок" if receiving.blocked else "",
	]
	if cycle.phase == C_DayCycle.Phase.MORNING and truck_parking != null:
		var current_status: ReceivingShiftService.Status = ReceivingShiftService.status(cycle, self)
		_sign_label.text += "\n" + ("Разгрузка завершена" if current_status.reasons.is_empty() else "\n".join(current_status.reasons))
#endregion
