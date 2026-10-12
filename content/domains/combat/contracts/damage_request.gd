extends RefCounted
## Запрос урона/лечения; повреждающий источник отделён от вызвавшего действие участника.
class_name DamageRequest

const EVENT := &"damage_requested"

enum Operation {
	DAMAGE,
	HEAL,
	# Explicit voluntary maximum-Health transaction; ignores attack resistance/source veto.
	SACRIFICE,
}
enum Type {
	GENERIC,
	MELEE,
	IMPACT,
	EXPLOSION,
	TOXIC,
	LIQUID,
	PROJECTILE,
	FIRE,
	# Append semantic types; preserve serialized GENERIC..FIRE values 0..7.
	ACID,
	HOLY,
	UNHOLY,
}

## Участник, вызвавший действие; не обязательно совпадает с повреждающим телом.
var instigator: Entity = null
## Настоящий повреждающий источник; null допустим для окружения.
var source: Entity = null
## Конкретный получатель с Health; null не становится широковещательным запросом.
var target: Entity = null
## Положительная конечная сумма в единицах здоровья до сопротивления.
var amount: float = 0.0
## Урон или лечение; лечение не использует сопротивление урону.
var operation: Operation = Operation.DAMAGE
## Permanent maximum-Health delta for SACRIFICE only; ordinary damage/healing requires zero.
var maximum_health_delta: float = 0.0
## Тип урона для сопротивления и представления.
var damage_type: Type = Type.GENERIC

## Постоянный ID происхождения эффекта независимо от живой ссылки источника.
var origin_id: String = ""
## Постоянный ID инициатора независимо от живой ссылки.
var instigator_id: String = ""
## Снимок боевого контекста и атрибуции для реакций после расчёта.
var combat_context: CombatContext = null
## Устойчивый личный инцидент, назначаемый при восприятии фактического насилия.
var incident_id: StringName = &""
## Transient request/result correlation; not a damage idempotency or incident key.
var correlation_id: StringName = &""
## Target identity snapshot for results after a queued target expires.
var target_id: String = ""
