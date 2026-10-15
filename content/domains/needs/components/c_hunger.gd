extends Component
## S_Hunger растит value/active time; HungerService меняет value явной food/debug операцией.
## Пороги и множители читаются из immutable политики, не копируются в отдельную authority.
class_name C_Hunger

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["value"]

enum Tier {
	NORMAL,
	HUNGRY,
	STARVING,
}

## Авторская политика порогов и эффектов; null отключает рост/усиление.
@export var policy: DEF_HungerPolicy = null
## Текущий накопленный голод, 0–maximum; еда уменьшает значение.
@export var value: float = 0.0
## S_Hunger суммирует gameplay seconds участия, в том числе при достигнутом maximum/нулевом росте.
## Ночь/пауза/недоступность не учитываются; transient diagnostics, не сохраняется.
var active_seconds: float = 0.0
