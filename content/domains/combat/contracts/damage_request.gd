extends RefCounted
## Caller-owned запрос урона/лечения/SACRIFICE; submit копирует поля в отдельный queued snapshot.
## Entity references не владеют lifetime; O_Damage повторно проверяет цель, результат несёт IDs.
class_name DamageRequest

const EVENT := &"damage_requested"

enum Operation {
	DAMAGE,
	HEAL,
	# Explicit voluntary HP/maximum-Health transaction; ignores attack resistance/source veto.
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
## Конечные HP до сопротивления: > 0 для DAMAGE/HEAL; SACRIFICE допускает 0.
var amount: float = 0.0
## Выбранная операция; HEAL и добровольный SACRIFICE не используют attack resistance/source veto.
var operation: Operation = Operation.DAMAGE
## SACRIFICE-only finite nonpositive maximum-HP delta; base and resulting limit must stay > 0.
## Ordinary DAMAGE/HEAL requires zero; HealthMutationService validates at resolution.
var maximum_health_delta: float = 0.0
## DAMAGE-only lower HP bound in [0, 1] of the resolution-time maximum; zero disables it.
## Already lower HP is never raised by this damage request.
var minimum_health_fraction: float = 0.0
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
