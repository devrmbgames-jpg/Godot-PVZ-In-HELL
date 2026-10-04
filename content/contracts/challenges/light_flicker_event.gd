extends RefCounted
## Запрос мерцания ламп; enabled цепи сохраняет состояние игрового выключателя.
class_name LightFlickerEvent

## Имя мирового события с этим типизированным запросом.
const EVENT: StringName = &"light_flickering"
## Стартовый интервал смены видимости лампы в секундах.
const DEFAULT_INTERVAL_SECONDS: float = 0.15

enum Kind { START, STOP }

## Запуск или отмена запроса мерцания.
var kind: Kind = Kind.START
## ID запроса; отмена действует только на совпадающий активный запрос.
var request_id: StringName = &""
## Постоянный ID адресуемой цепи.
var circuit_id: StringName = &"warehouse"
## Продолжительность мерцания в секундах; для START должна быть положительной.
var duration_seconds: float = 0.0
## Положительный интервал чередования видимости в секундах.
var interval_seconds: float = DEFAULT_INTERVAL_SECONDS
