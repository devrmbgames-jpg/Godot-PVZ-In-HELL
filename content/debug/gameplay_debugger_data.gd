extends RefCounted
## Detached selected-Entity diagnostics; reads owners without scheduling or replaying gameplay.
class_name GameplayDebuggerData

const RECENT_EVENT_LIMIT: int = 24


#region Selection lifetime
## Exact entity handles include dormant actors; other handles use the existing QA syntax.
static func resolve(raw_target: String) -> Entity:
	var handle: String = raw_target.strip_edges()
	if not is_instance_valid(ECS.world):
		return null
	if handle.begins_with("entity:"):
		var entity_id: String = handle.trim_prefix("entity:")
		for actor: Entity in ECS.world.entities:
			if available(actor) and actor.id == entity_id:
				return actor
		return null
	var target: DebugTarget = DebugTargetResolver.resolve(handle)
	return target.entity if available(target.entity) else null


## Presentation may retain a weak selection across frames, including disabled registered bodies.
static func available(candidate: Variant) -> bool:
	if not is_instance_valid(candidate) or not candidate is Entity:
		return false
	var actor: Entity = candidate as Entity
	return (
		is_instance_valid(ECS.world) and actor.is_inside_tree()
		and not actor.is_queued_for_deletion() and ECS.world.entities.has(actor)
	)
#endregion


#region Detached data provider
## Returns scalar/container data only; unavailable delayed selections have an explicit status.
static func snapshot(candidate: Variant) -> Dictionary[String, Variant]:
	if not available(candidate):
		return { "status": "UNAVAILABLE" }
	var actor: Entity = candidate as Entity
	var identities: PackedStringArray = [actor.id]
	var components: PackedStringArray = []
	for component: Component in actor.components.values():
		components.append(_script_name(component.get_script() as Script))
	components.sort()
	var result: Dictionary[String, Variant] = {
		"status": "REGISTERED",
		"entity": { "id": actor.id, "node": String(actor.get_path()), "enabled": actor.enabled },
		"components": components,
		"relationships": _relationships(actor),
		"reservations": _reservations(actor),
		"limboai": _brain(actor),
	}
	if actor.has_component(C_Package):
		var package: C_Package = actor.get_component(C_Package) as C_Package
		identities.append(package.package_id)
	if actor.has_component(C_CustomerAgent):
		var customer: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
		identities.append(String(customer.visit_id))
	if actor is E_DistrictNpc and actor.has_component(C_NpcIdentity):
		var npc: E_DistrictNpc = actor as E_DistrictNpc
		var state: Dictionary[String, Variant] = NpcDecisionDiagnostics.actor_state(npc)
		identities.append(String(state["npc_id"]))
		result["decision"] = state
		result["intent"] = _intent(actor.get_component(C_NpcIntent) as C_NpcIntent)
		result["perception"] = _perception(actor.get_component(C_NpcAwareness) as C_NpcAwareness)
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
		result["obligation"] = {
			"goal": String(person.goal_id),
			"day": person.planned_day,
			"phase": person.planned_phase,
			"complete": person.phase_complete,
		}
		result["simulation_lod"] = {
			"mode": state["participation"],
			"reason": state["participation_reason"],
			"placement": NpcRecord.Placement.keys()[person.placement],
			"process_mode": npc.process_mode,
			"frozen": npc.freeze,
			"collision_layer": npc.collision_layer,
			"collision_mask": npc.collision_mask,
			"cadence_elapsed_ticks": person.cadence_elapsed_ticks,
		}
	result["recent_events"] = _events(identities)
	return result


static func _relationships(actor: Entity) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for binding: Relationship in actor.relationships:
		rows.append(
			{ "relation": _reference(binding.relation), "target": _reference(binding.target) }
		)
	return rows


