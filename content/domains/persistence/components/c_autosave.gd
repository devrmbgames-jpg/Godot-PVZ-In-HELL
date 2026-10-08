extends Component
## Временное состояние ночной записи: однократная подготовка, задержка ретрая и результат.
class_name C_Autosave

## Путь локального слота; предыдущий файл заменяется после успешной записи временного.
@export var path: String = AutosaveStore.DEFAULT_PATH
## Задержка повторной попытки в секундах; сервис ограничивает её снизу.
@export var retry_seconds: float = 1.0
## Последний день однократной ночной подготовки; повтор не завершает обещания снова.
var started_night: int = 0
## Последнее успешно записанное утро; совпадение разрешает выход из ночи.
var last_saved_morning: int = 0
## Оставшееся время до попытки записи в секундах.
var retry_remaining: float = 0.0
## Результат последней проверки/записи сохранения.
var last_error: Error = OK
## Пояснение восстановления для интерфейса, включая несовместимый формат.
var startup_status: String = "Новое прохождение"
## Prepared value-only snapshot; retries never recapture live gameplay state.
var prepared_snapshot: Dictionary = {}
## Sole transient preparation request for this Night.
var preparation: DistrictMorningPreparationRequest = null
## Prevents duplicate queued steps for the same workflow.
var work_queued: bool = false
## Invalidates queued steps after an in-place restore.
var revision: int = 0
## Existing rejected slot protected against subsequent automatic writes.
var rejected_path: String = ""
## Failed construction of a prevalidated startup requires abandoning the world.
var construction_failed: bool = false
