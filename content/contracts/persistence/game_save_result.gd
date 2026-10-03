extends RefCounted
## Результат меню сохранений; snapshot содержит только проверенные сериализуемые данные.
class_name GameSaveResult

var success: bool = false
var message: String = ""
var path: String = ""
var snapshot: Dictionary = {}
