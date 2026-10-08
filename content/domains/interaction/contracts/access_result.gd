extends RefCounted
## Временный результат проверки доступа; не заменяет авторитетное владение и повторную проверку.
class_name AccessResult

enum Outcome { ALLOWED, ACTOR_UNAVAILABLE, ITEM_REQUIRED, CONSUMPTION_UNAVAILABLE, INVALID_REQUIREMENT }

## Результат проверки требования и возможности расходования.
var outcome: Outcome = Outcome.ITEM_REQUIRED
## Конкретный подходящий живой предмет, если он найден.
var item: Entity = null
## Адаптер источника найденного предмета для последующей повторной проверки.
var provider: DEF_ItemAccessProvider = null


## Возвращает true только для результата ALLOWED; владение заново не проверяет.
func is_allowed() -> bool:
	return outcome == Outcome.ALLOWED
