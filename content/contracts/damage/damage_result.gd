extends RefCounted
## Результат обработки здоровья с запросом и атрибуцией для дальнейшего жизненного цикла.
class_name DamageResult

## Мировое событие с типизированным результатом здоровья.
const EVENT: StringName = &"health_damage_resolved"

enum Outcome {
	REJECTED,
	BLOCKED,
	APPLIED,
	HEALTH_DEPLETED,
}

## Снимок исходного запроса, отдельно от реально применённой суммы.
var request: DamageRequest = null
## Отклонение, блокировка, применение или переход к истощению здоровья.
var outcome: Outcome = Outcome.REJECTED

## Здоровье до принятого расчёта; отклонённый запрос может оставить 0.
var previous_value: float = 0.0
## Здоровье после принятого расчёта.
var current_value: float = 0.0
## Абсолютное фактическое изменение здоровья, включая полезное лечение.
var applied_amount: float = 0.0

## Мировая поза цели до последующих реакций жизненного цикла и удаления.
var world_pose: Transform3D = Transform3D.IDENTITY
