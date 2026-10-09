extends C_ActorIdentityReference
## Постоянный ключ runtime-сущности, независимый от Node paths и instance ID.
class_name C_PersistentIdentity

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["key"]

## Непустой устойчивый ключ экземпляра; не наследуется новым жителем.
@export var key: String = ""

#region Existing identity projection
## Читает actor key непосредственно из авторитетного поля этого Component.
func actor_key() -> String:
	return key


## Сохраняет приоритет существующего ключа при восстановлении actor links.
func actor_key_priority() -> Specificity:
	return Specificity.RUNTIME


## Читает диагностический ID непосредственно из авторитетного поля этого Component.
func trace_key() -> String:
	return key


## Сохраняет приоритет существующего domain ID перед runtime identity.
func trace_key_priority() -> Specificity:
	return Specificity.RUNTIME
#endregion
