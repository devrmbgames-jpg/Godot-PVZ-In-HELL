extends DEF_ChallengeCondition
## Авторское требование состояния конкретной световой цепи.
class_name DEF_LightChallengeCondition

## Постоянный ID проверяемой цепи.
@export var circuit_id: StringName = &"warehouse"
## Нужное состояние выключателя для выполнения условия.
@export var required_enabled: bool = false
## Прежний клиент с условием при прибытии ждёт у Entry до выключения цепи.
@export var wait_outside_until_dark: bool = false
## Интервал визуального мерцания в секундах.
@export_range(0.05, 2.0) var flicker_interval_seconds: float = 0.15
