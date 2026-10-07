extends Observer
## Проверяет созданную плоскость и связывает её с ещё действующим испытанием.
class_name O_FloorChallengeSpawn


## Наблюдает созданные плоские эффекты.
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_FloorHazard]).on_event(HazardSpawnResult.EVENT)


## Ставит проверку и связь с ещё действующим испытанием в CommandBuffer.
func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	cmd.add_custom(_bind.bind(entity))


func _bind(entity: Entity) -> void:
	if not EntityAvailability.contains(entity, _world):
		return

	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var profile: DEF_FloorHazard = hazard.definition as DEF_FloorHazard
	var effect: E_FloorHazard = entity as E_FloorHazard
	var subject: Entity = hazard.origin
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge if EntityAvailability.contains(subject, _world) else null
	var floor: C_FloorChallenge = subject.get_component(C_FloorChallenge) as C_FloorChallenge if state != null else null
	if floor == null or not floor.spawn_requested or floor.spawn_request_id != hazard.request_id or profile == null or effect == null or state == null or state.phase != C_Challenge.Phase.ACTIVE or state.definition == null or not state.definition.condition is DEF_FloorChallengeCondition:
		HazardLifecycle.retire(entity, _world)
		return
	if not profile.size.is_finite() or profile.size.x <= 0.0 or profile.size.y <= 0.0 or not is_finite(profile.tick_seconds) or profile.tick_seconds <= 0.0 or not is_finite(profile.damage_per_tick) or profile.damage_per_tick < 0.0 or not is_finite(profile.contact_tolerance) or profile.contact_tolerance < 0.0:
		ChallengeService.cancel(subject)
		HazardLifecycle.retire(entity, _world)
		return

	effect.configure(profile)
	subject.add_relationship(Relationship.new(R_ChallengeEffect.new(), entity))
