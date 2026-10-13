extends "res://tests/smoke/district_smoke.gd"
## Read-only diagnostic for the unchanged passive-resident week acceptance threshold.

var _trace_installed: bool = false


class SurvivalTrace extends Observer:
	var _sampled: Dictionary[StringName, bool] = { }


	func query() -> QueryBuilder:
		return q.with_all([C_NpcIdentity]).on_event(DamageResult.EVENT)


	func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
		var result: DamageResult = payload as DamageResult
		var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
		var health: C_Health = entity.get_component(C_Health) as C_Health
		var stage: String = "critical" if health.current <= 12.0 else "half"
		var sample: StringName = StringName(
			"%s/%d/%s" % [identity.npc_id, DayPhaseQueries.current().day_index, stage]
		)
		if (
			result.outcome == DamageResult.Outcome.APPLIED
			and health.current <= health.value * 0.5 and not _sampled.has(sample)
		):
			_sampled[sample] = true
			var actor: E_DistrictNpc = entity as E_DistrictNpc
			var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
			var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
			var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
			var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
			print(
				"Survival probe ",
				stage,
				"-health npc=",
				identity.npc_id,
				" source=", _actor_key(result.request.source),
				" amount=", result.applied_amount,
				" velocity=",
				actor.linear_velocity,
				" source_position=",
				_position_of(result.request.source),
				" instigator_position=",
				_position_of(result.request.instigator),
				" hp=",
				health.current,
				" position=",
				actor.global_position,
				" behavior=",
				decision.active_behavior,
				" distress=",
				awareness.hazard_distress,
				" fleeing=", awareness.fleeing,
				" combat_target=", _actor_key(CombatQueries.target_for(actor)),
				" moving=",
				intent.movement_active,
				" goal=",
				intent.move_position,
				" reachable=",
				route.reachable,
				" pending=",
				route.pending,
				" points=",
				route.points,
				" stalled=",
				route.stalled_seconds,
				" blocked=",
				route.blocked_seconds,
				" day=",
				DayPhaseQueries.current().day_index,
			)
			if stage == "critical":
				_trace_navigation(actor, intent, route, result.request.source)
		if result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
			return
		print(
			"Survival probe death npc=",
			identity.npc_id,
			" type=",
			result.request.damage_type,
			" amount=",
			result.applied_amount,
			" source=",
			_actor_key(result.request.source),
			" instigator=",
			_actor_key(result.request.instigator),
			" day=",
			DayPhaseQueries.current().day_index,
		)


	func _position_of(candidate: Variant) -> Vector3:
		return (
			(candidate as Node3D).global_position
			if (is_instance_valid(candidate) and candidate is Node3D)
			else Vector3.INF
		)


	func _trace_navigation(
		actor: E_DistrictNpc,
		intent: C_NpcIntent,
		route: C_NpcRoute,
		source: Entity,
	) -> void:
		var agent: NavigationAgent3D = actor.navigation_agent
		print(
			"Survival probe navigation npc=", actor.id,
			" route_goal=", route.goal,
			" refuge_cursor=", route.refuge_direction_offset,
			" rejected_refuges=", route.rejected_refuge_points,
			" cursor=", route.point_index,
			" intent_arrived=", intent.arrived,
			" intent_blocked=", intent.navigation_blocked,
			" agent_target=", agent.target_position,
			" agent_path=", agent.get_current_navigation_path(),
			" agent_cursor=", agent.get_current_navigation_path_index(),
			" arrival=", intent.arrival_distance,
			" agent_arrival=", agent.target_desired_distance,
		)
		if not is_instance_valid(source) or not source.has_component(C_Hazard):
			return
		var state: C_Hazard = source.get_component(C_Hazard) as C_Hazard
		var definition: DEF_ToxicArea = state.definition as DEF_ToxicArea
		if definition == null:
			return
		print(
			"Survival probe hazard key=", definition.key,
			" tick_damage=", definition.damage_per_tick, " tick_seconds=", definition.tick_seconds,
		)
		var center: Vector3 = (source as Node as Node3D).global_position
		center.y = actor.global_position.y
		var outward: Vector3 = actor.global_position - center
		outward.y = 0.0
		if outward.is_zero_approx():
			outward = Vector3.RIGHT
		var radius: float = definition.radius + agent.radius
		var margin: float = NpcPopulationQueries.current().definition.local_detour_margin
		var map: RID = agent.get_navigation_map()
		for index: int in 8:
			var candidate: Vector3 = center + outward.normalized().rotated(
				Vector3.UP, TAU * float(index) / 8.0,
			) * (radius + margin)
			var projected: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
			var offset: Vector3 = projected - center
			offset.y = 0.0
			var path: PackedVector3Array = NavigationServer3D.map_get_path(
				map, actor.global_position, projected, true,
			)
			print(
				"Survival probe candidate npc=", actor.id, " index=", index,
				" projected=", projected, " clearance=", offset.length() - radius,
				" points=", path.size(),
				" endpoint=", path[path.size() - 1] if not path.is_empty() else Vector3.INF,
				" endpoint_gap=", path[path.size() - 1].distance_to(projected)
					if not path.is_empty() else INF,
			)


	func _actor_key(candidate: Variant) -> String:
		if not is_instance_valid(candidate) or not candidate is Entity:
			return "unavailable"
		var actor: Entity = candidate as Entity
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		if identity != null:
			return String(identity.npc_id)
		var hazard: C_Hazard = actor.get_component(C_Hazard) as C_Hazard
		if hazard != null:
			return String(hazard.definition.key)
		return actor.scene_file_path


#region Read-only diagnostic installation and terminal facts
func _process(_delta: float) -> void:
	if not _trace_installed and is_instance_valid(ECS.world):
		ECS.world.add_observer(SurvivalTrace.new())
		_trace_installed = true


func _check(condition: bool, label: String) -> void:
	if label.begins_with("passive original residents"):
		for person: NpcRecord in NpcPopulationQueries.current().people:
			print(
				"Survival probe person=",
				person.npc_id,
				" profile=",
				person.profile.key,
				" death_day=",
				person.death_day,
				" placement=",
				person.placement,
			)
	super._check(condition, label)
#endregion
