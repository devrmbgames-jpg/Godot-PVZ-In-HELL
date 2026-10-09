extends System
## Перемещает только нефизические эффекты и применяет явную политику потери владельца.
class_name S_HazardFollow


#region Scheduled follow contribution
## Выбирает включённые эффекты с живой связью следования.
func query() -> QueryBuilder:
	return q.enabled().with_relationship([Relationship.new(R_HazardFollow.new(), null)])


## Копирует позу только нефизического эффекта; потеря владельца снимает связь либо удаляет эффект.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var relationship: Relationship = HazardFollowService.binding(entity)
		if relationship == null:
			continue

		var follow: R_HazardFollow = relationship.relation as R_HazardFollow
		var effect: Node3D = entity as Node as Node3D
		if not EntityAvailability.contains(relationship.target, _world):
			if follow.on_loss == DEF_Hazard.OwnerLoss.Despawn:
				cmd.add_custom(_retire_lost_binding.bind(weakref(entity), relationship))
			else:
				cmd.add_custom(_remove_captured_relationship.bind(weakref(entity), relationship))
			continue

		var origin: Node3D = relationship.target as Node3D
		if effect != null and origin != null and not effect is PhysicsBody3D:
			effect.global_transform = origin.global_transform * follow.local_offset

#endregion

#region Captured owner loss
func _retire_lost_binding(effect_reference: WeakRef, binding: Relationship) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var effect: Entity = effect_reference.get_ref() as Entity

	if not EntityAvailability.contains(effect, _world) or HazardFollowService.binding(effect) != binding:
		return
	if not EntityAvailability.contains(binding.target, _world):
		HazardLifecycle.retire(effect, _world)
#endregion


#region Captured relationship retirement
func _remove_captured_relationship(owner_reference: WeakRef, captured: Relationship) -> void:
	# GECS pattern removal could otherwise match a replacement after the original binding disappeared.
	var subject: Entity = owner_reference.get_ref() as Entity
	if subject == null or not _world.entity_to_archetype.has(subject) or subject.is_queued_for_deletion():
		return
	if subject.relationships.has(captured):
		subject.remove_relationship(captured)
#endregion
