extends RefCounted
## Contact-resolution snapshot of a live throw binding, never a second throw owner.
class_name ImpactThrowAttribution

## Weak actor endpoint resolved separately at each synchronous damage boundary.
var actor_reference: WeakRef = null
## Stable identity remains valid if the actor retires during the first contact direction.
var actor_id: String = ""


#region Snapshot access
## Resolves the optional live instigator without extending its lifetime.
func actor() -> Entity:
	return actor_reference.get_ref() as Entity if actor_reference != null else null
#endregion
