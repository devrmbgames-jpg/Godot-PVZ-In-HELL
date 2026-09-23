extends Observer
## Applies living-only death state and minimal character control/grip cleanup.
class_name O_HealthLifecycle


func query() -> QueryBuilder:
	return q.with_all([C_Living]).on_event(DamageResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result != null and result.outcome == DamageResult.Outcome.HEALTH_DEPLETED:
		cmd.add_custom(_commit_death.bind(entity, result))


func _commit_death(target: Entity, result: DamageResult) -> void:
	if not S_Grab.entity_available(target) or target.has_component(C_Death):
		return
	var death: C_Death = C_Death.new()
	death.cause = result
	target.add_component(death)

	S_Grab.entity_unavailable(target)
	var cart: Entity = S_CartTransport.current(target)
	if cart != null:
		S_CartTransport.end(cart)
	var motion: C_Motion = target.get_component(C_Motion) as C_Motion
	if motion != null:
		motion.control_enabled = false
	var interactor: C_Interactor = target.get_component(C_Interactor) as C_Interactor
	if interactor != null:
		for system: System in ECS.world.systems:
			if system is S_InteractionTargeting:
				(system as S_InteractionTargeting).set_highlight(interactor.target, false)
		interactor.target = null
		interactor.prompt_text = ""
