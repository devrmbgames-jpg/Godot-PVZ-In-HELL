extends "res://tests/smoke/npc_life_cycle_smoke.gd"
## Тот же actual damage/restart цикл для одного returning Lost без районного дома.

const GUEST_PILOT_PATH: String = (
	"res://content/domains/npc/definitions/def_district_lost_life_prototype.tres"
)
const GUEST_SAVE_PATH: String = "user://npc_guest_life_smoke.pvzh"


#region Returning guest fixture
func _pilot_path() -> String:
	return GUEST_PILOT_PATH


func _save_path() -> String:
	return GUEST_SAVE_PATH


func _person_id() -> StringName:
	return &"npc/20"


func _completion_prefix() -> String:
	return "NPC guest life smoke"


func _restore() -> void:
	super._restore()
	var person: NpcRecord = NpcPopulationQueries.person_for(_person_id())
	_check(person.home_id.is_empty() and not person.profile.resident, "returning guest has no home")
#endregion
