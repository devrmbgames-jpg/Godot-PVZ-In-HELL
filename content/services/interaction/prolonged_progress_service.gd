extends RefCounted
## Вычисляет прогресс детерминированно; эффекты и захват управления принадлежат исполнителю.
class_name ProlongedProgressService

const COMPLETE_FRACTION: float = 1.0


#region Изменение прогресса
## Продвигает прогресс на delta секунд; true означает готовность к последней проверке исполнителя.
## Готовность не подтверждает эффект: завершение фиксирует только commit_success.
static func advance(
	progress: ProlongedInteractionProgress,
	definition: DEF_ProlongedInteraction,
	delta: float,
	active: bool,
) -> bool:
	if not _valid(progress, definition) or not is_finite(delta) or delta < 0.0:
		return false
	if progress.phase == ProlongedInteractionProgress.Phase.COMPLETED:
		return false
	if not active:
		interrupt(progress, definition)
		if definition.reset_policy == DEF_ProlongedInteraction.ResetPolicy.DECAY:
			progress.fraction = maxf(0.0, progress.fraction - definition.decay_per_second * delta)
		return false
	if progress.phase == ProlongedInteractionProgress.Phase.WAITING_FOR_RELEASE:
		return false

	progress.fraction = clampf(progress.fraction + delta / definition.duration_seconds, 0.0, COMPLETE_FRACTION)
	if progress.fraction >= COMPLETE_FRACTION:
		progress.phase = ProlongedInteractionProgress.Phase.READY
		return true

	progress.phase = ProlongedInteractionProgress.Phase.ADVANCING
	return false


## Вызывается после успешной фиксации эффекта в той же синхронной транзакции;
## при отказе проверки или эффекта исполнитель вызывает interrupt.
static func commit_success(
	progress: ProlongedInteractionProgress,
	definition: DEF_ProlongedInteraction,
) -> bool:
	if not _valid(progress, definition):
		return false
	if progress.phase != ProlongedInteractionProgress.Phase.READY or progress.fraction < COMPLETE_FRACTION:
		return false
	if definition.reset_policy == DEF_ProlongedInteraction.ResetPolicy.NEVER:
		progress.phase = ProlongedInteractionProgress.Phase.COMPLETED
	else:
		# Одно завершение за непрерывное удержание, включая повторяемые ON_COMPLETE-действия.
		progress.phase = ProlongedInteractionProgress.Phase.WAITING_FOR_RELEASE
		if definition.reset_policy == DEF_ProlongedInteraction.ResetPolicy.ON_COMPLETE:
			progress.fraction = 0.0
	return true


## Применяет авторское прерывание при отпускании, потере управления, смене или исчезновении цели.
## Меняет только прогресс; связь участия и токен освобождает владелец сеанса.
static func interrupt(
	progress: ProlongedInteractionProgress,
	definition: DEF_ProlongedInteraction,
) -> void:
	if not _valid(progress, definition):
		return
	if progress.phase == ProlongedInteractionProgress.Phase.COMPLETED:
		return
	if definition.reset_policy == DEF_ProlongedInteraction.ResetPolicy.INSTANT:
		progress.fraction = 0.0
	progress.phase = ProlongedInteractionProgress.Phase.IDLE


#endregion

#region Допустимость авторских данных
static func _valid(
	progress: ProlongedInteractionProgress,
	definition: DEF_ProlongedInteraction,
) -> bool:
	return (
		progress != null and definition != null
		and progress.phase >= ProlongedInteractionProgress.Phase.IDLE
		and progress.phase <= ProlongedInteractionProgress.Phase.COMPLETED
		and is_finite(progress.fraction)
		and progress.fraction >= 0.0 and progress.fraction <= COMPLETE_FRACTION
		and is_finite(definition.duration_seconds) and definition.duration_seconds > 0.0
		and is_finite(definition.decay_per_second) and definition.decay_per_second >= 0.0
		and definition.reset_policy >= DEF_ProlongedInteraction.ResetPolicy.DECAY
		and definition.reset_policy <= DEF_ProlongedInteraction.ResetPolicy.NEVER
	)

#endregion
