extends Observer
## Проверяет авторские настройки объёмной опасности и создаёт её форму и представление.
class_name O_ToxicAreaSetup


## Наблюдает созданные/восстановленные токсичные опасности.
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_ToxicArea]).on_event(HazardSpawnResult.EVENT)


## Ставит проверку и настройку объёма в CommandBuffer.
func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var captured_hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var captured_toxin: C_ToxicArea = entity.get_component(C_ToxicArea) as C_ToxicArea
	cmd.add_custom(_configure.bind(weakref(entity), captured_hazard, captured_toxin))


func _configure(entity_reference: WeakRef, captured_hazard: C_Hazard, captured_toxin: C_ToxicArea) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) \
			or entity.get_component(C_Hazard) != captured_hazard \
			or entity.get_component(C_ToxicArea) != captured_toxin:
		return


	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var profile: DEF_ToxicArea = hazard.definition as DEF_ToxicArea
	var effect: E_ToxicArea = entity as E_ToxicArea
	if profile == null or effect == null:
		push_error("ToxicArea requires DEF_ToxicArea and E_ToxicArea prefab")
		HazardLifecycle.retire(entity, _world)
		return

	if not HazardProfileRules.valid(profile):
		push_error(
			"ToxicArea tuning must contain finite positive radius/tick and nonnegative damage"
		)
		HazardLifecycle.retire(entity, _world)
		return

	HazardGeometry.configure_toxic(effect, profile)
