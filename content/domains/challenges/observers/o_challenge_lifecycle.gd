extends Observer
## Отменяет активное испытание при недоступности участника или потере живой связи.
class_name O_ChallengeLifecycle


## Подписывает отмену на удаление/отключение участника World.
func setup() -> void:
	_world.entity_removed.connect(ChallengeService.entity_unavailable)
	_world.entity_disabled.connect(ChallengeService.entity_unavailable)


## Наблюдает снятие живой связи участника или эффекта.
func query() -> QueryBuilder:
	return q.on_relationship_removed([R_ChallengeActor, R_ChallengeEffect])


## Отменяет ARMED/ACTIVE-сеанс после потери связи.
func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var state: C_Challenge = entity.get_component(C_Challenge) as C_Challenge
	if state != null and state.phase in [C_Challenge.Phase.ARMED, C_Challenge.Phase.ACTIVE]:
		ChallengeService.cancel(entity)
