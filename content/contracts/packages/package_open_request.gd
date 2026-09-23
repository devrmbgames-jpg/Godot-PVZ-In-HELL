extends RefCounted
## Deliberate package opening command; independent of damage and shipment ownership.
class_name PackageOpenRequest

const EVENT: StringName = &"package_open_requested"

## Actor requesting access and the physical package to open.
var actor: Entity = null
var package: Entity = null
