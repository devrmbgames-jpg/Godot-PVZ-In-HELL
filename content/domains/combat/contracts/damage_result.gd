extends RefCounted
## Terminal результат O_Damage после его CommandBuffer resolution; исходный запрос не равен эффекту.
## HealthMutationService заполняет расчёт; O_Damage публикует EVENT для последующих реакций.
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

## HP до принятого расчёта; при раннем REJECTED остаётся default 0, не показание живой цели.
var previous_value: float = 0.0
## HP после принятого расчёта; при раннем REJECTED default 0 не означает смерть.
var current_value: float = 0.0
## Неотрицательная фактическая величина изменения HP, включая полезное лечение.
## Нулевой результат не подтверждает расход лечебного предмета.
var applied_amount: float = 0.0

## Global pose цели, снятая O_Damage до lifecycle реакций; default IDENTITY, если цели уже нет.
var world_pose: Transform3D = Transform3D.IDENTITY
## Machine-readable terminal reason from the sole damage handler.
var reason: StringName = &"target_unavailable"
