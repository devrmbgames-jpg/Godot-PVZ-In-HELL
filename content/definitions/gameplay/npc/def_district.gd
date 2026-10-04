extends GameDefinition
## District population, replacement and perception tuning.
class_name DEF_District
## Exposure outside authored light zones; independent of visual ambient rendering.
@export_range(0.0, 1.0) var ambient_light: float = 0.05
## Radius around the resting player in which an immediate danger prevents sleep.
@export_range(0.1, 8.0) var sleep_danger_radius: float = 1.5
## Conversation remains open only within this distance.
@export_range(1.0, 10.0) var conversation_range: float = 4.0
## Physical pickup arrival tolerance.
@export_range(0.2, 2.0) var loot_distance: float = 0.8
## Appetite permitting ordinary food consumption.
@export_range(0.0, 100.0) var npc_food_threshold: float = 30.0
## Hunger that can justify an otherwise affordable ambient attack.
@export_range(0.0, 100.0) var npc_attack_hunger: float = 80.0
## Initial appetite; growth follows the existing Hunger policy while on map.
@export_range(0.0, 100.0) var npc_start_hunger: float = 20.0
## Authored compatible replacement names; stable sequence disambiguates reuse.
@export var replacement_names: PackedStringArray = ["Счетовод", "Грач", "Моль", "Сажа", "Свечник", "Тихоня", "Нитка", "Дымник"]
## Seconds between hazard route evaluations.
@export_range(0.1, 5.0) var route_interval: float = 0.6
## Maximum synchronous route plans allowed in one physics frame.
@export_range(1, 16) var route_plans_per_frame: int = 1
## Bounded wait before abandoning an unreachable activity.
@export_range(1.0, 120.0) var route_timeout: float = 20.0
## Actual horizontal movement needed to renew the route progress watchdog.
@export_range(0.05, 1.0) var route_progress_distance: float = 0.15
## Extra clearance for local paths around moving damaging volumes.
@export_range(0.1, 3.0) var local_detour_margin: float = 0.5
## Ordered passage IDs followed by light-sensitive NPCs in either direction.
@export var shade_route: PackedStringArray = []
## Authored retreat point for light aversion; no runtime search for darker places.
@export var shade_refuge: StringName = &""
## Waypoint arrival tolerance independent of final service arrival.
@export_range(0.1, 1.0) var waypoint_distance: float = 0.5

## Authored initial people and replacement pool.
@export var profiles: Array[DEF_NpcProfile] = []
## Stable homes, portals, activities and route junctions.
@export var places: Array[DEF_DistrictPlace] = []
## Target number of local people.
@export_range(1, 64) var resident_count: int = 8
## Target number of recurring outside people.
@export_range(0, 64) var visitor_count: int = 4
## Vacancies required to begin local resettlement.
@export_range(1, 64) var replacement_threshold: int = 2
## Morning transitions before a replacement may arrive.
@export_range(1, 30) var replacement_delay_days: int = 2
## AI and sensory update interval.
@export_range(0.05, 1.0) var decision_interval: float = 0.2
## Self-initiated NPC conflicts permitted per phase.
@export_range(0, 10) var ambient_conflicts_per_phase: int = 1
## Limits the number of initiating local profiles during authored replacement.
@export_range(0, 8) var maximum_conflict_initiators: int = 2
## Idle delay before choosing another simple activity.
@export_range(1.0, 300.0) var activity_seconds: float = 30.0
## Maximum accepted home deliveries per evening.
@export_range(0, 8) var maximum_home_deliveries: int = 2
## Maximum damage amount safe for normal route planning as an HP fraction.
@export_range(0.0, 1.0) var ordinary_route_risk: float = 0.05

## Sound attenuation through one or more physical blockers.
@export_range(0.0, 1.0) var hearing_wall_attenuation: float = 0.25
## Footstep stimulus emission interval.
@export_range(0.1, 2.0) var footstep_interval: float = 0.6
## Walking sound radius.
@export_range(0.1, 30.0) var walking_noise_radius: float = 6.0
## Running sound radius.
@export_range(0.1, 40.0) var running_noise_radius: float = 12.0
## Physical doors and pickup interactions emit a location within this radius.
@export_range(0.1, 30.0) var interaction_noise_radius: float = 4.0
## An attempted weapon strike remains audible even when it misses.
@export_range(0.1, 40.0) var strike_noise_radius: float = 10.0
## Actual damage produces an impact or pain stimulus.
@export_range(0.1, 40.0) var damage_noise_radius: float = 14.0
## Crouched movement sound multiplier.
@export_range(0.0, 1.0) var crouching_noise_fraction: float = 0.3

#region Place queries
## Looks up a stable authored place ID.
func place_for(place_key: StringName) -> DEF_DistrictPlace:
	for place: DEF_DistrictPlace in places:
		if place != null and place.key == place_key:
			return place
	return null
#endregion
