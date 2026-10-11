extends RefCounted
## Read-only observation capability queries; no sensing, clocks or body mutations.
class_name NpcGazeQueries


#region Selected capability and sampled constraint
## Resolves the selected typed capability without inspecting an archetype ID or rerolling traits.
static func selected_rule(traits: Array[DEF_NpcTrait]) -> DEF_NpcGazeFreeze:
	for rule: DEF_NpcTrait in traits:
		if rule is DEF_NpcGazeFreeze:
			return rule as DEF_NpcGazeFreeze
	return null


## Combat and native body boundaries read the same observed fact, including between BT ticks.
static func frozen(actor: Entity) -> bool:
	var constraint: C_NpcGazeFreeze = actor.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
	return (
		constraint != null and constraint.rule != null
		and constraint.observed and not actor.has_component(C_Death)
	)
#endregion
