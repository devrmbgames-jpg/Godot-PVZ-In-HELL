extends RefCounted
## Bridges arbitrary RigidBody3D nodes into the existing C_HeldBy relationship model.
class_name PhysicsGrabTarget

const META_PROXY: StringName = &"_gecs_grab_proxy"


static func body_for(handle: Entity) -> RigidBody3D:
	if not is_instance_valid(handle):
		return null
	var direct: RigidBody3D = handle as Node as RigidBody3D
	if direct != null:
		return direct
	var reference: C_PhysicsBodyRef = handle.get_component(C_PhysicsBodyRef) as C_PhysicsBodyRef
	if reference == null or not is_instance_valid(reference.body):
		return null
	return reference.body


static func handle_for(body: RigidBody3D, create_proxy: bool = false) -> Entity:
	if not is_instance_valid(body):
		return null

	var direct: Entity = body as Node as Entity
	if direct != null and _registered(direct):
		return direct

	var cached: Entity = _cached_proxy(body)
	if cached != null:
		return cached
	if not create_proxy or not is_instance_valid(ECS.world):
		return null

	var proxy: Entity = Entity.new()
	proxy.name = "PhysicsGrabProxy_%d" % body.get_instance_id()
	var reference: C_PhysicsBodyRef = C_PhysicsBodyRef.new()
	reference.body = body
	proxy.add_component(reference)
	ECS.world.add_entity(proxy)

	body.set_meta(META_PROXY, weakref(proxy))
	body.tree_exiting.connect(_on_body_tree_exiting.bind(weakref(proxy)), CONNECT_ONE_SHOT)
	return proxy


static func is_proxy(handle: Entity) -> bool:
	return (
		is_instance_valid(handle)
		and handle.get_component(C_PhysicsBodyRef) as C_PhysicsBodyRef != null
	)


static func _cached_proxy(body: RigidBody3D) -> Entity:
	if not body.has_meta(META_PROXY):
		return null
	var reference: WeakRef = body.get_meta(META_PROXY) as WeakRef
	var proxy: Entity = reference.get_ref() as Entity if reference != null else null
	if _registered(proxy):
		return proxy
	body.remove_meta(META_PROXY)
	return null


static func _registered(entity: Entity) -> bool:
	return (
		is_instance_valid(entity)
		and is_instance_valid(ECS.world)
		and ECS.world.entity_to_archetype.has(entity)
	)


static func _on_body_tree_exiting(proxy_reference: WeakRef) -> void:
	var proxy: Entity = proxy_reference.get_ref() as Entity if proxy_reference != null else null
	if _registered(proxy):
		ECS.world.remove_entity(proxy)
