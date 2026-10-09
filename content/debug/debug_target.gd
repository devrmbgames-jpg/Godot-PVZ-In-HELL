extends RefCounted
## Временный результат разбора консольной цели; хранит записи/живую Entity, не владея игровыми связями.
class_name DebugTarget

enum Kind {
	INVALID,
	ENTITY,
	PACKAGE,
	VISIT,
}

## Нормализованная исходная строка выбора цели.
var query: String = ""
## Какой контракт найден; INVALID сопровождается error.
var kind: Kind = Kind.INVALID
## Необязательная живая Entity; доступность повторно проверяется перед мутацией.
var entity: Entity = null
## Стабильный ID коробки, даже если физический экземпляр отсутствует.
var package_id: String = ""
## Необязательная запись регистрации для данной коробки.
var registration: PackageRegistrationRecord = null
## Необязательный случай обслуживания данного заказа.
var visit: CustomerVisit = null
## Причина неуспешного разрешения цели.
var error: String = ""
