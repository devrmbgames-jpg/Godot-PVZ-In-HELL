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