static func _reservations(selected: Entity) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for actor: Entity in ECS.world.entities:
		for binding: Relationship in actor.relationships:
			if not binding.relation is R_SmartObjectReservation:
				continue
			if actor != selected and binding.target != selected:
				continue
			var reservation: R_SmartObjectReservation = binding.relation as R_SmartObjectReservation
			rows.append(
				{
					"owner": actor.id,
					"object": _reference(binding.target),
					"affordance": String(reservation.affordance_id),
					"slot": String(reservation.slot_id),
					"token": reservation.token,
					"executing": reservation.executing,
				}
			)
	return rows


static func _brain(actor: Entity) -> Dictionary[String, Variant]:
	var runner: BTPlayer = actor.get_node_or_null("Brain") as BTPlayer
	if runner == null:
		return { "status": "NOT_INSTALLED" }
	var instance: BTInstance = runner.get_bt_instance()
	var root_status: String = "NOT_INITIALIZED"
	if instance != null:
		match instance.get_root_task().get_status():
			BTTask.FRESH:
				root_status = "FRESH"
			BTTask.RUNNING:
				root_status = "RUNNING"
			BTTask.SUCCESS:
				root_status = "SUCCESS"
			BTTask.FAILURE:
				root_status = "FAILURE"
	return {
		"node": String(runner.get_path()),
		"active": runner.active,
		"status": root_status,
		"tree": runner.behavior_tree.resource_path if runner.behavior_tree != null else "",
		"instance_id": instance.get_instance_id() if instance != null else 0,
		"inspector": "Use the native LimboAI debugger for this Brain; no duplicate tree view.",
	}


static func _intent(intent: C_NpcIntent) -> Dictionary[String, Variant]:
	return {
		"movement_active": intent.movement_active,
		"move_position": intent.move_position,
		"move_uses_entity": intent.move_uses_entity,
		"arrived": intent.arrived,
		"distance": intent.distance_to_target,
		"speed_fraction": intent.speed_fraction,
		"look_mode": C_NpcIntent.LookMode.keys()[intent.look_mode],
		"look_position": intent.look_position,
		"look_uses_entity": intent.look_uses_entity,
		"navigation_enabled": intent.navigation_enabled,
		"navigation_pending": intent.navigation_pending,
		"navigation_blocked": intent.navigation_blocked,
	}


static func _perception(awareness: C_NpcAwareness) -> Dictionary[String, Variant]:
	return {
		"target_visible": awareness.target_visible,
		"player_visible": awareness.player_visible,
		"has_last_seen": awareness.has_last_seen,
		"last_seen_position": awareness.last_seen_position,
		"search_elapsed": awareness.search_elapsed,
		"heard_position": awareness.heard_position,
		"heard_remaining": awareness.heard_remaining,
		"investigate_noise": awareness.investigate_noise,
		"fleeing": awareness.fleeing,
		"flee_portal": String(awareness.flee_portal_id),
		"light_distress": awareness.light_distress,
		"hazard_distress": awareness.hazard_distress,
		"rule_exposure": awareness.rule_exposure.duplicate(),
		"warned_rules": awareness.warned_rules.duplicate(),
		"reacted_rules": awareness.reacted_rules.duplicate(),
	}


static func _events(identities: PackedStringArray) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in BoundaryTrace.snapshots():
		var origin: String = String(entry["origin_id"])
		var target: String = String(entry["target_id"])
		if (not origin.is_empty() and identities.has(origin)) \
				or (not target.is_empty() and identities.has(target)):
			rows.append(entry)
			if rows.size() > RECENT_EVENT_LIMIT:
				rows.pop_front()
	return rows
#endregion


#region Reference labels
static func _reference(value: Variant) -> String:
	if value is Object:
		if not is_instance_valid(value):
			return "RETIRED"
		if value is Entity:
			return "entity:" + (value as Entity).id
		if value is Script:
			return _script_name(value as Script)
		var object: Object = value as Object
		return _script_name(object.get_script() as Script) if object.get_script() != null \
				else object.get_class()
	return str(value)


static func _script_name(script: Script) -> String:
	var declared: StringName = script.get_global_name()
	return String(declared) if not declared.is_empty() else script.resource_path
#endregion
