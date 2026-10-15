extends RefCounted
## Synchronous query о наличии Night preparation owner без зависимости Time от Persistence.
## Ответ заполняется внутри emit_event; queued ответ не успеет удержать текущий переход в Night.
class_name NightPreparationRequirement

## Канал запроса перед night_started и phase_changed.
const EVENT: StringName = &"night_preparation_requirement"
var _required: bool = false


#region Preparation response
## Синхронный listener отмечает требование; повтор idempotent, это не completion подготовки.
func require_preparation() -> void:
	_required = true


## Возвращает ответ участников текущего запроса.
func is_required() -> bool:
	return _required
#endregion
