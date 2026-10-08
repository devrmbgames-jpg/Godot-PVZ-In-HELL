extends RefCounted
## Global composition connects native actor lifecycle to the higher Customer role owner.
class_name NpcCustomerComposition

#region Native World registration
## Binds existing and later actors, including bodies constructed by passive snapshot restore.
static func install(world: World) -> void:
	if not world.entity_added.is_connected(_on_entity_added):
		world.entity_added.connect(_on_entity_added)
	for actor: Entity in world.entity_to_archetype:
		_bind_actor(actor, world)


static func _on_entity_added(actor: Entity) -> void:
	_bind_actor(actor, ECS.world)


static func _bind_actor(actor: Entity, world: World) -> void:
	var body: E_DistrictNpc = actor as E_DistrictNpc
	if body != null:
		CustomerNpcLifecycleBinding.bind(body, world)
#endregion
