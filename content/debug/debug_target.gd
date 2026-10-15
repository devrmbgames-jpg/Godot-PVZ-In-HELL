extends RefCounted
## Временный результат разбора консольной цели; хранит записи/живую Entity, не владея игровыми
## связями.
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
## Заимствованная Entity; доступность проверяет вызывающий перед мутацией/после await.
var entity: Entity = null
## Стабильный ID коробки, даже если физический экземпляр отсутствует.
var package_id: String = ""
## Необязательная общая запись журнала, не копия; её writer остаётся в packages.
var registration: PackageRegistrationRecord = null
## Необязательный общий CustomerVisit, не копия; его writer остаётся в customers.
var visit: CustomerVisit = null
## Причина неуспешного разрешения цели.
var error: String = ""
