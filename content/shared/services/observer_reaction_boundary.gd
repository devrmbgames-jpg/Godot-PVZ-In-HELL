extends RefCounted
## Suspends Observer reactions and restores derived membership without replaying effects.
class_name ObserverReactionBoundary


#region Synchronous construction reaction scope
## Captures activity for an explicit Observer set and prevents partial-construction reactions.
static func suspend(subjects: Array[Observer]) -> Dictionary[Observer, bool]:
	var activity: Dictionary[Observer, bool] = { }
	for observer: Observer in subjects:
		activity[observer] = observer.active
		observer.active = false
	return activity


## Seeds current native membership silently before restoring each Observer's captured activity.
static func resume(world: World, activity: Dictionary[Observer, bool]) -> void:
	# Pinned GECS exposes no silent public reseed; this adapter owns its derived monitor index.
	var entries_by_observer: Dictionary = world.get("_obs_entries_by_observer") as Dictionary
	for entries_value: Variant in entries_by_observer.values():
		var entries: Array = entries_value as Array
		for entry: Dictionary in entries:
			if bool(entry.get("is_monitor", false)):
				(entry.membership as Dictionary).clear()
				world.call("_seed_monitor_membership", entry, false)

	for observer: Observer in activity:
		observer.active = activity[observer]
#endregion
