extends Component
## Контракт чтения существующего ID; не хранит второй ключ и не создаёт идентичность.
class_name C_ActorIdentityReference

## Специфичность существующей ссылки для детерминированного выбора ключа.
enum Specificity { NONE, RUNTIME, DOMAIN, PRIMARY }

#region Identity projection
## Возвращает canonical actor key из поля владельца; пуст по умолчанию.
func actor_key() -> String:
	return ""


## Определяет приоритет actor key; NONE оставляет authored/runtime fallback.
func actor_key_priority() -> Specificity:
	return Specificity.NONE


## Возвращает диагностический ID из поля владельца; пуст по умолчанию.
func trace_key() -> String:
	return ""


## Определяет приоритет диагностического ID; NONE оставляет Entity.id fallback.
func trace_key_priority() -> Specificity:
	return Specificity.NONE
#endregion
