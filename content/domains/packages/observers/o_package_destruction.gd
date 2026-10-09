extends Observer
## Заменяет уничтоженную коробку обломками её варианта сцены и удаляет исходную Node.
class_name O_PackageDestruction

#region Подписка на уничтожение
## Подписывается на жизненный цикл коробок с авторским представлением уничтожения.
func query() -> QueryBuilder:
	return q.with_all([C_Package, C_PackageDestruction]).on_event(PackageLifecycleEvent.EVENT)

## На Destroyed сохраняет положение и скорости, затем откладывает замену коробки обломками.
func each(_event: Variant, package: Entity, payload: Variant = null) -> void:
	var event: PackageLifecycleEvent = payload as PackageLifecycleEvent
	if event == null or event.kind != PackageLifecycleEvent.Kind.Destroyed:
		return
	if not EntityAvailability.contains(package, _world):
		return

	var identity: C_Package = package.get_component(C_Package) as C_Package
	var destruction: C_PackageDestruction = package.get_component(C_PackageDestruction) as C_PackageDestruction
	if identity == null or identity.definition == null or destruction == null:
		return
	if destruction.debris_scene == null:
		push_error("Destroyed Package has no C_PackageDestruction.debris_scene")
		return

	var body: RigidBody3D = package as Node as RigidBody3D
	var linear_velocity: Vector3 = body.linear_velocity if body != null else Vector3.ZERO
	var angular_velocity: Vector3 = body.angular_velocity if body != null else Vector3.ZERO
	var spatial: Node3D = package as Node as Node3D
	if spatial == null:
		return

	var world_pose: Transform3D = (
		event.cause.world_pose
		if event.cause != null and event.cause.world_pose.is_finite()
		else spatial.global_transform
	)
	cmd.add_custom(
		_replace_with_debris.bind(
			weakref(package),
			identity,
			destruction,
			identity.package_id,
			identity.definition,
			destruction.debris_scene,
			world_pose,
			linear_velocity,
			angular_velocity,
			event.cause,
			PackageContentsService.is_empty(package),
		)
	)

#endregion

#region Замена физического экземпляра
func _replace_with_debris(
	package_reference: WeakRef,
	captured_identity: C_Package,
	captured_destruction: C_PackageDestruction,
	package_id: String,
	definition: DEF_Package,
	debris_scene: PackedScene,
	world_pose: Transform3D,
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	cause: DamageResult,
	contents_released: bool,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var package: Entity = package_reference.get_ref() as Entity

	if not is_instance_valid(_world) or not EntityAvailability.contains(package, _world):
		return
	if package.get_component(C_Package) != captured_identity or package.get_component(C_PackageDestruction) != captured_destruction:
		return

	var node: Node = debris_scene.instantiate()
	var debris: E_PackageDebris = node as E_PackageDebris
	var spatial: Node3D = node as Node3D
	if debris == null or spatial == null:
		node.free()
		push_error("Package debris scene must use E_PackageDebris on a Node3D root")
		return

	debris.configure_source(package_id, definition)
	debris.name = "Debris_%s" % package_id if not package_id.is_empty() else "PackageDebris"
	_world.add_child(debris)
	spatial.global_transform = world_pose

	var rigid: RigidBody3D = debris as Node as RigidBody3D
	if rigid != null:
		rigid.linear_velocity = linear_velocity
		rigid.angular_velocity = angular_velocity

	var context: EntitySpawnContext = EntityCompositionService.context_for(debris, _world,
		debris.id if not debris.id.is_empty() else GECSIO.uuid())
	if not EntityCompositionService.try_register(context, false):
		debris.free()
		return

	var spawned: PackageDebrisSpawnedEvent = PackageDebrisSpawnedEvent.new()
	spawned.debris = debris
	spawned.package_id = package_id
	spawned.definition = definition
	spawned.cause = cause
	spawned.world_pose = world_pose
	spawned.contents_released = contents_released or PackageContentsService.is_empty(package)
	_world.emit_event(PackageDebrisSpawnedEvent.EVENT, debris, spawned)

	_world.remove_entity(package)
	package.queue_free()

#endregion
