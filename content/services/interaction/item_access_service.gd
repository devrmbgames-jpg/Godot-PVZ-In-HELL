extends RefCounted
## Shared predicate and provider boundary for locks and other contextual actions.
class_name ItemAccessService


static func matches(identity: C_AccessItem, requirement: DEF_AccessRequirement) -> bool:
	if identity == null or requirement == null:
		return false
	if requirement.required_item_id != &"" and identity.item_id != requirement.required_item_id:
		return false
	for tag: StringName in requirement.required_tags:
		if tag == &"" or not identity.tags.has(tag):
			return false
	return true


static func evaluate(actor: Entity, requirement: DEF_AccessRequirement) -> AccessResult:
	var result: AccessResult = AccessResult.new()
	if not GrabService.holder_available(actor):
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
	var providers: Array[DEF_ItemAccessProvider] = [DEF_HeldItemAccess.new()]
	if config != null and not config.providers.is_empty():
		providers = config.providers
	for provider: DEF_ItemAccessProvider in providers:
		if provider == null:
			continue
		for item: Entity in provider.items(actor):
			if not GrabService.entity_available(item):
				continue
			var identity: C_AccessItem = item.get_component(C_AccessItem) as C_AccessItem
			if not matches(identity, requirement):
				continue
			if requirement.consume_item and not provider.can_consume(actor, item):
				result.outcome = AccessResult.Outcome.CONSUMPTION_UNAVAILABLE
				continue
			result.outcome = AccessResult.Outcome.ALLOWED
			result.item = item
			result.provider = provider
			return result
	return result


## Re-evaluates at the command boundary; callers must not reuse a prior query grant.
static func fulfill(actor: Entity, requirement: DEF_AccessRequirement) -> bool:
	var result: AccessResult = evaluate(actor, requirement)
	if not result.is_allowed():
		return false
	if requirement == null or not requirement.consume_item:
		return true
	return result.provider != null and result.provider.consume(actor, result.item)
