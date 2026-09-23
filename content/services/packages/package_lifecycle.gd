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
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var notification: PackageLifecycleEvent = PackageLifecycleEvent.new()
	notification.package = package
	notification.package_id = identity.package_id if identity != null else ""
	notification.kind = kind
	notification.actor = actor
	notification.cause = cause
	ECS.world.emit_event(PackageLifecycleEvent.EVENT, package, notification)
