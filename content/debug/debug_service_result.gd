extends RefCounted
## Результат отладочного адаптера: принятие запроса, пояснение и строки диагностики.
class_name DebugServiceResult

## Запрос принят адаптером; отложенный физический результат может наступить позже.
var success: bool = false
## Пояснение принятия или причина отказа.
var message: String = ""
## Строки фактического контекста для вывода команды.
var details: PackedStringArray = []
