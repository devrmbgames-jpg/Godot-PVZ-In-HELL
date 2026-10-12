extends RefCounted
## Bounded safe firing positions for an observed combat target; never moves bodies or clocks.
class_name NpcRangedPositionSolver

const PROJECTION_TOLERANCE: float = 0.5
const POSITION_TOLERANCE: float = 0.25
const SIDE_ANGLE_DEGREES: float = 60.0


#region Authored ranged geometry
## Resolves the highest-priority usable authored ranged variant within the executor's bound.
static func variant(state: C_NpcCombat) -> int:
	var selected: int = -1
	for index: int in mini(state.ranged_attacks.size(), C_NpcCombat.MAX_VARIANTS):
		var attack: DEF_NpcAttack = state.ranged_attacks[index]
		if not NpcAttackService.valid_attack(attack, C_NpcCombat.Kind.RANGED) \
				or not is_finite(attack.selection_priority):
			continue
		if (
			selected < 0
			or attack.selection_priority > state.ranged_attacks[selected].selection_priority
		):
			selected = index
	return selected


## A margin inside the weapon's range avoids chasing during cooldown or crossing its minimum.
static func positioned(position: Vector3, observed: Vector3, attack: DEF_NpcAttack) -> bool:
	var margin: float = minf(
		PROJECTION_TOLERANCE,
		(attack.maximum_range - attack.minimum_range) / 4.0,
	)
	var distance: float = position.distance_to(observed)
	return distance >= attack.minimum_range + margin and distance <= attack.maximum_range - margin
#endregion


#region Native route preview
## Previews at most three navmesh positions with the shared hazard/health reserve contract.
## INF means no safe route exists; the ordinary combat branch may defend or continue searching.
static func destination(
	actor: E_DistrictNpc,
	person: NpcRecord,
	observed: Vector3,
	attack: DEF_NpcAttack,
) -> Vector3:
	var map: RID = actor.navigation_agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return Vector3.INF
	var outward: Vector3 = actor.global_position - observed
	outward.y = 0.0
	if outward.is_zero_approx():
		outward = Vector3.BACK
	var distance: float = (attack.minimum_range + attack.maximum_range) / 2.0
	var selected: Vector3 = Vector3.INF
	var nearest: float = INF
	for angle: float in [0.0, -SIDE_ANGLE_DEGREES, SIDE_ANGLE_DEGREES]:
		var proposed: Vector3 = observed + outward.normalized().rotated(
			Vector3.UP,
			deg_to_rad(angle),
		) * distance
		proposed.y = actor.global_position.y
		var candidate: Vector3 = NavigationServer3D.map_get_closest_point(map, proposed)
		if candidate.distance_to(proposed) > PROJECTION_TOLERANCE \
				or not positioned(candidate, observed, attack):
			continue
		var path: PackedVector3Array = NpcRouteSolver.plan(
			actor,
			person,
			actor.global_position,
			candidate,
			map,
		)
		if path.is_empty():
			continue
		var travel: float = actor.global_position.distance_squared_to(candidate)
		if travel < nearest:
			nearest = travel
			selected = candidate
	return selected
#endregion
