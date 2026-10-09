extends Observer
## Проверяет параметры взрыва и размер вспышки без повторного эффекта при restore.
class_name O_ExplosionSetup


## Наблюдает созданные/восстановленные автономные взрывы.
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_Explosion, C_HazardLifetime]).on_event(HazardSpawnResult.EVENT)


## Ставит настройку в CommandBuffer, сохраняя признак восстановления.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: HazardSpawnResult = payload as HazardSpawnResult
	var captured_hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var captured_explosion: C_Explosion = entity.get_component(C_Explosion) as C_Explosion
	var captured_lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
	cmd.add_custom(_configure.bind(weakref(entity), result != null and result.restored, captured_hazard, captured_explosion, captured_lifetime))


func _configure(
	entity_reference: WeakRef, restored: bool, captured_hazard: C_Hazard, captured_explosion: C_Explosion,
	captured_lifetime: C_HazardLifetime,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) \
			or entity.get_component(C_Hazard) != captured_hazard \
			or entity.get_component(C_Explosion) != captured_explosion \
			or entity.get_component(C_HazardLifetime) != captured_lifetime:
		return


	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var profile: DEF_Explosion = hazard.definition as DEF_Explosion
	var effect: E_Explosion = entity as E_Explosion
	if profile == null or effect == null:
		push_error("Explosion requires DEF_Explosion and E_Explosion prefab")
		HazardLifecycle.retire(entity, _world)
		return

	if not HazardProfileRules.valid(profile):
		push_error("Explosion tuning must be finite, with positive radius/falloff/target limit")
		HazardLifecycle.retire(entity, _world)
		return

	var lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
	if not restored:
		lifetime.awaiting_resolution = true

	HazardGeometry.configure_explosion(effect, profile)
