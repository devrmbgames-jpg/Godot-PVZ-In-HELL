extends RefCounted
## Reads authored feeding policy and perceived eligibility; never selects or changes a target.
class_name NpcFeedingQueries


#region Immutable policy and common attack guards
static func rule_for(actor: Entity) -> DEF_NpcFeeding:
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	if identity == null:
		return null
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	for rule: DEF_NpcTrait in person.rules_for():
		if rule is DEF_NpcFeeding:
			return rule as DEF_NpcFeeding
	return null


## The ordinary attack boundary fails closed for a malformed authored feeding policy.
static func can_attack(actor: Entity, target: Entity) -> bool:
	var rule: DEF_NpcFeeding = rule_for(actor)
	if rule == null:
		return true
	var health: C_Health = target.get_component(C_Health) as C_Health
	return (
		rule.valid_configuration() and health != null and not health.depleted
		and is_finite(health.current) and is_finite(health.value) and health.value > 0.0
		and health.current > health.value * rule.minimum_health_fraction
	)


## Captured by a concrete melee request or projectile before ordinary Health resolution.
static func minimum_health_fraction(actor: Entity) -> float:
	var rule: DEF_NpcFeeding = rule_for(actor)
	return rule.minimum_health_fraction if rule != null and rule.valid_configuration() else 0.0
#endregion
