extends RefCounted
## Типизированное событие состояния коробки; последствия для опасностей и клиентов применяют подписчики.
class_name PackageLifecycleEvent

## Постоянный канал World для передачи этой записи события.
const EVENT: StringName = &"package_lifecycle"

enum Kind {
	Damaged,
	Destroyed,
	Opened,
	Leaking,
}

## Стабильный ID коробки сохраняется после удаления физической сущности.
var package_id: String = ""
## Живая коробка на момент события; подписчик проверяет её доступность.
var package: Entity = null
## Инициатор вскрытия либо известный источник урона.
var actor: Entity = null
## Captured initiator identity survives removal before deferred contents release.
var actor_id: String = ""
## Зафиксированный переход состояния коробки.
var kind: Kind = Kind.Damaged
## Причина урона для повреждения и уничтожения, иначе null.
var cause: DamageResult = null
