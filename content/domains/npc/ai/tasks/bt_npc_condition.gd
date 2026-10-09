@tool
extends BTCondition
## Общий доступ условий к постоянной личности; условия не меняют игровой мир.

var _actor: E_DistrictNpc
var _person: NpcRecord
var _awareness: C_NpcAwareness

#region Контекст условия
func _setup() -> void:
	_actor = get_agent() as E_DistrictNpc
	if not is_instance_valid(_actor):
		return
	var identity: C_NpcIdentity = _actor.get_component(C_NpcIdentity) as C_NpcIdentity
	_person = NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null
	_awareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness

func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent
#endregion
