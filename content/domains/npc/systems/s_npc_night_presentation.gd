extends System
## Projects appearance and committed combat facts onto authored night audio/shadow views.
class_name S_NpcNightPresentation

const MUSIC_CUE: String = "npc/night/music"
const SHADOW_CUE: String = "npc/night/shadows"


#region Scheduling
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_NpcTraits, S_NpcDecision] }


## Includes dormant/dead retained bodies so their optional view cannot keep old native work.
func query() -> QueryBuilder:
	return q.with_all([C_NpcIdentity, C_NpcAwareness])


## Reads gameplay authority and submits presentation transitions without gameplay mutation.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var view: NpcNightPresentation = (
			entity.get_node_or_null("NightPresence") as NpcNightPresentation
		)
		if view == null:
			continue
		if not entity.enabled or entity.has_component(C_Death):
			view.suspend()
			continue
		var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
		var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
		if person == null:
			view.suspend()
			continue
		var cues: PackedStringArray = person.profile.presentation_cues
		var hunting: bool = (
			CombatQueries.target_for(entity) != null
			and not NpcDarknessQueries.combat_suppressed(entity)
		)
		view.synchronize(cues.has(MUSIC_CUE), cues.has(SHADOW_CUE), hunting)
#endregion
