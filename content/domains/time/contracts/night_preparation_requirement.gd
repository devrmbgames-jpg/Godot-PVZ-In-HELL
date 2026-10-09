extends RefCounted
## Synchronous query о наличии Night preparation owner без зависимости Time от Persistence.
class_name NightPreparationRequirement

## Канал запроса перед night_started и phase_changed.
const EVENT: StringName = &"night_preparation_requirement"
var _required: bool = false

#region Preparation response
## Сообщает, что ночной owner должен завершить подготовку до следующего утра.
func require_preparation() -> void:
	_required = true


## Возвращает ответ участников текущего запроса.
func is_required() -> bool:
	return _required
#endregion
