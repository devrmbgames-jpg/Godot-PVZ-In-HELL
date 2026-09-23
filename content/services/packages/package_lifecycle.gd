extends RefCounted
## Publishes package-specific transitions for future hazard/customer subscribers.
class_name PackageLifecycle


## Called only after the domain state transition has committed.
static func publish(
	package: Entity,
	kind: PackageLifecycleEvent.Kind,
	actor: Entity = null,
	cause: DamageResult = null,
) -> void:
	if not EntityAvailability.contains(package, ECS.world):
		return
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var package_lifecycle: PackageLifecycleEvent = PackageLifecycleEvent.new()
	package_lifecycle.package = package
	package_lifecycle.package_id = identity.package_id if identity != null else ""
	package_lifecycle.kind = kind
	package_lifecycle.actor = actor
	package_lifecycle.cause = cause
	ECS.world.emit_event(PackageLifecycleEvent.EVENT, package, package_lifecycle)
