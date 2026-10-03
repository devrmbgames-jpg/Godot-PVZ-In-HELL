extends GameDefinition
## District population, replacement and perception tuning.
class_name DEF_District
## Seconds between hazard route evaluations.
@export_range(0.1, 5.0) var route_interval: float = 0.6
## Bounded wait before abandoning an unreachable activity.
@export_range(1.0, 120.0) var route_timeout: float = 20.0
## Length-equivalent penalty for one expected lost HP.
@export_range(0.1, 20.0) var danger_penalty: float = 4.0
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
