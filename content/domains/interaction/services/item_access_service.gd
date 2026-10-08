extends RefCounted
## Проверяет требования предметов и адаптеры доступа для замков и контекстных действий.
class_name ItemAccessService


#region Требование и доступный предмет
## Выбирает доступный предмет и адаптер; null-требование допускается без расходования.
static func evaluate(actor: Entity, requirement: DEF_AccessRequirement) -> AccessResult:
	var result: AccessResult = AccessResult.new()
	if not GrabQueries.holder_available(actor):
		result.outcome = AccessResult.Outcome.ACTOR_UNAVAILABLE
		return result
	if requirement == null:
		result.outcome = AccessResult.Outcome.ALLOWED
		return result
	if requirement.required_item_id == &"" and requirement.required_tags.is_empty():
		result.outcome = (
			AccessResult.Outcome.INVALID_REQUIREMENT if requirement.consume_item
			else AccessResult.Outcome.ALLOWED
		)
		return result

	var config: C_ItemAccess = actor.get_component(C_ItemAccess) as C_ItemAccess
	var providers: Array[DEF_ItemAccessProvider] = [DEF_HeldItemAccess.new(), DEF_WornItemAccess.new()]
	if config != null and not config.providers.is_empty():
		providers = config.providers
	for provider: DEF_ItemAccessProvider in providers:
		if provider == null:
			continue

		for item: Entity in provider.items(actor):
			if not GrabQueries.entity_available(item):
				continue

			var identity: C_AccessItem = item.get_component(C_AccessItem) as C_AccessItem
			if not ItemAccessRules.matches(identity, requirement):
				continue
			if requirement.consume_item and not provider.can_consume(actor, item):
				result.outcome = AccessResult.Outcome.CONSUMPTION_UNAVAILABLE
				continue

			result.outcome = AccessResult.Outcome.ALLOWED
			result.item = item
			result.provider = provider
			return result
	return result


## Повторно проверяет доступ на границе команды; прежний результат проверки не даёт разрешения.
static func fulfill(actor: Entity, requirement: DEF_AccessRequirement) -> bool:
	var result: AccessResult = evaluate(actor, requirement)
	if not result.is_allowed():
		return false
	if requirement == null or not requirement.consume_item:
		return true
	return result.provider != null and result.provider.consume(actor, result.item)

#endregion
