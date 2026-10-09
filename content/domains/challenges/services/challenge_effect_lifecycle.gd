extends RefCounted
## Читает и освобождает владение автономными эффектами через R_ChallengeEffect.
class_name ChallengeEffectLifecycle


## Снимает связи эффектов носителя и удаляет ещё доступные автономные опасности.
static func retire(subject: Entity) -> void:
	if not is_instance_valid(subject):
		return

	for relation: Relationship in subject.relationships.duplicate():
		if relation.relation is R_ChallengeEffect:
			var effect: Entity = relation.target as Entity if EntityAvailability.contains(relation.target, ECS.world) else null
			subject.remove_relationship(relation)
			if effect != null:
				HazardLifecycle.retire(effect, ECS.world)


## Находит носителя через входящую R_ChallengeEffect без параллельного кеша.
static func owner_for(effect: Entity) -> Entity:
	if not EntityAvailability.contains(effect, ECS.world):
		return null

	for subject: Entity in ECS.world.query.with_all([C_Challenge]).execute():
		for relation: Relationship in subject.relationships:
			if relation.relation is R_ChallengeEffect and relation.target == effect:
				return subject
	return null
