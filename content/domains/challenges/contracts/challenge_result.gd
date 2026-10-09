extends RefCounted
## Общие типы итога и стабильные ключи результата для представления.
class_name ChallengeResult

enum Type { NONE, SUCCESS, FAILURE, CANCELLED }


## Возвращает стабильный ключ итога; NONE соответствует пустому ключу.
static func key(result: Type) -> StringName:
	match result:
		Type.SUCCESS: return &"success"
		Type.FAILURE: return &"failure"
		Type.CANCELLED: return &"cancelled"
	return &""
