extends Component
## Transient workflow: S_NightSave ведёт подготовку/retry; startup services пишут status.
## SnapshotRestoreBoundary инвалидирует queued context после restore; этот Component не сохраняется.
class_name C_Autosave

## Путь локального слота; пустой отключает хранение, сохраняя обязательную ночную подготовку.
## Предыдущий файл заменяется только после успешной записи временного.
@export var path: String = AutosaveStore.DEFAULT_PATH
## Operational storage retry seconds, independent of frozen gameplay ticks; bounded by S_NightSave.
@export var retry_seconds: float = 1.0
## S_NightSave отмечает Night day после evening closeout; это ещё не completion подготовки утра.
var started_night: int = 0
## S_NightSave/startup restore отмечают записанное/загруженное утро для Night gate.
var last_saved_morning: int = 0
## Последнее подготовленное утро без файла; не подтверждает сохранение. Владелец — S_NightSave.
var last_prepared_morning: int = 0
## S_NightSave decrements raw operational seconds; transient, never a gameplay timestamp.
var retry_remaining: float = 0.0
## Последний workflow Error S_NightSave: OK после write/preparation, иначе причина retry/refusal.
var last_error: Error = OK
## NightSaveService/GameSessionService задают startup пояснение для UI, включая отказ формата.
var startup_status: String = "Новое прохождение"
## S_NightSave owns the detached value graph after preflight/drain; I/O retries do not recapture.
var prepared_snapshot: Dictionary = { }
## S_NightSave retains one request; DistrictMorningPreparationRequest carries completion/success.
var preparation: DistrictMorningPreparationRequest = null
## S_NightSave sets before queuing/clears on execution; restore clears it to retire the old queue.
var work_queued: bool = false
## SnapshotRestoreBoundary increments to reject queued steps from before an in-place restore.
var revision: int = 0
## Startup services protect rejected slots; S_NightSave refuses that same path before reset.
var rejected_path: String = ""
## Startup services set on failed reconstruction; the level must abandon the unfinished World.
var construction_failed: bool = false
