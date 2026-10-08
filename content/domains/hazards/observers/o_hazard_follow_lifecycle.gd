extends Observer
## При снятии входящей связи GECS сохраняет авторскую реакцию на потерю владельца.
class_name O_HazardFollowLifecycle


## Наблюдает снятие R_HazardFollow.
func query() -> QueryBuilder:
	return q.on_relationship_removed([R_HazardFollow])


## Вне защищённой замены планирует удаление эффекта с политикой Despawn.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var relationship: Relationship = payload as Relationship
	if relationship == null or HazardFollowService.is_replacing(entity):
		return

	var data: R_HazardFollow = relationship.relation as R_HazardFollow
	if data != null and data.on_loss == DEF_Hazard.OwnerLoss.Despawn:
		cmd.add_custom(_retire_if_unbound.bind(weakref(entity)))


func _retire_if_unbound(effect_reference: WeakRef) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var effect: Entity = effect_reference.get_ref() as Entity

	if not EntityAvailability.contains(effect, _world):
		return
	if HazardFollowService.binding(effect) == null:
		HazardLifecycle.retire(effect, _world)
