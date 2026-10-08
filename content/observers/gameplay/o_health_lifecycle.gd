extends Observer
## Создаёт смерть только живого участника и освобождает управление, бой и хват.
class_name O_HealthLifecycle


#region Подписка на истощение
## Подписывается на результаты только живых участников.
func query() -> QueryBuilder:
	return q.with_all([C_Living]).on_event(DamageResult.EVENT)


## Ставит однократную смерть в CommandBuffer после результата истощения.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result != null and result.outcome == DamageResult.Outcome.HEALTH_DEPLETED:
		var captured_living: C_Living = entity.get_component(C_Living) as C_Living
		cmd.add_custom(_commit_death.bind(weakref(entity), result, captured_living))


#endregion

#region Смерть и освобождение управления
func _commit_death(target_reference: WeakRef, result: DamageResult, captured_living: C_Living) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var target: Entity = target_reference.get_ref() as Entity

	if not EntityAvailability.contains(target, _world) \
			or target.get_component(C_Living) != captured_living:
		return

	if not GrabService.entity_available(target) or target.has_component(C_Death):
		return

	var death: C_Death = C_Death.new()
	death.cause = result
	target.add_component(death)

	GrabService.entity_unavailable(target)
	CombatService.entity_unavailable(target)
	ChallengeService.entity_unavailable(target)
	var cart: Entity = CartTransportService.current(target)
	if cart != null:
		CartTransportService.end(cart)
	var motion: C_Motion = target.get_component(C_Motion) as C_Motion
	if motion != null:
		motion.control_enabled = false

	var interactor: C_Interactor = target.get_component(C_Interactor) as C_Interactor
	if interactor != null:
		# Контур наведения сам очистит цель и подсветку на следующем такте недоступного участника.
		interactor.prompt_text = ""

#endregion
