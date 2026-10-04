extends RefCounted
## Результат сканирования и регистрации для интерфейса; сам состояние мира не изменяет.
class_name PackageScanResult

enum Outcome {
	REJECTED,
	REGISTERED,
	ALREADY_REGISTERED,
}

## Итог сканирования: отказ, новая регистрация или уже существующая запись.
var outcome: Outcome = Outcome.REJECTED
## ID проверенной коробки, если она распознана.
var package_id: String = ""
## Регистрационный номер, ноль при отсутствии регистрации.
var number: int = 0
## Текст результата для игрока; не является игровым состоянием.
var message: String = "Нет доступной посылки"
