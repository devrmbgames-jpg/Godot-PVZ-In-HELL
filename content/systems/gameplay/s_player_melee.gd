extends System
## Owns player strike clocks, active-window scan and terminal cancellation.
class_name S_PlayerMelee

#region Scheduling
## Declares combat ordering relative to input, decisions, challenges and physical intent.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_Grab]}


## Selects registered live state for this authoritative scheduled owner.
func query() -> QueryBuilder:
	return q.with_all([C_Combat]).with_none([C_Death]).enabled()


## Captures state identity and execution generation at the command-buffer boundary.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for actor: Entity in entities:
		var captured: C_Combat = actor.get_component(C_Combat) as C_Combat
		cmd.add_custom(_advance.bind(actor, captured, captured.execution_generation, delta))
#endregion

#region Authoritative progression
func _advance(actor: Entity, captured: C_Combat, generation: int, delta: float) -> void:
	if not EntityAvailability.contains(actor, _world) or actor.get_component(C_Combat) != captured:
		return
	if captured.execution_generation != generation:
		return
	_step(actor, delta)


func _step(actor: Entity, delta: float) -> void:
	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	if state == null or state.phase == C_Combat.Phase.READY:
		return

	var weapon: Entity = CombatService.weapon_for(actor)
	var grip: Relationship = GrabService.held_relationship(weapon)
	if not GrabService.holder_available(actor) or grip == null or grip.target != actor or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PROLONGED:
		CombatService.cancel_strike(actor)
		return

	var generation: int = state.execution_generation
	var previous: float = state.elapsed
	state.elapsed += maxf(0.0, delta)
	var attack: DEF_MeleeAttack = state.strike
	MeleeWeaponPresentation.update(weapon, state.elapsed, attack)
	var active_end: float = attack.windup_seconds + attack.active_seconds
	if state.elapsed >= attack.windup_seconds and previous < active_end and not state.hit_committed:
		_scan_strike(actor, weapon, state)
	if not EntityAvailability.contains(actor, _world) or actor.get_component(C_Combat) != state \
			or state.execution_generation != generation:
		return
	if state.elapsed >= active_end + attack.recovery_seconds:
		CombatService.cancel_strike(actor)
	elif state.elapsed >= active_end:
		state.phase = C_Combat.Phase.RECOVERY
	elif state.elapsed >= attack.windup_seconds:
		state.phase = C_Combat.Phase.ACTIVE


func _scan_strike(actor: Entity, weapon: Entity, state: C_Combat) -> void:
	var node: Node3D = actor as Node as Node3D
	if node == null or not node.is_inside_tree():
		return

	var attack: DEF_MeleeAttack = state.strike
	var closest: Entity = null
	var distance: float = INF
	# Близкие статические плитки могут заполнить ограниченный overlap-запрос;
	# поэтому кандидаты удара берутся среди владельцев Health и проверяются лучом.
	for target: Entity in ECS.world.query.with_all([C_Health]).execute():
		if target == actor or not (target as Node) is PhysicsBody3D or not GrabService.holder_available(target):
			continue
		if not CombatGeometry.in_cone(actor, target, attack.reach, attack.half_angle_degrees) or not CombatGeometry.clear_line(actor, target, attack.collision_mask):
			continue

		var candidate: float = CombatGeometry.origin(actor).distance_squared_to(CombatGeometry.aim_point(target))
		if candidate < distance:
			closest = target
			distance = candidate
	if closest != null:
		var generation: int = state.execution_generation
		var accepted: bool = CombatService.hit(actor, weapon, closest, attack.damage)
		# Damage publication can cancel or replace the strike before its receipt returns.
		if EntityAvailability.contains(actor, _world) and actor.get_component(C_Combat) == state \
				and state.execution_generation == generation:
			state.hit_committed = accepted
#endregion
