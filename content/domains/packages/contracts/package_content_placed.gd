extends RefCounted
## Committed physical package content; captured native relationship identities are lifetime witnesses only.
class_name PackageContentPlaced

## Event published after the item enters World at a verified pose.
const EVENT: StringName = &"package_content_placed"
## Weak live item witness; the fact does not retain a physical body.
var item_reference: WeakRef
## Captured native item identity, rejecting a recycled endpoint.
var item_id: String
## Borrowed binding identities at placement; no role state is copied or written here.
var source_bindings: Array[Relationship] = []

#region Committed fact construction
## Captures the committed item and the source's current native relationship identities.
func _init(item: Entity, source: Entity) -> void:
	item_reference = weakref(item)
	item_id = item.id
	source_bindings.assign(source.relationships)
#endregion
