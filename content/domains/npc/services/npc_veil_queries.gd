extends RefCounted
## Reads selected immutable escape capability and current committed concealment.
class_name NpcVeilQueries


#region Read-only capability
static func rule_for(person: NpcRecord) -> DEF_NpcVeil:
	if person == null:
		return null
	for rule: DEF_NpcTrait in person.rules_for():
		if rule is DEF_NpcVeil:
			return rule as DEF_NpcVeil
	return null


## Optional on ordinary actors; cloud appearance is still physically visible.
static func concealed(actor: Entity) -> bool:
	if not is_instance_valid(actor):
		return false
	var veil: C_NpcVeil = actor.get_component(C_NpcVeil) as C_NpcVeil
	return veil != null and veil.form == C_NpcVeil.Form.INVISIBLE
#endregion
