extends RefCounted
## Follow ownership is an effect -> owner Relationship; replacement is a restore transaction.
class_name HazardFollowService

static var _replacing: Dictionary[int, bool] = {}


static func binding(effect: Entity) -> Relationship:
	if not is_instance_valid(effect):
		return null
	for relationship: Relationship in effect.relationships:
		if relationship.relation is R_HazardFollow:
			return relationship
	return null


## Also clears a previous binding when data is null, without replaying owner-loss effects.
static func replace(effect: Entity, owner: Entity, data: R_HazardFollow) -> void:
	if not is_instance_valid(effect):
		return
	if not effect.relationship_removed.is_connected(_disabled_binding_removed):
		effect.relationship_removed.connect(_disabled_binding_removed)
	var instance_id: int = effect.get_instance_id()
	_replacing[instance_id] = true
	for relationship: Relationship in effect.relationships.duplicate():
		if relationship.relation is R_HazardFollow:
			effect.remove_relationship(relationship)
	if data != null and is_instance_valid(owner):
		effect.add_relationship(Relationship.new(data, owner))
	_replacing.erase(instance_id)
	var lifetime: C_HazardLifetime = effect.get_component(C_HazardLifetime) as C_HazardLifetime
	if lifetime != null:
		lifetime.owner_loss_pending = false


static func is_replacing(effect: Entity) -> bool:
	return is_instance_valid(effect) and _replacing.has(effect.get_instance_id())


## Disabled sources no longer forward relationship signals to World observers.
static func _disabled_binding_removed(effect: Entity, relationship: Relationship) -> void:
	if effect.enabled or is_replacing(effect) or not relationship.relation is R_HazardFollow:
		return
	var data: R_HazardFollow = relationship.relation as R_HazardFollow
	if data.on_loss == DEF_Hazard.OwnerLoss.Despawn and is_instance_valid(ECS.world):
		var lifetime: C_HazardLifetime = effect.get_component(C_HazardLifetime) as C_HazardLifetime
		if lifetime != null:
			lifetime.owner_loss_pending = true
		_retire_disabled_if_unbound.call_deferred(weakref(effect), weakref(ECS.world))


static func _retire_disabled_if_unbound(effect_reference: WeakRef, world_reference: WeakRef) -> void:
	var effect: Entity = effect_reference.get_ref() as Entity
	var world: World = world_reference.get_ref() as World
	var lifetime: C_HazardLifetime = effect.get_component(C_HazardLifetime) as C_HazardLifetime if is_instance_valid(effect) else null
	if is_instance_valid(world) and lifetime != null and lifetime.owner_loss_pending and binding(effect) == null:
		HazardLifecycle.retire(effect, world)
