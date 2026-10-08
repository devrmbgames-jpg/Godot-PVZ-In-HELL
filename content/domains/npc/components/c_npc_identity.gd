extends C_ActorIdentityReference
## Связь тела с постоянной личностью; не управляет целями боя и посылками.
class_name C_NpcIdentity

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["npc_id"]

## Постоянный ID личности района.
@export var npc_id: StringName = &""

#region Existing identity projection
## Читает диагностический ID непосредственно из авторитетного поля этого Component.
func trace_key() -> String:
	return String(npc_id)


## Сохраняет приоритет существующего domain ID перед runtime identity.
func trace_key_priority() -> Specificity:
	return Specificity.DOMAIN
#endregion
